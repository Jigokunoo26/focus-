import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/data/database/app_database.dart';
import 'package:focus_app/data/repositories/local_audit_repository.dart';
import 'package:focus_app/data/repositories/local_critical_alert_repository.dart';
import 'package:focus_app/data/repositories/local_focus_guard_repository.dart';
import 'package:focus_app/domain/models/critical_alert_models.dart';
import 'package:focus_app/domain/models/focus_guard_models.dart';
import 'package:focus_app/domain/models/task_item.dart';
import 'package:focus_app/domain/services/alert_policy_engine.dart';
import 'package:focus_app/domain/services/focus_session_coordinator.dart';
import 'package:focus_app/platform/platform_alert_adapter.dart';

class FakePlatformAlertAdapter implements PlatformAlertAdapter {
  final List<String> scheduledOccurrences = [];
  final List<String> cancelledOccurrences = [];
  final StreamController<Map<String, dynamic>> _eventStreamController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get focusEventStream => _eventStreamController.stream;

  void emitFocusEvent(Map<String, dynamic> event) {
    _eventStreamController.add(event);
  }

  @override
  Future<bool> scheduleOccurrence({
    required String occurrenceId,
    required int revision,
    required DateTime fireAtUtc,
    String? title,
    String? channel,
  }) async {
    scheduledOccurrences.add('$occurrenceId:$revision');
    return true;
  }

  @override
  Future<bool> cancelOccurrence({
    required String occurrenceId,
    required int revision,
  }) async {
    cancelledOccurrences.add('$occurrenceId:$revision');
    return true;
  }

  @override
  Future<bool> startFocusMonitoring({
    required String sessionId,
    required FocusPolicy policy,
  }) async {
    return true;
  }

  @override
  Future<bool> stopFocusMonitoring({required String sessionId}) async {
    return true;
  }

  @override
  Future<PermissionSnapshot> getCapabilities() async {
    return PermissionSnapshot(
      exactScheduling: true,
      notifications: true,
      accessibility: true,
      overlay: true,
      backgroundWatcher: true,
      checkedAt: DateTime.now(),
    );
  }

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> requestAccessibilityPermission() async {}

  @override
  Future<void> requestOverlayPermission() async {}

