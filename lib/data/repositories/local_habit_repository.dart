import 'package:sqlite3/sqlite3.dart';
import '../../domain/models/habit_item.dart';
import '../database/app_database.dart';

abstract class IHabitRepository {
  Future<List<HabitItem>> getHabits();
  Future<void> saveHabit(HabitItem habit);
  Future<void> toggleHabitToday(String id);
  Future<void> deleteHabit(String id);
}

class LocalHabitRepository implements IHabitRepository {
  final AppDatabase _dbManager;

  LocalHabitRepository(this._dbManager);

  Database get _db => _dbManager.rawDb;

  @override
  Future<List<HabitItem>> getHabits() async {
    final results = _db.select('SELECT * FROM habits ORDER BY current_streak DESC, created_at_utc ASC;');
    return results.map((row) => HabitItem.fromMap(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<void> saveHabit(HabitItem habit) async {
    final stmt = _db.prepare('''
      INSERT INTO habits (
        id, name, schedule_rule, target_per_period,
        current_streak, best_streak, is_completed_today, created_at_utc
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        schedule_rule = excluded.schedule_rule,
        target_per_period = excluded.target_per_period,
        current_streak = excluded.current_streak,
        best_streak = excluded.best_streak,
        is_completed_today = excluded.is_completed_today;
    ''');

    try {
      stmt.execute([
        habit.id,
        habit.name,
        habit.scheduleRule,
        habit.targetPerPeriod,
        habit.currentStreak,
        habit.bestStreak,
        habit.isCompletedToday ? 1 : 0,
        habit.createdAt.toUtc().toIso8601String(),
      ]);
    } finally {
      stmt.close();
    }
  }

  @override
  Future<void> toggleHabitToday(String id) async {
    final selectStmt = _db.prepare('SELECT is_completed_today, current_streak, best_streak FROM habits WHERE id = ?;');
    int isCompleted = 0;
    int currentStreak = 0;
    int bestStreak = 0;

    try {
      final rows = selectStmt.select([id]);
      if (rows.isEmpty) return;
      isCompleted = rows.first['is_completed_today'] as int;
      currentStreak = rows.first['current_streak'] as int;
      bestStreak = rows.first['best_streak'] as int;
    } finally {
      selectStmt.close();
    }

    final newCompleted = isCompleted == 1 ? 0 : 1;
    final newStreak = newCompleted == 1 ? currentStreak + 1 : (currentStreak > 0 ? currentStreak - 1 : 0);
    final newBest = newStreak > bestStreak ? newStreak : bestStreak;

    final updateStmt = _db.prepare('''
      UPDATE habits 
      SET is_completed_today = ?, current_streak = ?, best_streak = ?
      WHERE id = ?;
    ''');

    try {
      updateStmt.execute([newCompleted, newStreak, newBest, id]);
    } finally {
      updateStmt.close();
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    final stmt = _db.prepare('DELETE FROM habits WHERE id = ?;');
    try {
      stmt.execute([id]);
    } finally {
      stmt.close();
    }
  }
}
