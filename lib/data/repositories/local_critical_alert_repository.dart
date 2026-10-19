import '../database/app_database.dart';
import '../../domain/models/critical_alert_models.dart';
import '../../domain/models/task_item.dart';

class LocalCriticalAlertRepository {
  final AppDatabase _db;

  LocalCriticalAlertRepository(this._db);

  /// Saves or updates a TaskSchedule
  Future<void> saveTaskSchedule(TaskSchedule schedule) async {
    _db.rawDb.execute('''
      INSERT INTO task_schedules (task_id, local_date_time, zone_id, recurrence_rule, due_policy, grace_minutes)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(task_id) DO UPDATE SET
        local_date_time = excluded.local_date_time,
        zone_id = excluded.zone_id,
        recurrence_rule = excluded.recurrence_rule,
        due_policy = excluded.due_policy,
        grace_minutes = excluded.grace_minutes;
    ''', [
      schedule.taskId,
      schedule.localDateTime,
      schedule.zoneId,
      schedule.recurrenceRule,
      schedule.duePolicy.name,
      schedule.graceMinutes,
    ]);
  }

  Future<TaskSchedule?> getTaskSchedule(String taskId) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM task_schedules WHERE task_id = ? LIMIT 1;',
      [taskId],
    );
    if (rows.isEmpty) return null;
    return TaskSchedule.fromMap(rows.first);
  }

  /// Saves or updates an AlertRule
  Future<void> saveAlertRule(AlertRule rule) async {
    _db.rawDb.execute('''
      INSERT INTO alert_rules (id, task_id, lead_minutes, channel, escalation_steps_json, quiet_hours_policy, enabled)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        lead_minutes = excluded.lead_minutes,
        channel = excluded.channel,
        escalation_steps_json = excluded.escalation_steps_json,
        quiet_hours_policy = excluded.quiet_hours_policy,
        enabled = excluded.enabled;
    ''', [
      rule.id,
      rule.taskId,
      rule.leadMinutes,
      rule.channel,
      rule.escalationSteps.join(','),
      rule.quietHoursPolicy.name,
      rule.enabled ? 1 : 0,
    ]);
  }

  Future<AlertRule?> getAlertRule(String taskId) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM alert_rules WHERE task_id = ? LIMIT 1;',
      [taskId],
    );
    if (rows.isEmpty) return null;
    return AlertRule.fromMap(rows.first);
  }

  /// Saves or updates a TaskOccurrence
  Future<void> saveOccurrence(TaskOccurrence occurrence) async {
    _db.rawDb.execute('''
      INSERT INTO task_occurrences (id, task_id, planned_at_utc, local_date, zone_id, revision, state, acknowledged_at_utc)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        planned_at_utc = excluded.planned_at_utc,
        local_date = excluded.local_date,
        zone_id = excluded.zone_id,
        revision = excluded.revision,
        state = excluded.state,
        acknowledged_at_utc = excluded.acknowledged_at_utc;
    ''', [
      occurrence.id,
      occurrence.taskId,
      occurrence.plannedAtUtc.toUtc().toIso8601String(),
      occurrence.localDate,
      occurrence.zoneId,
      occurrence.revision,
      occurrence.state.name,
      occurrence.acknowledgedAt?.toUtc().toIso8601String(),
    ]);
  }

  Future<TaskOccurrence?> getOccurrence(String id) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM task_occurrences WHERE id = ? LIMIT 1;',
      [id],
    );
    if (rows.isEmpty) return null;
    return TaskOccurrence.fromMap(rows.first);
  }

  Future<List<TaskOccurrence>> getOccurrencesForTask(String taskId) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM task_occurrences WHERE task_id = ? ORDER BY planned_at_utc ASC;',
      [taskId],
    );
    return rows.map((r) => TaskOccurrence.fromMap(r)).toList();
  }

  Future<List<TaskOccurrence>> getUpcomingActiveOccurrences({DateTime? upToUtc}) async {
    final limitTime = upToUtc ?? DateTime.now().add(const Duration(days: 14)).toUtc();
    final rows = _db.rawDb.select(
      '''
      SELECT * FROM task_occurrences
      WHERE state NOT IN ('acknowledged', 'expired', 'cancelled')
      AND planned_at_utc <= ?
      ORDER BY planned_at_utc ASC;
      ''',
      [limitTime.toIso8601String()],
    );
    return rows.map((r) => TaskOccurrence.fromMap(r)).toList();
  }

  /// Updates occurrence state with strict revision check (optimistic locking)
  Future<bool> updateOccurrenceState(String id, AlertState newState, int expectedRevision, {DateTime? acknowledgedAt}) async {
    _db.rawDb.execute('''
      UPDATE task_occurrences
      SET state = ?, revision = revision + 1, acknowledged_at_utc = ?
      WHERE id = ? AND revision = ?;
    ''', [
      newState.name,
      acknowledgedAt?.toUtc().toIso8601String(),
      id,
      expectedRevision,
    ]);
    return _db.rawDb.updatedRows > 0;
  }

  /// Records an alert attempt audit entry
  Future<void> recordAttempt(AlertAttempt attempt) async {
    _db.rawDb.execute('''
      INSERT INTO alert_attempts (id, occurrence_id, ordinal, planned_at_utc, attempted_at_utc, channel, result, reason_code)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO NOTHING;
    ''', [
      attempt.id,
      attempt.occurrenceId,
      attempt.ordinal,
      attempt.plannedAtUtc.toUtc().toIso8601String(),
      attempt.attemptedAtUtc?.toUtc().toIso8601String(),
      attempt.channel,
      attempt.result,
      attempt.reasonCode,
    ]);
  }

  Future<List<AlertAttempt>> getAttemptsForOccurrence(String occurrenceId) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM alert_attempts WHERE occurrence_id = ? ORDER BY ordinal ASC;',
      [occurrenceId],
    );
    return rows.map((r) => AlertAttempt.fromMap(r)).toList();
  }

  /// Snooze operations
  Future<void> setSnooze(SnoozeRecord snooze) async {
    _db.rawDb.execute('''
      INSERT INTO snooze_records (occurrence_id, until_utc, count, source)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(occurrence_id) DO UPDATE SET
        until_utc = excluded.until_utc,
        count = count + 1,
        source = excluded.source;
    ''', [
      snooze.occurrenceId,
      snooze.untilUtc.toUtc().toIso8601String(),
      snooze.count,
      snooze.source,
    ]);
  }

  Future<SnoozeRecord?> getSnooze(String occurrenceId) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM snooze_records WHERE occurrence_id = ? LIMIT 1;',
      [occurrenceId],
    );
    if (rows.isEmpty) return null;
    return SnoozeRecord.fromMap(rows.first);
  }

  Future<void> clearSnooze(String occurrenceId) async {
    _db.rawDb.execute(
      'DELETE FROM snooze_records WHERE occurrence_id = ?;',
      [occurrenceId],
    );
  }

  /// Platform schedules projections
  Future<void> savePlatformSchedule(PlatformSchedule schedule) async {
    _db.rawDb.execute('''
      INSERT INTO platform_schedules (schedule_key, occurrence_id, revision, platform_token, desired_at_utc, synced_at_utc, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(schedule_key) DO UPDATE SET
        occurrence_id = excluded.occurrence_id,
        revision = excluded.revision,
        platform_token = excluded.platform_token,
        desired_at_utc = excluded.desired_at_utc,
        synced_at_utc = excluded.synced_at_utc,
        status = excluded.status;
    ''', [
      schedule.scheduleKey,
      schedule.occurrenceId,
      schedule.revision,
      schedule.platformToken,
      schedule.desiredAtUtc.toUtc().toIso8601String(),
      schedule.syncedAtUtc?.toUtc().toIso8601String(),
      schedule.status,
    ]);
  }

  /// Outbox pattern methods for crash recovery & zero-loss delivery
  Future<void> enqueueOutbox(OutboxItem item) async {
    _db.rawDb.execute('''
      INSERT INTO outbox_events (id, command, occurrence_id, revision, fire_at_utc, payload_json, created_at_utc, is_processed)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
      item.id,
      item.command,
      item.occurrenceId,
      item.revision,
      item.fireAtUtc.toUtc().toIso8601String(),
      item.payloadJson,
      item.createdAtUtc.toUtc().toIso8601String(),
      item.isProcessed ? 1 : 0,
    ]);
  }

  Future<List<OutboxItem>> getPendingOutbox() async {
    final rows = _db.rawDb.select(
      'SELECT * FROM outbox_events WHERE is_processed = 0 ORDER BY fire_at_utc ASC;',
    );
    return rows.map((r) => OutboxItem.fromMap(r)).toList();
  }

  Future<void> markOutboxProcessed(String id) async {
    _db.rawDb.execute(
      'UPDATE outbox_events SET is_processed = 1 WHERE id = ?;',
      [id],
    );
  }

  /// Atomic transactional save for a Critical Task:
  /// Commits Task, TaskSchedule, AlertRule, initial TaskOccurrence, and OutboxItem in one SQLite transaction.
  Future<void> saveCriticalTaskTransaction({
    required TaskItem task,
    required TaskSchedule schedule,
    required AlertRule rule,
    required TaskOccurrence occurrence,
    required OutboxItem outboxItem,
  }) async {
    // Execute atomic transaction using SQLite BEGIN/COMMIT
    _db.rawDb.execute('BEGIN TRANSACTION;');
    try {
      // 1. Task
      _db.rawDb.execute('''
        INSERT INTO tasks (id, title, description, status, priority, due_at_utc, created_at_utc, updated_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          description = excluded.description,
          status = excluded.status,
          priority = excluded.priority,
          due_at_utc = excluded.due_at_utc,
          updated_at_utc = excluded.updated_at_utc;
      ''', [
        task.id,
        task.title,
        task.description,
        task.status.value,
        task.priority.value,
        task.dueAt?.toUtc().toIso8601String(),
        task.createdAt.toUtc().toIso8601String(),
        task.updatedAt.toUtc().toIso8601String(),
      ]);

      // 2. Schedule
      _db.rawDb.execute('''
        INSERT INTO task_schedules (task_id, local_date_time, zone_id, recurrence_rule, due_policy, grace_minutes)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(task_id) DO UPDATE SET
          local_date_time = excluded.local_date_time,
          zone_id = excluded.zone_id,
          recurrence_rule = excluded.recurrence_rule,
          due_policy = excluded.due_policy,
          grace_minutes = excluded.grace_minutes;
      ''', [
        schedule.taskId,
        schedule.localDateTime,
        schedule.zoneId,
        schedule.recurrenceRule,
        schedule.duePolicy.name,
        schedule.graceMinutes,
      ]);

      // 3. Rule
      _db.rawDb.execute('''
        INSERT INTO alert_rules (id, task_id, lead_minutes, channel, escalation_steps_json, quiet_hours_policy, enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          lead_minutes = excluded.lead_minutes,
          channel = excluded.channel,
          escalation_steps_json = excluded.escalation_steps_json,
          quiet_hours_policy = excluded.quiet_hours_policy,
          enabled = excluded.enabled;
      ''', [
        rule.id,
        rule.taskId,
        rule.leadMinutes,
        rule.channel,
        rule.escalationSteps.join(','),
        rule.quietHoursPolicy.name,
        rule.enabled ? 1 : 0,
      ]);

      // 4. Occurrence
      _db.rawDb.execute('''
        INSERT INTO task_occurrences (id, task_id, planned_at_utc, local_date, zone_id, revision, state, acknowledged_at_utc)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          planned_at_utc = excluded.planned_at_utc,
          local_date = excluded.local_date,
          zone_id = excluded.zone_id,
          revision = excluded.revision,
          state = excluded.state,
          acknowledged_at_utc = excluded.acknowledged_at_utc;
      ''', [
        occurrence.id,
        occurrence.taskId,
        occurrence.plannedAtUtc.toUtc().toIso8601String(),
        occurrence.localDate,
        occurrence.zoneId,
        occurrence.revision,
        occurrence.state.name,
        occurrence.acknowledgedAt?.toUtc().toIso8601String(),
      ]);

      // 5. Outbox Event
      _db.rawDb.execute('''
        INSERT INTO outbox_events (id, command, occurrence_id, revision, fire_at_utc, payload_json, created_at_utc, is_processed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
      ''', [
        outboxItem.id,
        outboxItem.command,
        outboxItem.occurrenceId,
        outboxItem.revision,
        outboxItem.fireAtUtc.toUtc().toIso8601String(),
        outboxItem.payloadJson,
        outboxItem.createdAtUtc.toUtc().toIso8601String(),
        0,
      ]);

      _db.rawDb.execute('COMMIT;');
    } catch (e) {
      _db.rawDb.execute('ROLLBACK;');
      rethrow;
    }
  }
}