  void dispose() {
    _eventStreamController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalCriticalAlertRepository alertRepo;
  late LocalAuditRepository auditRepo;
  late LocalFocusGuardRepository focusRepo;
  late FakePlatformAlertAdapter adapter;
  late AlertPolicyEngine alertEngine;
  late FocusSessionCoordinator focusCoordinator;

  setUp(() async {
    db = await AppDatabase.getInstance(inMemory: true);
    alertRepo = LocalCriticalAlertRepository(db);
    auditRepo = LocalAuditRepository(db);
    focusRepo = LocalFocusGuardRepository(db);
    adapter = FakePlatformAlertAdapter();
    alertEngine = AlertPolicyEngine(alertRepo, auditRepo, adapter);
    focusCoordinator = FocusSessionCoordinator(focusRepo, adapter);
  });

  tearDown(() {
    focusCoordinator.dispose();
    adapter.dispose();
    db.close();
  });

  group('Phase 5: Critical Task and Alert Engine Acceptance Tests', () {
    test('10.1: TaskSchedule preserves wall-clock intent separate from UTC', () async {
      const schedule = TaskSchedule(
        taskId: 'task-101',
        localDateTime: '2026-10-20T09:00:00',
        zoneId: 'America/New_York',
        recurrenceRule: 'FREQ=DAILY',
        duePolicy: DuePolicy.strict,
        graceMinutes: 10,
      );

      await alertRepo.saveTaskSchedule(schedule);
      final loaded = await alertRepo.getTaskSchedule('task-101');

      expect(loaded, isNotNull);
      expect(loaded!.localDateTime, '2026-10-20T09:00:00');
      expect(loaded.zoneId, 'America/New_York');
      expect(loaded.duePolicy, DuePolicy.strict);
      expect(loaded.graceMinutes, 10);
    });

    test('10.1: Alert State Machine legal transitions and terminal immutability', () async {
      final occ = TaskOccurrence(
        id: 'occ-1',
        taskId: 'task-1',
        plannedAtUtc: DateTime.now().toUtc(),
        localDate: '2026-10-20',
        zoneId: 'UTC',
        revision: 1,
        state: AlertState.scheduled,
      );
      await alertRepo.saveOccurrence(occ);

      // Transition scheduled -> firing
      final toFiring = await alertEngine.transitionOccurrence('occ-1', AlertState.firing);
      expect(toFiring, isTrue);

      final occFiring = await alertRepo.getOccurrence('occ-1');
      expect(occFiring!.state, AlertState.firing);
      expect(occFiring.revision, 2);

      // Transition firing -> presented
      final toPresented = await alertEngine.transitionOccurrence('occ-1', AlertState.presented);
      expect(toPresented, isTrue);

      // Transition presented -> acknowledged (terminal)
      final toAck = await alertEngine.transitionOccurrence('occ-1', AlertState.acknowledged);
      expect(toAck, isTrue);

      // Attempt to reopen terminal occurrence must fail
      final reopenAttempt = await alertEngine.transitionOccurrence('occ-1', AlertState.scheduled);
      expect(reopenAttempt, isFalse);

      final finalOcc = await alertRepo.getOccurrence('occ-1');
      expect(finalOcc!.state, AlertState.acknowledged);
    });

    test('10.1: Bounded Snooze caps at 3 occurrences and escalates to expired on 4th', () async {
      final occ = TaskOccurrence(
        id: 'occ-snooze-test',
        taskId: 'task-snooze',
        plannedAtUtc: DateTime.now().toUtc(),
        localDate: '2026-10-20',
        zoneId: 'UTC',
        revision: 1,
        state: AlertState.presented,
      );
      await alertRepo.saveOccurrence(occ);

      // Snooze 1
      final s1 = await alertEngine.handleSnooze('occ-snooze-test', delayMinutes: 15);
      expect(s1, isTrue);

      // Set to presented for next snooze
      await alertRepo.updateOccurrenceState('occ-snooze-test', AlertState.presented, 2);

      // Snooze 2
      final s2 = await alertEngine.handleSnooze('occ-snooze-test', delayMinutes: 15);
      expect(s2, isTrue);

      await alertRepo.updateOccurrenceState('occ-snooze-test', AlertState.presented, 4);

      // Snooze 3 (Cap reached)
      final s3 = await alertEngine.handleSnooze('occ-snooze-test', delayMinutes: 15);
      expect(s3, isTrue);

      await alertRepo.updateOccurrenceState('occ-snooze-test', AlertState.presented, 6);

      // Snooze 4 (Must exceed cap and transition to expired)
      final s4 = await alertEngine.handleSnooze('occ-snooze-test', delayMinutes: 15);
      expect(s4, isFalse);

      final cappedOcc = await alertRepo.getOccurrence('occ-snooze-test');
      expect(cappedOcc!.state, AlertState.expired);
    });

    test('10.2: Atomic transactional persistence commits Task, Schedule, Rule, Occurrence, and Outbox', () async {
      final now = DateTime.now();
      final task = TaskItem(
        id: 'atomic-task-1',
        title: 'Review System Design Phase 5',
        priority: TaskPriority.high,
        dueAt: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      );

      final schedule = TaskSchedule(
        taskId: 'atomic-task-1',
        localDateTime: '2026-10-20T11:00:00',
        zoneId: 'America/Los_Angeles',
        duePolicy: DuePolicy.strict,
        graceMinutes: 10,
      );

      const rule = AlertRule(
        id: 'rule-atomic-1',
        taskId: 'atomic-task-1',
        leadMinutes: 15,
        channel: 'alarm',
        escalationSteps: [10, 20, 30],
        quietHoursPolicy: QuietHoursPolicy.silent,
        enabled: true,
      );

      final occurrence = TaskOccurrence(
        id: 'occ-atomic-1',
        taskId: 'atomic-task-1',
        plannedAtUtc: now.add(const Duration(hours: 2)).toUtc(),
        localDate: '2026-10-20',
        zoneId: 'America/Los_Angeles',
        revision: 1,
        state: AlertState.scheduled,
      );

      final outboxItem = OutboxItem(
        id: 'outbox-1',
        command: 'SCHEDULE',
        occurrenceId: 'occ-atomic-1',
        revision: 1,
        fireAtUtc: now.add(const Duration(hours: 2)).toUtc(),
        payloadJson: '{"title": "Review System Design Phase 5"}',
        createdAtUtc: now.toUtc(),
      );

      await alertRepo.saveCriticalTaskTransaction(
        task: task,
        schedule: schedule,
        rule: rule,
        occurrence: occurrence,
        outboxItem: outboxItem,
      );

      // Verify all 5 entities exist in SQLite
      final loadedSchedule = await alertRepo.getTaskSchedule('atomic-task-1');
      final loadedRule = await alertRepo.getAlertRule('atomic-task-1');
      final loadedOcc = await alertRepo.getOccurrence('occ-atomic-1');
      final pendingOutbox = await alertRepo.getPendingOutbox();

      expect(loadedSchedule, isNotNull);
      expect(loadedRule, isNotNull);
      expect(loadedOcc, isNotNull);
      expect(pendingOutbox.length, 1);
      expect(pendingOutbox.first.occurrenceId, 'occ-atomic-1');

      // Process outbox
      await alertEngine.processOutbox();

      expect(adapter.scheduledOccurrences, contains('occ-atomic-1:1'));
      final remainingPending = await alertRepo.getPendingOutbox();
      expect(remainingPending.isEmpty, isTrue);
    });

    test('10.2: Idempotent startup reconciliation handles stale events without backlog flood', () async {
      // 1. Stale missed occurrence from yesterday
      final staleOcc = TaskOccurrence(
        id: 'stale-1',
        taskId: 'task-stale',
        plannedAtUtc: DateTime.now().toUtc().subtract(const Duration(hours: 24)),
        localDate: '2026-10-19',
        zoneId: 'UTC',
        revision: 1,
        state: AlertState.scheduled,
      );
      // 2. Valid upcoming occurrence
      final upcomingOcc = TaskOccurrence(
        id: 'upcoming-1',
        taskId: 'task-upcoming',
        plannedAtUtc: DateTime.now().toUtc().add(const Duration(hours: 2)),
        localDate: '2026-10-20',
        zoneId: 'UTC',
        revision: 1,
        state: AlertState.scheduled,
      );

      await alertRepo.saveOccurrence(staleOcc);
      await alertRepo.saveOccurrence(upcomingOcc);

      final scheduledCount = await alertEngine.reconcileAllOccurrences();

      // Only upcoming occurrence was re-scheduled on platform
      expect(scheduledCount, 1);
      expect(adapter.scheduledOccurrences, contains('upcoming-1:1'));

      // Stale occurrence was marked expired with audit attempt
      final updatedStale = await alertRepo.getOccurrence('stale-1');
      expect(updatedStale!.state, AlertState.expired);

      final attempts = await alertRepo.getAttemptsForOccurrence('stale-1');
      expect(attempts.length, 1);
      expect(attempts.first.reasonCode, 'OVERDUE_ON_STARTUP');
    });
  });

  group('Phase 7: Focus Guard Acceptance Tests', () {
    test('10.3: Distraction qualification observes allowlist and triggers candidate state', () async {
      const policy = FocusPolicy(
        id: 'policy-test',
        name: 'Strict Policy',
        monitoredTargets: ['instagram', 'twitter', 'tiktok'],
        graceSeconds: 1,
        cooldownSeconds: 60,
      );
      await focusRepo.savePolicy(policy);

      await focusCoordinator.startSession(policy: policy, durationMinutes: 25);
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.monitoring);

      // Safe app does not trigger candidate state
      await focusCoordinator.handleForegroundChange('com.android.calculator');
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.monitoring);

      // Monitored target triggers Candidate state
      await focusCoordinator.handleForegroundChange('com.instagram.android');
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.candidate);

      // Wait for 1s grace debounce
      await Future.delayed(const Duration(milliseconds: 1100));
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.prompting);
    });

    test('10.3: Switching away from distraction before debounce cancels prompt', () async {
      const policy = FocusPolicy(
        id: 'policy-cancel',
        name: 'Quick Cancel',
        monitoredTargets: ['tiktok', 'musically'],
        graceSeconds: 2,
      );
      await focusRepo.savePolicy(policy);

      await focusCoordinator.startSession(policy: policy, durationMinutes: 25);

      // Target opens -> Candidate
      await focusCoordinator.handleForegroundChange('com.zhiliaoapp.musically');
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.candidate);

      // User immediately switches back to safe task after 200ms
      await Future.delayed(const Duration(milliseconds: 200));
      await focusCoordinator.handleForegroundChange('com.focus.personal_os');

      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.monitoring);

      // Wait out the rest of the grace period
      await Future.delayed(const Duration(milliseconds: 2000));
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.monitoring);
    });

    test('10.4: Focus Guard 4 deliberate escape actions', () async {
      const policy = FocusPolicy(
        id: 'policy-escape',
        name: 'Escape Actions Policy',
        monitoredTargets: ['youtube'],
      );
      await focusRepo.savePolicy(policy);

      final session = await focusCoordinator.startSession(policy: policy, durationMinutes: 25);

      // Escape Action 1: Return to Task
      await focusCoordinator.handleReturnToTask(session.id);
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.monitoring);

      // Escape Action 2: Snooze 5 Min (Cooldown created)
      await focusCoordinator.handleSnooze5m(session.id, 'com.google.android.youtube');
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.cooldown);

      final activeCooldown = await focusRepo.getActiveCooldown(session.id, 'com.google.android.youtube');
      expect(activeCooldown, isNotNull);
      expect(activeCooldown!.isExpired, isFalse);

      // Cooldown suppresses intervention
      await focusCoordinator.handleForegroundChange('com.google.android.youtube');
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.cooldown);

      // Escape Action 3: Pause Session
      await focusCoordinator.pauseSession(session.id);
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.paused);

      // Escape Action 4: End Session (Terminal)
      await focusCoordinator.endSession(session.id);
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.completed);
      expect(focusCoordinator.currentSessionNotifier.value, isNull);
    });

    test('10.5: Degraded mode handling and 30-day retention pruning', () async {
      // Degraded service entry
      focusCoordinator.handleServiceDegraded('Accessibility service permission revoked by user');
      expect(focusCoordinator.currentStateNotifier.value, FocusGuardState.degraded);

      // Event retention pruning
      final now = DateTime.now().toUtc();
      await focusRepo.logFocusEvent(FocusEvent(
        id: 'event-old',
        sessionId: 'sess-1',
        occurredAtUtc: now.subtract(const Duration(days: 35)),
        kind: 'targetDetected',
        targetAppId: 'youtube',
        decision: 'prompt',
      ));
      await focusRepo.logFocusEvent(FocusEvent(
        id: 'event-recent',
        sessionId: 'sess-1',
        occurredAtUtc: now.subtract(const Duration(days: 5)),
        kind: 'promptAction',
        decision: 'returnToTask',
      ));

      final pruned = await focusRepo.pruneOldEvents(days: 30);
      expect(pruned, 1);

      final remainingEvents = await focusRepo.getRecentFocusEvents();
      expect(remainingEvents.length, 1);
      expect(remainingEvents.first.id, 'event-recent');
    });

    test('Stage 6: Offline JSON backup export and restore round-trip', () async {
      // 1. Export current database state to JSON
      final jsonSnapshot = await db.exportDataJson();
      expect(jsonSnapshot, isNotEmpty);
      expect(jsonSnapshot, contains('"app":"FOCUS Personal OS"'));

      // 2. Perform import of snapshot into database
      final restoredCount = await db.importDataJson(jsonSnapshot);
      expect(restoredCount, greaterThan(0));
    });
  });
}
