import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/project_item.dart';
import '../database/app_database.dart';

abstract class IProjectRepository {
  Future<List<ProjectItem>> getProjects();
  Future<ProjectItem?> getProjectById(String id);
  Future<void> saveProject(ProjectItem project);
  Future<void> deleteProject(String id);
}

class LocalProjectRepository implements IProjectRepository {
  final AppDatabase _dbManager;

  LocalProjectRepository(this._dbManager);

  Database get _db => _dbManager.rawDb;

  @override
  Future<List<ProjectItem>> getProjects() async {
    final results = _db.select('SELECT * FROM projects ORDER BY created_at_utc DESC;');
    return results.map((row) => ProjectItem.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<ProjectItem?> getProjectById(String id) async {
    final stmt = _db.prepare('SELECT * FROM projects WHERE id = ? LIMIT 1;');
    try {
      final results = stmt.select([id]);
      if (results.isEmpty) return null;
      return ProjectItem.fromMap(Map<String, dynamic>.from(results.first));
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> saveProject(ProjectItem project) async {
    final stmt = _db.prepare('''
      INSERT INTO projects (
        id, name, description, status, color_hex, icon_name,
        deadline_utc, created_at_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        description = excluded.description,
        status = excluded.status,
        color_hex = excluded.color_hex,
        icon_name = excluded.icon_name,
        deadline_utc = excluded.deadline_utc;
    ''');

    try {
      stmt.execute([
        project.id,
        project.name,
        project.description,
        project.status,
        project.colorHex,
        project.iconName,
        project.deadline?.toUtc().toIso8601String(),
        project.createdAt.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    final stmt = _db.prepare('DELETE FROM projects WHERE id = ?;');
    try {
      stmt.execute([id]);
    } finally {
      stmt.close();
    }
  }
}
