import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/models/critical_alert_models.dart';
import '../domain/models/focus_guard_models.dart';

abstract class PlatformAlertAdapter {
  Future<bool> scheduleOccurrence({
    required String occurrenceId,
    required int revision,
    required DateTime fireAtUtc,
    String channel = 'notification',
  });

  Future<bool> cancelOccurrence({
    required String occurrenceId,
    required int revision,
  });

  Future<PermissionSnapshot> getCapabilities();

  Future<bool> startFocusMonitoring({
    required String sessionId,
    required FocusPolicy policy,
  });

  Future<bool> stopFocusMonitoring({
    required String sessionId,
  });

  Future<void> requestExactAlarmPermission();
  Future<void> requestAccessibilityPermission();
  Future<void> requestOverlayPermission();

  Stream<Map<String, dynamic>> get focusEventStream;
}

class MethodChannelPlatformAlertAdapter implements PlatformAlertAdapter {
  static const MethodChannel _channel = MethodChannel('com.focus.personal_os/platform_adapter');
  static const EventChannel _eventChannel = EventChannel('com.focus.personal_os/focus_event_stream');

  Stream<Map<String, dynamic>>? _stream;

  @override
  Stream<Map<String, dynamic>> get focusEventStream {
    _stream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _stream!;
  }

  @override
  Future<bool> scheduleOccurrence({
    required String occurrenceId,
    required int revision,
    required DateTime fireAtUtc,
    String channel = 'notification',
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await _channel.invokeMethod<bool>('scheduleOccurrence', {
        'occurrenceId': occurrenceId,
        'revision': revision,
        'fireAtUtc': fireAtUtc.toUtc().toIso8601String(),
        'channel': channel,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('scheduleOccurrence platform error: $e');
      return false;
    }
  }

  @override
  Future<bool> cancelOccurrence({
    required String occurrenceId,
    required int revision,
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await _channel.invokeMethod<bool>('cancelOccurrence', {
        'occurrenceId': occurrenceId,
        'revision': revision,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('cancelOccurrence platform error: $e');
      return false;
    }
  }

  @override
  Future<PermissionSnapshot> getCapabilities() async {
    if (kIsWeb) {
      return PermissionSnapshot(
        exactScheduling: false,
        notifications: true,
        accessibility: false,
        overlay: false,
        backgroundWatcher: false,
        checkedAt: DateTime.now(),
      );
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getCapabilities');
      if (res != null) {
        return PermissionSnapshot(
          exactScheduling: res['exactScheduling'] as bool? ?? false,
          notifications: res['notifications'] as bool? ?? true,
          accessibility: res['accessibility'] as bool? ?? false,
          overlay: res['overlay'] as bool? ?? false,
          backgroundWatcher: res['backgroundWatcher'] as bool? ?? false,
          checkedAt: DateTime.now(),
          detailCode: res['detailCode'] as String?,
        );
      }
    } catch (e) {
      debugPrint('getCapabilities error: $e');
    }
    return PermissionSnapshot(
      exactScheduling: true,
      notifications: true,
      accessibility: false,
      overlay: false,
      backgroundWatcher: false,
      checkedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> startFocusMonitoring({
    required String sessionId,
    required FocusPolicy policy,
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await _channel.invokeMethod<bool>('startFocusMonitoring', {
        'sessionId': sessionId,
        'targets': policy.monitoredTargets,
        'graceSeconds': policy.graceSeconds,
        'cooldownSeconds': policy.cooldownSeconds,
        'promptText': policy.promptText,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('startFocusMonitoring platform error: $e');
      return false;
    }
  }

  @override
  Future<bool> stopFocusMonitoring({
    required String sessionId,
  }) async {
    if (kIsWeb) return true;
    try {
      final res = await _channel.invokeMethod<bool>('stopFocusMonitoring', {
        'sessionId': sessionId,
      });
      return res ?? true;
    } catch (e) {
      debugPrint('stopFocusMonitoring platform error: $e');
      return false;
    }
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
    } catch (_) {}
  }

  @override
  Future<void> requestAccessibilityPermission() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (_) {}
  }

  @override
  Future<void> requestOverlayPermission() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }
}
