import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/models/reminder_item.dart';
import 'notification_scheduler.dart';

typedef NotificationActionCallback = Future<void> Function(String actionId, String reminderId);

class LocalNotificationScheduler implements NotificationScheduler {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _notificationsAllowed = true;
  bool _exactAlarmsAllowed = true;
  DateTime? _lastReconciledAt;

  static const String channelId = 'focus_personal_os_channel';
  static const String channelName = 'FOCUS Scheduled Reminders';
  static const String channelDesc = 'Time-sensitive notifications for tasks, deadlines, and focus routines.';

  NotificationActionCallback? _onActionCallback;

  void setActionCallback(NotificationActionCallback callback) {
    _onActionCallback = callback;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone initialization note: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped action: ${response.actionId}, payload: ${response.payload}');
          if (response.payload != null && _onActionCallback != null) {
            _onActionCallback!(response.actionId ?? 'tap', response.payload!);
          }
        },
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Notification plugin initialize error (running fallback): $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final androidPlatform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final notifGranted = await androidPlatform.requestNotificationsPermission();
        final exactGranted = await androidPlatform.requestExactAlarmsPermission();
        _notificationsAllowed = notifGranted ?? true;
        _exactAlarmsAllowed = exactGranted ?? true;
        return _notificationsAllowed;
      }
    } catch (e) {
      debugPrint('requestPermissions note: $e');
    }
    return true;
  }

  static int deriveNotificationId(String id) {
    // Generate deterministic positive 31-bit integer for OS notification ID
    var hash = 0;
    for (var i = 0; i < id.length; i++) {
      hash = (31 * hash + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  @override
  Future<void> schedule(ReminderItem reminder) async {
    await initialize();

    final notifId = reminder.notificationId != 0
        ? reminder.notificationId
        : deriveNotificationId(reminder.id);

    final scheduledDate = tz.TZDateTime.from(reminder.triggerAt, tz.local);

    // If trigger date has already passed, don't schedule in the past
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_complete',
          '✓ Mark Done',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'action_snooze_15',
          '⏱ +15m',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        id: notifId,
        title: reminder.title,
        body: reminder.notes ?? 'FOCUS OS Scheduled Reminder',
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: reminder.id,
      );
      debugPrint('Scheduled notification $notifId for ${reminder.triggerAt}');
    } catch (e) {
      debugPrint('zonedSchedule fallback: $e');
    }
  }

  @override
  Future<void> cancel(String reminderId) async {
    await initialize();
    final notifId = deriveNotificationId(reminderId);
    try {
      await _notifications.cancel(id: notifId);
    } catch (e) {
      debugPrint('Cancel notification error: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('CancelAll error: $e');
    }
  }

  @override
  Future<void> showInstantTestNotification({
    required String title,
    required String body,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        id: 99999,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint('show instant notification: $e');
    }
  }

  @override
  Future<NotificationHealthStatus> getStatus() async {
    int count = 0;
    try {
      final pending = await _notifications.pendingNotificationRequests();
      count = pending.length;
    } catch (_) {}

    return NotificationHealthStatus(
      notificationsAllowed: _notificationsAllowed,
      exactAlarmsAllowed: _exactAlarmsAllowed,
      upcomingScheduledCount: count,
      lastReconciledAt: _lastReconciledAt,
    );
  }

  void markReconciled(DateTime time) {
    _lastReconciledAt = time;
  }
}
