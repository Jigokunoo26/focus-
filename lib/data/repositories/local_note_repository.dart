import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/note_item.dart';
import '../database/app_database.dart';

abstract class INoteRepository {
  Future<List<NoteItem>> getNotes();
  Future<NoteItem?> getNoteById(String id);
  Future<void> saveNote(NoteItem note);
  Future<void> deleteNote(String id);
}

class LocalNoteRepository implements INoteRepository {
  final AppDatabase _dbManager;

  LocalNoteRepository(this._dbManager);

  Database get _db => _dbManager.rawDb;

  @override
  Future<List<NoteItem>> getNotes() async {
    final results = _db.select('SELECT * FROM notes ORDER BY updated_at_utc DESC;');
    return results.map((row) => NoteItem.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<NoteItem?> getNoteById(String id) async {
    final stmt = _db.prepare('SELECT * FROM notes WHERE id = ? LIMIT 1;');
    try {
      final results = stmt.select([id]);
      if (results.isEmpty) return null;
      return NoteItem.fromMap(Map<String, dynamic>.from(results.first));
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> saveNote(NoteItem note) async {
    final stmt = _db.prepare('''
      INSERT INTO notes (
        id, title, content, tags, linked_entity_id, created_at_utc, updated_at_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        content = excluded.content,
        tags = excluded.tags,
        linked_entity_id = excluded.linked_entity_id,
        updated_at_utc = excluded.updated_at_utc;
    ''');

    try {
      stmt.execute([
        note.id,
        note.title,
        note.content,
        note.tags,
        note.linkedEntityId,
        note.createdAt.toUtc().toIso8601String(),
        note.updatedAt.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    final stmt = _db.prepare('DELETE FROM notes WHERE id = ?;');
    try {
      stmt.execute([id]);
    } finally {
      stmt.close();
    }
  }
}
