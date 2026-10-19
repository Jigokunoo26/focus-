import 'package:flutter/foundation.dart';

/// Explicit alert state machine states according to Phase 5 System Design
enum AlertState {
  draft,
  scheduled,
  firing,
  presented,
  snoozed,
  escalating,
  needsReconcile,
  acknowledged, // Terminal
  expired,      // Terminal
  cancelled;    // Terminal

  bool get isTerminal =>
      this == AlertState.acknowledged ||
      this == AlertState.expired ||
      this == AlertState.cancelled;
}

enum DuePolicy {
  strict,
  gracePeriod,
  nextBusinessDay;

  static DuePolicy fromString(String val) {
    return DuePolicy.values.firstWhere(
      (e) => e.name == val,
      orElse: () => DuePolicy.gracePeriod,
    );
  }
}

enum QuietHoursPolicy {
  defer,
  silent,
  allow;

  static QuietHoursPolicy fromString(String val) {
    return QuietHoursPolicy.values.firstWhere(
      (e) => e.name == val,
      orElse: () => QuietHoursPolicy.silent,
    );
  }
}

/// Task Schedule keeping wall-clock intent and timezone separate from UTC instant
@immutable
class TaskSchedule {
  final String taskId;
  final String localDateTime; // e.g. "2026-10-20T09:00:00"
  final String zoneId;        // IANA zone identifier, e.g. "America/New_York", "UTC"
  final String? recurrenceRule; // e.g. "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,WE,FR"
  final DuePolicy duePolicy;
  final int graceMinutes;

  const TaskSchedule({
    required this.taskId,
    required this.localDateTime,
    required this.zoneId,
    this.recurrenceRule,
    this.duePolicy = DuePolicy.gracePeriod,
    this.graceMinutes = 15,
  });

  Map<String, dynamic> toMap() => {
    'task_id': taskId,
    'local_date_time': localDateTime,
    'zone_id': zoneId,
    'recurrence_rule': recurrenceRule,
    'due_policy': duePolicy.name,
    'grace_minutes': graceMinutes,
  };

  factory TaskSchedule.fromMap(Map<String, dynamic> map) => TaskSchedule(
    taskId: map['task_id'] as String,
    localDateTime: map['local_date_time'] as String,
    zoneId: map['zone_id'] as String? ?? 'UTC',
    recurrenceRule: map['recurrence_rule'] as String?,
    duePolicy: DuePolicy.fromString(map['due_policy'] as String? ?? 'gracePeriod'),
    graceMinutes: map['grace_minutes'] as int? ?? 15,
  );
}

/// Alert Rule with bounded escalation plan
@immutable
class AlertRule {
  final String id;
  final String taskId;
  final int leadMinutes; // 0 = at due time, 15 = 15m before
  final String channel;  // 'notification', 'alarm', 'silent'
  final List<int> escalationSteps; // e.g. [5, 15] intervals in minutes, capped at 3
  final QuietHoursPolicy quietHoursPolicy;
  final bool enabled;

  const AlertRule({
    required this.id,
    required this.taskId,
    this.leadMinutes = 0,
    this.channel = 'notification',
    this.escalationSteps = const [15],
    this.quietHoursPolicy = QuietHoursPolicy.silent,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'lead_minutes': leadMinutes,
    'channel': channel,
    'escalation_steps_json': escalationSteps.join(','),
    'quiet_hours_policy': quietHoursPolicy.name,
    'enabled': enabled ? 1 : 0,
  };

  factory AlertRule.fromMap(Map<String, dynamic> map) {
    final stepsRaw = map['escalation_steps_json'] as String? ?? '';
    final steps = stepsRaw.isEmpty
        ? <int>[15]
        : stepsRaw.split(',').map((s) => int.tryParse(s.trim()) ?? 15).toList();

    return AlertRule(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      leadMinutes: map['lead_minutes'] as int? ?? 0,
      channel: map['channel'] as String? ?? 'notification',
      escalationSteps: steps.take(3).toList(), // capped at 3
      quietHoursPolicy: QuietHoursPolicy.fromString(map['quiet_hours_policy'] as String? ?? 'silent'),
      enabled: (map['enabled'] as int? ?? 1) == 1,
    );
  }
}

/// Stable occurrence instance for unique task/date/recurrence slot
@immutable
class TaskOccurrence {
  final String id;
  final String taskId;
  final DateTime plannedAtUtc;
  final String localDate; // "YYYY-MM-DD"
  final String zoneId;
  final int revision;     // Increments on each reschedule/recompute
  final AlertState state;
  final DateTime? acknowledgedAt;

