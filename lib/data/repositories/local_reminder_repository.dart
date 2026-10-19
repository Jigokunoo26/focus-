import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/reminder_item.dart';
import '../database/app_database.dart';

abstract class IReminderRepository {
  Future<List<ReminderItem>> getReminders();
  Future<List<ReminderItem>> getActiveReminders();
  Future<ReminderItem?> getReminderById(String id);
  Future<void> saveReminder(ReminderItem reminder);
  Future<void> updateReminderState(String id, ReminderState state);
  Future<void> deleteReminder(String id);
}

class LocalReminderRepository implements IReminderRepository {
  final AppDatabase _dbManager;

  LocalReminderRepository(this._dbManager);

  Database get _db => _dbManager.rawDb;

  @override
  Future<List<ReminderItem>> getReminders() async {
    final results = _db.select(
      'SELECT * FROM reminders ORDER BY trigger_at_utc ASC;',
    );
    return results.map((row) => ReminderItem.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<List<ReminderItem>> getActiveReminders() async {
    final results = _db.select(
      "SELECT * FROM reminders WHERE state IN ('pending', 'scheduled') ORDER BY trigger_at_utc ASC;",
    );
    return results.map((row) => ReminderItem.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<ReminderItem?> getReminderById(String id) async {
    final results = _db.select('SELECT * FROM reminders WHERE id = ?;', [id]);
    if (results.isEmpty) return null;
    return ReminderItem.fromMap(Map<String, dynamic>.from(results.first));
  }

  @override
  Future<void> saveReminder(ReminderItem reminder) async {
    final stmt = _db.prepare('''
      INSERT INTO reminders (
        id, owner_type, owner_id, title, notes,
        trigger_at_utc, state, notification_id, created_at_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        notes = excluded.notes,
        trigger_at_utc = excluded.trigger_at_utc,
        state = excluded.state,
        notification_id = excluded.notification_id;
    ''');

    try {
      stmt.execute([
        reminder.id,
        reminder.ownerType,
        reminder.ownerId,
        reminder.title,
        reminder.notes,
        reminder.triggerAt.toUtc().toIso8601String(),
        reminder.state.value,
        reminder.notificationId,
        reminder.createdAt.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> updateReminderState(String id, ReminderState state) async {
    final stmt = _db.prepare('UPDATE reminders SET state = ? WHERE id = ?;');
    try {
      stmt.execute([state.value, id]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    final stmt = _db.prepare('DELETE FROM reminders WHERE id = ?;');
    try {
      stmt.execute([id]);
    } finally {
      stmt.close();
    }
  }
}
