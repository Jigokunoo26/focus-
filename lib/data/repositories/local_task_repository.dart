import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/task_item.dart';
import '../database/app_database.dart';

abstract class ITaskRepository {
  Future<List<TaskItem>> getTasks();
  Future<TaskItem?> getTaskById(String id);
  Future<void> saveTask(TaskItem task);
  Future<void> deleteTask(String id);
  Future<void> updateTaskStatus(String id, TaskStatus status);
}

class LocalTaskRepository implements ITaskRepository {
  final AppDatabase _dbManager;

  LocalTaskRepository(this._dbManager);

  Database get _db => _dbManager.rawDb;

  @override
  Future<List<TaskItem>> getTasks() async {
    final results = _db.select(
      'SELECT * FROM tasks ORDER BY status ASC, priority DESC, due_at_utc ASC, created_at_utc DESC;',
    );

    return results.map((row) {
      return TaskItem.fromMap(Map<String, dynamic>.from(row));
    }).toList();
  }

  @override
  Future<TaskItem?> getTaskById(String id) async {
    final stmt = _db.prepare('SELECT * FROM tasks WHERE id = ? LIMIT 1;');
    try {
      final results = stmt.select([id]);
      if (results.isEmpty) return null;
      return TaskItem.fromMap(Map<String, dynamic>.from(results.first));
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> saveTask(TaskItem task) async {
    final stmt = _db.prepare('''
      INSERT INTO tasks (
        id, title, description, status, priority, due_at_utc,
        timezone_id, project_id, parent_task_id, created_at_utc,
        updated_at_utc, completed_at_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        description = excluded.description,
        status = excluded.status,
        priority = excluded.priority,
        due_at_utc = excluded.due_at_utc,
        timezone_id = excluded.timezone_id,
        project_id = excluded.project_id,
        parent_task_id = excluded.parent_task_id,
        updated_at_utc = excluded.updated_at_utc,
        completed_at_utc = excluded.completed_at_utc;
    ''');

    try {
      stmt.execute([
        task.id,
        task.title,
        task.description,
        task.status.value,
        task.priority.value,
        task.dueAt?.toUtc().toIso8601String(),
        task.timezoneId,
        task.projectId,
        task.parentTaskId,
        task.createdAt.toUtc().toIso8601String(),
        DateTime.now().toUtc().toIso8601String(),
        task.completedAt?.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    final stmt = _db.prepare('DELETE FROM tasks WHERE id = ?;');
    try {
      stmt.execute([id]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> updateTaskStatus(String id, TaskStatus status) async {
    final stmt = _db.prepare('''
      UPDATE tasks 
      SET status = ?, 
          updated_at_utc = ?, 
          completed_at_utc = ?
      WHERE id = ?;
    ''');

    final now = DateTime.now().toUtc().toIso8601String();
    final completedAt = status == TaskStatus.completed ? now : null;

    try {
      stmt.execute([status.value, now, completedAt, id]);
    } finally {
      stmt.close();
    }
  }
}