  const TaskOccurrence({
    required this.id,
    required this.taskId,
    required this.plannedAtUtc,
    required this.localDate,
    required this.zoneId,
    this.revision = 1,
    this.state = AlertState.scheduled,
    this.acknowledgedAt,
  });

  TaskOccurrence copyWith({
    String? id,
    String? taskId,
    DateTime? plannedAtUtc,
    String? localDate,
    String? zoneId,
    int? revision,
    AlertState? state,
    DateTime? acknowledgedAt,
  }) {
    return TaskOccurrence(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      plannedAtUtc: plannedAtUtc ?? this.plannedAtUtc,
      localDate: localDate ?? this.localDate,
      zoneId: zoneId ?? this.zoneId,
      revision: revision ?? this.revision,
      state: state ?? this.state,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'planned_at_utc': plannedAtUtc.toUtc().toIso8601String(),
    'local_date': localDate,
    'zone_id': zoneId,
    'revision': revision,
    'state': state.name,
    'acknowledged_at_utc': acknowledgedAt?.toUtc().toIso8601String(),
  };

  factory TaskOccurrence.fromMap(Map<String, dynamic> map) => TaskOccurrence(
    id: map['id'] as String,
    taskId: map['task_id'] as String,
    plannedAtUtc: DateTime.parse(map['planned_at_utc'] as String),
    localDate: map['local_date'] as String,
    zoneId: map['zone_id'] as String? ?? 'UTC',
    revision: map['revision'] as int? ?? 1,
    state: AlertState.values.firstWhere(
      (s) => s.name == map['state'],
      orElse: () => AlertState.scheduled,
    ),
    acknowledgedAt: map['acknowledged_at_utc'] != null
        ? DateTime.parse(map['acknowledged_at_utc'] as String)
        : null,
  );
}

/// Audit record for one alert delivery attempt
@immutable
class AlertAttempt {
  final String id;
  final String occurrenceId;
  final int ordinal;
  final DateTime plannedAtUtc;
  final DateTime? attemptedAtUtc;
  final String channel;
  final String result; // 'presented', 'suppressed', 'failed', 'missed'
  final String? reasonCode;

  const AlertAttempt({
    required this.id,
    required this.occurrenceId,
    required this.ordinal,
    required this.plannedAtUtc,
    this.attemptedAtUtc,
    required this.channel,
    required this.result,
    this.reasonCode,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'occurrence_id': occurrenceId,
    'ordinal': ordinal,
    'planned_at_utc': plannedAtUtc.toUtc().toIso8601String(),
    'attempted_at_utc': attemptedAtUtc?.toUtc().toIso8601String(),
    'channel': channel,
    'result': result,
    'reason_code': reasonCode,
  };

  factory AlertAttempt.fromMap(Map<String, dynamic> map) => AlertAttempt(
    id: map['id'] as String,
    occurrenceId: map['occurrence_id'] as String,
    ordinal: map['ordinal'] as int? ?? 0,
    plannedAtUtc: DateTime.parse(map['planned_at_utc'] as String),
    attemptedAtUtc: map['attempted_at_utc'] != null
        ? DateTime.parse(map['attempted_at_utc'] as String)
        : null,
    channel: map['channel'] as String? ?? 'notification',
    result: map['result'] as String? ?? 'presented',
    reasonCode: map['reason_code'] as String?,
  );
}

/// Bounded snooze record for an occurrence
@immutable
class SnoozeRecord {
  final String occurrenceId;
  final DateTime untilUtc;
  final int count;
  final String source; // 'notification_action', 'in_app'

  const SnoozeRecord({
    required this.occurrenceId,
    required this.untilUtc,
    this.count = 1,
    this.source = 'notification_action',
  });

  Map<String, dynamic> toMap() => {
    'occurrence_id': occurrenceId,
    'until_utc': untilUtc.toUtc().toIso8601String(),
    'count': count,
    'source': source,
  };

  factory SnoozeRecord.fromMap(Map<String, dynamic> map) => SnoozeRecord(
    occurrenceId: map['occurrence_id'] as String,
    untilUtc: DateTime.parse(map['until_utc'] as String),
    count: map['count'] as int? ?? 1,
    source: map['source'] as String? ?? 'notification_action',
  );
}

/// Rebuildable projection for platform schedules
@immutable
class PlatformSchedule {
  final String scheduleKey;
  final String occurrenceId;
  final int revision;
  final String? platformToken;
  final DateTime desiredAtUtc;
  final DateTime? syncedAtUtc;
  final String status; // 'synced', 'pendingCancel', 'failed'

