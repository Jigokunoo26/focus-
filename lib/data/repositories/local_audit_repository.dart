import '../database/app_database.dart';
import '../../domain/models/audit_event_item.dart';

class LocalAuditRepository {
  final AppDatabase _db;

  LocalAuditRepository(this._db);

  Future<void> logEvent({
    required String id,
    required String eventType,
    String? ownerId,
    required String title,
    String details = '',
    required DateTime createdAt,
  }) async {
    final raw = _db.rawDb;
    raw.execute(
      '''
      INSERT INTO audit_events (id, event_type, owner_id, title, details, created_at_utc)
      VALUES (?, ?, ?, ?, ?, ?);
      ''',
      [
        id,
        eventType,
        ownerId,
        title,
        details,
        createdAt.toUtc().toIso8601String(),
      ],
    );
  }

  Future<List<AuditEventItem>> getRecentAuditEvents({int limit = 50}) async {
    final raw = _db.rawDb;
    final results = raw.select(
      '''
      SELECT * FROM audit_events
      ORDER BY created_at_utc DESC
      LIMIT ?;
      ''',
      [limit],
    );

    return results.map((row) => AuditEventItem.fromMap(row)).toList();
  }

  Future<void> clearAll() async {
    final raw = _db.rawDb;
    raw.execute('DELETE FROM audit_events;');
  }
}
