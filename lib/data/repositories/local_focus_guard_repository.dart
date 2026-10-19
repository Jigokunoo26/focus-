import '../database/app_database.dart';
import '../../domain/models/focus_guard_models.dart';

class LocalFocusGuardRepository {
  final AppDatabase _db;

  LocalFocusGuardRepository(this._db);

  /// Saves or updates a FocusPolicy
  Future<void> savePolicy(FocusPolicy policy) async {
    _db.rawDb.execute('''
      INSERT INTO focus_policies (id, name, monitored_targets_json, grace_seconds, cooldown_seconds, block_mode, prompt_text)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        monitored_targets_json = excluded.monitored_targets_json,
        grace_seconds = excluded.grace_seconds,
        cooldown_seconds = excluded.cooldown_seconds,
        block_mode = excluded.block_mode,
        prompt_text = excluded.prompt_text;
    ''', [
      policy.id,
      policy.name,
      policy.monitoredTargets.join(','),
      policy.graceSeconds,
      policy.cooldownSeconds,
      policy.blockMode.name,
      policy.promptText,
    ]);
  }

  Future<FocusPolicy?> getPolicy(String id) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM focus_policies WHERE id = ? LIMIT 1;',
      [id],
    );
    if (rows.isEmpty) return null;
    return FocusPolicy.fromMap(rows.first);
  }

  Future<FocusPolicy> getActivePolicy() async {
    final rows = _db.rawDb.select('SELECT * FROM focus_policies LIMIT 1;');
    if (rows.isNotEmpty) {
      return FocusPolicy.fromMap(rows.first);
    }
    // Fallback default policy
    const defaultPolicy = FocusPolicy(
      id: 'policy-default',
      name: 'Default Deep Work Shield',
    );
    await savePolicy(defaultPolicy);
    return defaultPolicy;
  }

  /// Creates a new Focus Guard session
  Future<void> createSession(FocusSession session) async {
    _db.rawDb.execute('''
      INSERT INTO focus_sessions (id, policy_id, task_id, started_at_utc, planned_end_utc, ended_at_utc, state, source)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        state = excluded.state,
        ended_at_utc = excluded.ended_at_utc;
    ''', [
      session.id,
      session.policyId,
      session.taskId,
      session.startedAtUtc.toUtc().toIso8601String(),
      session.plannedEndUtc.toUtc().toIso8601String(),
      session.endedAtUtc?.toUtc().toIso8601String(),
      session.state.name,
      session.source,
    ]);
  }

  Future<void> updateSessionState(String id, FocusGuardState newState, {DateTime? endedAt}) async {
    _db.rawDb.execute('''
      UPDATE focus_sessions
      SET state = ?, ended_at_utc = ?
      WHERE id = ?;
    ''', [
      newState.name,
      endedAt?.toUtc().toIso8601String(),
      id,
    ]);
  }

  Future<FocusSession?> getActiveSession() async {
    final rows = _db.rawDb.select('''
      SELECT * FROM focus_sessions
      WHERE state NOT IN ('completed', 'inactive')
      ORDER BY started_at_utc DESC
      LIMIT 1;
    ''');
    if (rows.isEmpty) return null;
    return FocusSession.fromMap(rows.first);
  }

  Future<List<FocusSession>> getRecentSessions({int limit = 10}) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM focus_sessions ORDER BY started_at_utc DESC LIMIT ?;',
      [limit],
    );
    return rows.map((r) => FocusSession.fromMap(r)).toList();
  }

  /// Appends an event to the 30-day privacy-safe event history
  Future<void> logFocusEvent(FocusEvent event) async {
    _db.rawDb.execute('''
      INSERT INTO focus_events (id, session_id, occurred_at_utc, kind, target_app_id, decision, trigger_id)
      VALUES (?, ?, ?, ?, ?, ?, ?);
    ''', [
      event.id,
      event.sessionId,
      event.occurredAtUtc.toUtc().toIso8601String(),
      event.kind,
      event.targetAppId,
      event.decision,
      event.triggerId,
    ]);
  }

  Future<List<FocusEvent>> getRecentFocusEvents({int limit = 50}) async {
    final rows = _db.rawDb.select(
      'SELECT * FROM focus_events ORDER BY occurred_at_utc DESC LIMIT ?;',
      [limit],
    );
    return rows.map((r) => FocusEvent.fromMap(r)).toList();
  }

  /// Enforces 30-day retention and local data deletion
  Future<int> clearFocusEventsBefore(DateTime cutoffUtc) async {
    _db.rawDb.execute(
      'DELETE FROM focus_events WHERE occurred_at_utc < ?;',
      [cutoffUtc.toUtc().toIso8601String()],
    );
    return _db.rawDb.updatedRows;
  }

  Future<void> clearAllFocusEvents() async {
    _db.rawDb.execute('DELETE FROM focus_events;');
  }

  Future<int> pruneOldEvents({int days = 30}) async {
    if (days == 0) {
      await clearAllFocusEvents();
      return 0;
    }
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
    return clearFocusEventsBefore(cutoff);
  }

  /// Cooldown Management
  Future<void> setCooldown(FocusCooldown cooldown) async {
    _db.rawDb.execute('''
      INSERT INTO cooldown_records (session_id, target_app_id, until_utc, reason)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(session_id, target_app_id) DO UPDATE SET
        until_utc = excluded.until_utc,
        reason = excluded.reason;
    ''', [
      cooldown.sessionId,
      cooldown.targetAppId,
      cooldown.untilUtc.toUtc().toIso8601String(),
      cooldown.reason,
    ]);
  }

  Future<FocusCooldown?> getActiveCooldown(String sessionId, String targetAppId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = _db.rawDb.select('''
      SELECT * FROM cooldown_records
      WHERE session_id = ? AND target_app_id = ? AND until_utc > ?
      LIMIT 1;
    ''', [sessionId, targetAppId, now]);
    if (rows.isEmpty) return null;
    return FocusCooldown.fromMap(rows.first);
  }

  Future<void> cleanExpiredCooldowns() async {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.rawDb.execute('DELETE FROM cooldown_records WHERE until_utc <= ?;', [now]);
  }
}
