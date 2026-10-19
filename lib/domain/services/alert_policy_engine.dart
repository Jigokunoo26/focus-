import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../data/repositories/local_audit_repository.dart';
import '../../data/repositories/local_critical_alert_repository.dart';
import '../../platform/platform_alert_adapter.dart';
import '../models/critical_alert_models.dart';

class AlertPolicyEngine {
  final LocalCriticalAlertRepository _alertRepo;
  final LocalAuditRepository _auditRepo;
  final PlatformAlertAdapter _adapter;

  AlertPolicyEngine(
    this._alertRepo,
    this._auditRepo,
    this._adapter,
  );

  /// Computes the initial occurrence for a task schedule and alert rule
  TaskOccurrence createInitialOccurrence({
    required String taskId,
    required DateTime plannedAtUtc,
    required String localDate,
    required String zoneId,
  }) {
    return TaskOccurrence(
      id: const Uuid().v4(),
      taskId: taskId,
      plannedAtUtc: plannedAtUtc,
      localDate: localDate,
      zoneId: zoneId,
      revision: 1,
      state: AlertState.scheduled,
    );
  }

  /// Transition state machine with strict optimistic locking revision check
  Future<bool> transitionOccurrence(
    String occurrenceId,
    AlertState targetState, {
    DateTime? acknowledgedAt,
  }) async {
    final occurrence = await _alertRepo.getOccurrence(occurrenceId);
    if (occurrence == null) return false;

    // Terminal occurrences can never be reopened (Section 4.3 & 10.1)
    if (occurrence.state.isTerminal) {
      return false;
    }

    // Validate legal state transition
    if (!_isLegalTransition(occurrence.state, targetState)) {
      return false;
    }

    final success = await _alertRepo.updateOccurrenceState(
      occurrenceId,
      targetState,
      occurrence.revision,
      acknowledgedAt: acknowledgedAt,
    );

    if (success) {
      await _auditRepo.logEvent(
        id: const Uuid().v4(),
        eventType: targetState.name.toUpperCase(),
        ownerId: occurrence.taskId,
        title: 'Occurrence ${targetState.name}',
        details: 'Transitioned from ${occurrence.state.name} to ${targetState.name} (Rev ${occurrence.revision + 1})',
        createdAt: DateTime.now(),
      );
    }
    return success;
  }

  bool _isLegalTransition(AlertState from, AlertState to) {
    switch (from) {
      case AlertState.draft:
        return to == AlertState.scheduled || to == AlertState.cancelled;
      case AlertState.scheduled:
        return to == AlertState.firing || to == AlertState.cancelled || to == AlertState.needsReconcile;
      case AlertState.firing:
        return to == AlertState.presented || to == AlertState.needsReconcile;
      case AlertState.presented:
        return to == AlertState.acknowledged ||
            to == AlertState.snoozed ||
            to == AlertState.escalating ||
            to == AlertState.expired;
      case AlertState.snoozed:
        return to == AlertState.scheduled || to == AlertState.acknowledged || to == AlertState.expired;
      case AlertState.escalating:
        return to == AlertState.presented ||
            to == AlertState.acknowledged ||
            to == AlertState.expired;
      case AlertState.needsReconcile:
        return to == AlertState.scheduled || to == AlertState.cancelled;
      case AlertState.acknowledged:
      case AlertState.expired:
      case AlertState.cancelled:
        return false; // Terminal states
    }
  }

  /// Executes bounded user snooze (caps at 3 times, default 15m)
  Future<bool> handleSnooze(String occurrenceId, {int delayMinutes = 15}) async {
    final occurrence = await _alertRepo.getOccurrence(occurrenceId);
    if (occurrence == null || occurrence.state.isTerminal) return false;

    final existingSnooze = await _alertRepo.getSnooze(occurrenceId);
    final count = (existingSnooze?.count ?? 0) + 1;

    // Bounded escalation / snooze cap: Max 3 snoozes
    if (count > 3) {
      // Force expired or terminal acknowledge
      await transitionOccurrence(occurrenceId, AlertState.expired);
      return false;
    }

    final newTriggerUtc = DateTime.now().toUtc().add(Duration(minutes: delayMinutes));
    await _alertRepo.setSnooze(SnoozeRecord(
      occurrenceId: occurrenceId,
      untilUtc: newTriggerUtc,
      count: count,
      source: 'user_action',
    ));

    // Transition to snoozed then scheduled
    await transitionOccurrence(occurrenceId, AlertState.snoozed);

    // Schedule new platform projection with incremented revision
    await _adapter.scheduleOccurrence(
      occurrenceId: occurrenceId,
      revision: occurrence.revision + 1,
      fireAtUtc: newTriggerUtc,
    );

    return true;
  }

  /// Explicit acknowledgment by user (Done / Terminal)
  Future<bool> handleAcknowledge(String occurrenceId) async {
    final occurrence = await _alertRepo.getOccurrence(occurrenceId);
    if (occurrence == null) return false;

    final success = await transitionOccurrence(
      occurrenceId,
      AlertState.acknowledged,
      acknowledgedAt: DateTime.now(),
    );

    if (success) {
      await _alertRepo.clearSnooze(occurrenceId);
      await _adapter.cancelOccurrence(
        occurrenceId: occurrenceId,
        revision: occurrence.revision + 1,
      );
    }
    return success;
  }

  /// Reconciles all pending and overdue occurrences on boot, DST change, or app launch
  Future<int> reconcileAllOccurrences() async {
    final now = DateTime.now().toUtc();
    final upcoming = await _alertRepo.getUpcomingActiveOccurrences();
    int scheduledCount = 0;

    for (final occ in upcoming) {
      if (occ.plannedAtUtc.isBefore(now.subtract(const Duration(minutes: 60)))) {
        // Stale missed instance: Do not replay backlog flood, mark expired/needsReconcile
        await _alertRepo.updateOccurrenceState(
          occ.id,
          AlertState.expired,
          occ.revision,
        );
        await _alertRepo.recordAttempt(AlertAttempt(
          id: const Uuid().v4(),
          occurrenceId: occ.id,
          ordinal: 0,
          plannedAtUtc: occ.plannedAtUtc,
          attemptedAtUtc: now,
          channel: 'notification',
          result: 'missed',
          reasonCode: 'OVERDUE_ON_STARTUP',
        ));
      } else {
        // Valid upcoming occurrence or recent within grace window
        await _adapter.scheduleOccurrence(
          occurrenceId: occ.id,
          revision: occ.revision,
          fireAtUtc: occ.plannedAtUtc,
        );
        scheduledCount++;
      }
    }

    // Process pending outbox
    await processOutbox();

    return scheduledCount;
  }

  /// Outbox replay processor for crash recovery
  Future<void> processOutbox() async {
    final pending = await _alertRepo.getPendingOutbox();
    for (final item in pending) {
      try {
        if (item.command == 'SCHEDULE') {
          await _adapter.scheduleOccurrence(
            occurrenceId: item.occurrenceId,
            revision: item.revision,
            fireAtUtc: item.fireAtUtc,
          );
        } else if (item.command == 'CANCEL') {
          await _adapter.cancelOccurrence(
            occurrenceId: item.occurrenceId,
            revision: item.revision,
          );
        }
        await _alertRepo.markOutboxProcessed(item.id);
      } catch (e) {
        // Keep pending for next replay
      }
    }
  }
}
