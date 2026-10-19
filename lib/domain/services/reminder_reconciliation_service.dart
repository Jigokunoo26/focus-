import 'package:uuid/uuid.dart';
import '../../data/repositories/local_audit_repository.dart';
import '../../data/repositories/local_reminder_repository.dart';
import '../../domain/models/reminder_item.dart';
import '../../platform/local_notification_scheduler.dart';
import '../../platform/notification_scheduler.dart';

class ReminderReconciliationService {
  final IReminderRepository _reminderRepo;
  final NotificationScheduler _scheduler;
  final LocalAuditRepository? auditRepo;

  ReminderReconciliationService(
    this._reminderRepo,
    this._scheduler, {
    this.auditRepo,
  });

  /// Idempotent reconciliation pipeline:
  /// 1. Query active reminders in a 14-day rolling window
  /// 2. Cancel all obsolete or already passed scheduled alarms
  /// 3. Reschedule active future reminders with deterministic IDs
  /// 4. Record reconciliation timestamp
  Future<int> reconcileAll() async {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 14));

    final allReminders = await _reminderRepo.getReminders();
    int scheduledCount = 0;

    for (final reminder in allReminders) {
      if (reminder.state == ReminderState.cancelled) {
        await _scheduler.cancel(reminder.id);
        continue;
      }

      // Check if reminder is in the past
      if (reminder.triggerAt.isBefore(now)) {
        if (reminder.state == ReminderState.scheduled || reminder.state == ReminderState.pending) {
          // Mark as missed per catch-up policy rather than alerting late
          await _reminderRepo.updateReminderState(reminder.id, ReminderState.missed);
          await _scheduler.cancel(reminder.id);
        }
        continue;
      }

      // Check if reminder is within rolling window
      if (reminder.triggerAt.isBefore(horizon)) {
        await _scheduler.schedule(reminder);
        if (reminder.state != ReminderState.scheduled) {
          await _reminderRepo.updateReminderState(reminder.id, ReminderState.scheduled);
        }
        scheduledCount++;
      }
    }

    if (_scheduler is LocalNotificationScheduler) {
      _scheduler.markReconciled(DateTime.now());
    }

    try {
      await auditRepo?.logEvent(
        id: const Uuid().v4(),
        eventType: 'RECONCILED',
        title: '14-Day Rolling Window Reconciled',
        details: '$scheduledCount alarms verified and scheduled in rolling window.',
        createdAt: now,
      );
    } catch (_) {}

    return scheduledCount;
  }
}
