import '../domain/models/reminder_item.dart';

class NotificationHealthStatus {
  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;
  final int upcomingScheduledCount;
  final int blockedCount;
  final DateTime? lastReconciledAt;

  const NotificationHealthStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.upcomingScheduledCount,
    this.blockedCount = 0,
    this.lastReconciledAt,
  });
}

abstract interface class NotificationScheduler {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> schedule(ReminderItem reminder);
  Future<void> cancel(String reminderId);
  Future<void> cancelAll();
  Future<NotificationHealthStatus> getStatus();
  Future<void> showInstantTestNotification({required String title, required String body});
}
