import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/event_item.dart';
import '../database/app_database.dart';

abstract class IEventRepository {
  Future<List<EventItem>> getEvents();
  Future<List<EventItem>> getEventsForDate(DateTime date);
  Future<EventItem?> getEventById(String id);
  Future<void> saveEvent(EventItem event);
  Future<void> deleteEvent(String id);
}

class LocalEventRepository implements IEventRepository {
  final AppDatabase _dbManager;

  LocalEventRepository(this._dbManager);

  Database get _db => _dbManager.rawDb;

  @override
  Future<List<EventItem>> getEvents() async {
    final results = _db.select('SELECT * FROM events ORDER BY starts_at_utc ASC;');
    return results.map((row) => EventItem.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<List<EventItem>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc().toIso8601String();

    final stmt = _db.prepare('''
      SELECT * FROM events 
      WHERE (starts_at_utc <= ? AND ends_at_utc >= ?)
      ORDER BY starts_at_utc ASC;
    ''');
    try {
      final results = stmt.select([endOfDay, startOfDay]);
      return results.map((row) => EventItem.fromMap(Map<String, dynamic>.from(row))).toList();
    } finally {
      stmt.close();
    }
  }

  @override
  Future<EventItem?> getEventById(String id) async {
    final stmt = _db.prepare('SELECT * FROM events WHERE id = ? LIMIT 1;');
    try {
      final results = stmt.select([id]);
      if (results.isEmpty) return null;
      return EventItem.fromMap(Map<String, dynamic>.from(results.first));
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> saveEvent(EventItem event) async {
    final stmt = _db.prepare('''
      INSERT INTO events (
        id, title, description, starts_at_utc, ends_at_utc,
        is_all_day, location, color_hex, created_at_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        description = excluded.description,
        starts_at_utc = excluded.starts_at_utc,
        ends_at_utc = excluded.ends_at_utc,
        is_all_day = excluded.is_all_day,
        location = excluded.location,
        color_hex = excluded.color_hex;
    ''');

    try {
      stmt.execute([
        event.id,
        event.title,
        event.description,
        event.startsAt.toUtc().toIso8601String(),
        event.endsAt.toUtc().toIso8601String(),
        event.isAllDay ? 1 : 0,
        event.location,
        event.colorHex,
        event.createdAt.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> deleteEvent(String id) async {
    final stmt = _db.prepare('DELETE FROM events WHERE id = ?;');
    try {
      stmt.execute([id]);
    } finally {
      stmt.close();
    }
  }
}