  const PlatformSchedule({
    required this.scheduleKey,
    required this.occurrenceId,
    required this.revision,
    this.platformToken,
    required this.desiredAtUtc,
    this.syncedAtUtc,
    this.status = 'synced',
  });

  Map<String, dynamic> toMap() => {
    'schedule_key': scheduleKey,
    'occurrence_id': occurrenceId,
    'revision': revision,
    'platform_token': platformToken,
    'desired_at_utc': desiredAtUtc.toUtc().toIso8601String(),
    'synced_at_utc': syncedAtUtc?.toUtc().toIso8601String(),
    'status': status,
  };

  factory PlatformSchedule.fromMap(Map<String, dynamic> map) => PlatformSchedule(
    scheduleKey: map['schedule_key'] as String,
    occurrenceId: map['occurrence_id'] as String,
    revision: map['revision'] as int? ?? 1,
    platformToken: map['platform_token'] as String?,
    desiredAtUtc: DateTime.parse(map['desired_at_utc'] as String),
    syncedAtUtc: map['synced_at_utc'] != null
        ? DateTime.parse(map['synced_at_utc'] as String)
        : null,
    status: map['status'] as String? ?? 'synced',
  );
}

/// Outbox record ensuring transactional atomic commitment between DB and OS calls
@immutable
class OutboxItem {
  final String id;
  final String command; // 'SCHEDULE', 'CANCEL'
  final String occurrenceId;
  final int revision;
  final DateTime fireAtUtc;
  final String payloadJson;
  final DateTime createdAtUtc;
  final bool isProcessed;

  const OutboxItem({
    required this.id,
    required this.command,
    required this.occurrenceId,
    required this.revision,
    required this.fireAtUtc,
    required this.payloadJson,
    required this.createdAtUtc,
    this.isProcessed = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'command': command,
    'occurrence_id': occurrenceId,
    'revision': revision,
    'fire_at_utc': fireAtUtc.toUtc().toIso8601String(),
    'payload_json': payloadJson,
    'created_at_utc': createdAtUtc.toUtc().toIso8601String(),
    'is_processed': isProcessed ? 1 : 0,
  };

  factory OutboxItem.fromMap(Map<String, dynamic> map) => OutboxItem(
    id: map['id'] as String,
    command: map['command'] as String,
    occurrenceId: map['occurrence_id'] as String,
    revision: map['revision'] as int? ?? 1,
    fireAtUtc: DateTime.parse(map['fire_at_utc'] as String),
    payloadJson: map['payload_json'] as String? ?? '{}',
    createdAtUtc: DateTime.parse(map['created_at_utc'] as String),
    isProcessed: (map['is_processed'] as int? ?? 0) == 1,
  );
}

/// Snapshot of system permissions
@immutable
class PermissionSnapshot {
  final bool exactScheduling;
  final bool notifications;
  final bool accessibility;
  final bool overlay;
  final bool backgroundWatcher;
  final DateTime checkedAt;
  final String? detailCode;

  const PermissionSnapshot({
    required this.exactScheduling,
    required this.notifications,
    required this.accessibility,
    required this.overlay,
    required this.backgroundWatcher,
    required this.checkedAt,
    this.detailCode,
  });

  Map<String, dynamic> toMap() => {
    'exact_scheduling': exactScheduling ? 1 : 0,
    'notifications': notifications ? 1 : 0,
    'accessibility': accessibility ? 1 : 0,
    'overlay': overlay ? 1 : 0,
    'background_watcher': backgroundWatcher ? 1 : 0,
    'checked_at_utc': checkedAt.toUtc().toIso8601String(),
    'detail_code': detailCode,
  };

  factory PermissionSnapshot.fromMap(Map<String, dynamic> map) => PermissionSnapshot(
    exactScheduling: (map['exact_scheduling'] as int? ?? 0) == 1,
    notifications: (map['notifications'] as int? ?? 0) == 1,
    accessibility: (map['accessibility'] as int? ?? 0) == 1,
    overlay: (map['overlay'] as int? ?? 0) == 1,
    backgroundWatcher: (map['background_watcher'] as int? ?? 0) == 1,
    checkedAt: DateTime.parse(map['checked_at_utc'] as String),
    detailCode: map['detail_code'] as String?,
  );
}
