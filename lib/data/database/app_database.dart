import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Local SQLite Database manager providing persistent transactional storage
/// with versioned migrations for Android, Windows, and testing environments.
class AppDatabase {
  static AppDatabase? _instance;
  late final Database _db;

  AppDatabase._(this._db) {
    _initSchema();
  }

  static Future<AppDatabase> getInstance({bool inMemory = false}) async {
    if (_instance != null && !inMemory) return _instance!;

    Database db;
    if (inMemory || kIsWeb) {
      db = sqlite3.openInMemory();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, 'focus_personal_os.db');
      db = sqlite3.open(dbPath);
    }

    _instance = AppDatabase._(db);
    return _instance!;
  }

  Database get rawDb => _db;

  void _initSchema() {
    _db.execute('PRAGMA foreign_keys = ON;');

    // Tasks Table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'todo',
        priority INTEGER NOT NULL DEFAULT 2,
        due_at_utc TEXT,
        timezone_id TEXT,
        project_id TEXT,
        parent_task_id TEXT,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL,
        completed_at_utc TEXT
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at_utc);');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);');

    // Projects Table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'active',
        color_hex TEXT NOT NULL DEFAULT '#FFFFFF',
        icon_name TEXT NOT NULL DEFAULT 'folder',
        deadline_utc TEXT,
        created_at_utc TEXT NOT NULL
      );
    ''');

    // Events Table (Calendar & Timeline)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        starts_at_utc TEXT NOT NULL,
        ends_at_utc TEXT NOT NULL,
        is_all_day INTEGER NOT NULL DEFAULT 0,
        location TEXT,
        color_hex TEXT NOT NULL DEFAULT '#FF3B30',
        created_at_utc TEXT NOT NULL
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_events_start ON events(starts_at_utc);');

    // Reminders Table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        owner_type TEXT NOT NULL DEFAULT 'task',
        owner_id TEXT,
        title TEXT NOT NULL,
        notes TEXT,
        trigger_at_utc TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        notification_id INTEGER NOT NULL,
        created_at_utc TEXT NOT NULL
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(trigger_at_utc);');

    // Habits Table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        schedule_rule TEXT NOT NULL DEFAULT 'daily',
        target_per_period INTEGER NOT NULL DEFAULT 1,
        current_streak INTEGER NOT NULL DEFAULT 0,
        best_streak INTEGER NOT NULL DEFAULT 0,
        is_completed_today INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      );
    ''');

    // Screens & Widgets Layout Table (Custom OS layout engine)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS screens (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'layout',
        sort_order INTEGER NOT NULL DEFAULT 0,
        layout_json TEXT NOT NULL
      );
    ''');

    // Notes Table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        tags TEXT NOT NULL DEFAULT '',
        linked_entity_id TEXT,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at_utc DESC);');

    // App Preferences / Settings Table
    _db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL
      );
    ''');

    // Audit Events Table (Stage 3 deterministic reliability logging)
    _db.execute('''
      CREATE TABLE IF NOT EXISTS audit_events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        owner_id TEXT,
        title TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        created_at_utc TEXT NOT NULL
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_events(created_at_utc DESC);');

    // === PHASE 5: CRITICAL TASK & ALERT ENGINE SCHEMA ===
    _db.execute('''
      CREATE TABLE IF NOT EXISTS task_schedules (
        task_id TEXT PRIMARY KEY,
        local_date_time TEXT NOT NULL,
        zone_id TEXT NOT NULL DEFAULT 'UTC',
        recurrence_rule TEXT,
        due_policy TEXT NOT NULL DEFAULT 'gracePeriod',
        grace_minutes INTEGER NOT NULL DEFAULT 15
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS alert_rules (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        lead_minutes INTEGER NOT NULL DEFAULT 0,
        channel TEXT NOT NULL DEFAULT 'notification',
        escalation_steps_json TEXT NOT NULL DEFAULT '15',
        quiet_hours_policy TEXT NOT NULL DEFAULT 'silent',
        enabled INTEGER NOT NULL DEFAULT 1
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_alert_rules_task ON alert_rules(task_id);');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS task_occurrences (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        planned_at_utc TEXT NOT NULL,
        local_date TEXT NOT NULL,
        zone_id TEXT NOT NULL DEFAULT 'UTC',
        revision INTEGER NOT NULL DEFAULT 1,
        state TEXT NOT NULL DEFAULT 'scheduled',
        acknowledged_at_utc TEXT
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_occurrences_plan ON task_occurrences(planned_at_utc);');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_occurrences_task ON task_occurrences(task_id);');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS alert_attempts (
        id TEXT PRIMARY KEY,
        occurrence_id TEXT NOT NULL,
        ordinal INTEGER NOT NULL DEFAULT 0,
        planned_at_utc TEXT NOT NULL,
        attempted_at_utc TEXT,
        channel TEXT NOT NULL,
        result TEXT NOT NULL,
        reason_code TEXT
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_attempts_occ ON alert_attempts(occurrence_id);');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS snooze_records (
        occurrence_id TEXT PRIMARY KEY,
        until_utc TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        source TEXT NOT NULL DEFAULT 'notification_action'
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS platform_schedules (
        schedule_key TEXT PRIMARY KEY,
        occurrence_id TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1,
        platform_token TEXT,
        desired_at_utc TEXT NOT NULL,
        synced_at_utc TEXT,
        status TEXT NOT NULL DEFAULT 'synced'
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS outbox_events (
        id TEXT PRIMARY KEY,
        command TEXT NOT NULL,
        occurrence_id TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1,
        fire_at_utc TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}',
        created_at_utc TEXT NOT NULL,
        is_processed INTEGER NOT NULL DEFAULT 0
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox_events(is_processed, fire_at_utc);');

    // === PHASE 7: FOCUS GUARD SCHEMA ===
    _db.execute('''
      CREATE TABLE IF NOT EXISTS focus_policies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        monitored_targets_json TEXT NOT NULL,
        grace_seconds INTEGER NOT NULL DEFAULT 5,
        cooldown_seconds INTEGER NOT NULL DEFAULT 60,
        block_mode TEXT NOT NULL DEFAULT 'reminder',
        prompt_text TEXT NOT NULL
      );
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS focus_sessions (
        id TEXT PRIMARY KEY,
        policy_id TEXT NOT NULL,
        task_id TEXT,
        started_at_utc TEXT NOT NULL,
        planned_end_utc TEXT NOT NULL,
        ended_at_utc TEXT,
        state TEXT NOT NULL DEFAULT 'monitoring',
        source TEXT NOT NULL DEFAULT 'manual'
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_focus_sessions_start ON focus_sessions(started_at_utc);');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS focus_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        occurred_at_utc TEXT NOT NULL,
        kind TEXT NOT NULL,
        target_app_id TEXT,
        decision TEXT NOT NULL,
        trigger_id TEXT
      );
    ''');
    _db.execute('CREATE INDEX IF NOT EXISTS idx_focus_events_time ON focus_events(occurred_at_utc);');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS cooldown_records (
        session_id TEXT NOT NULL,
        target_app_id TEXT NOT NULL,
        until_utc TEXT NOT NULL,
        reason TEXT NOT NULL,
        PRIMARY KEY (session_id, target_app_id)
      );
    ''');

    // Seed default starter screens if empty
    _seedDefaultDataIfEmpty();
  }

  void _seedDefaultDataIfEmpty() {
    final result = _db.select('SELECT COUNT(*) as count FROM screens;');
    final count = result.first['count'] as int;
    if (count == 0) {
      final now = DateTime.now().toUtc().toIso8601String();
      // Insert default Home Screen layout
      _db.execute('''
        INSERT INTO screens (id, name, icon, sort_order, layout_json)
        VALUES (
          'home',
          'Command Center',
          'layout-dashboard',
          0,
          '{"widgets": ["clock_date", "daily_overview", "quick_actions", "task_glance", "focus_timer", "habit_streak", "countdown", "device_status"]}'
        );
      ''');

      // Seed starter tasks if empty
      final taskCountResult = _db.select('SELECT COUNT(*) as count FROM tasks;');
      if ((taskCountResult.first['count'] as int) == 0) {
        final sampleDue = DateTime.now().add(const Duration(hours: 3)).toUtc().toIso8601String();
        _db.execute('''
          INSERT INTO tasks (id, title, description, status, priority, due_at_utc, created_at_utc, updated_at_utc)
          VALUES 
          ('task-init-1', 'Review Master Implementation Plan', 'Verified Nothing OS aesthetics and local database pipeline.', 'completed', 3, '$now', '$now', '$now'),
          ('task-init-2', 'Finalize Foundation Architecture', 'Complete Stage 1 core widgets, design tokens, and state flow.', 'in_progress', 3, '$sampleDue', '$now', '$now'),
          ('task-init-3', 'Configure Reminder Notification Channel', 'Prepare local exact alarm scheduling.', 'todo', 2, '$sampleDue', '$now', '$now');
        ''');

        // Seed initial habits
        _db.execute('''
          INSERT INTO habits (id, name, schedule_rule, target_per_period, current_streak, best_streak, is_completed_today, created_at_utc)
          VALUES
          ('habit-1', 'Morning Deep Focus', 'daily', 1, 4, 12, 1, '$now'),
          ('habit-2', 'Project Milestone Review', 'daily', 1, 6, 15, 0, '$now');
        ''');

        // Seed initial project
        _db.execute('''
          INSERT INTO projects (id, name, description, status, color_hex, icon_name, created_at_utc)
          VALUES
          ('project-os', 'FOCUS Personal OS', 'Offline-first, zero-cloud personal productivity platform.', 'active', '#FF3B30', 'cpu', '$now');
        ''');

        // Seed initial note
        _db.execute('''
          INSERT INTO notes (id, title, content, tags, created_at_utc, updated_at_utc)
          VALUES
          ('note-welcome', 'Welcome to FOCUS', '# FOCUS Personal OS\n\n- Pure local persistence (SQLite)\n- Apple squircle & frosted glass polish\n- Nothing OS high-contrast minimalism\n- Zero cloud dependencies', 'system, welcome', '$now', '$now');
        ''');

        // Seed initial event for today
        final eventStart = DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String();
        final eventEnd = DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String();
        _db.execute('''
          INSERT INTO events (id, title, description, starts_at_utc, ends_at_utc, is_all_day, location, color_hex, created_at_utc)
          VALUES
          ('event-init-1', 'Architecture Deep Work Session', 'Review Stage 2 productivity workflows and agenda timeline.', '$eventStart', '$eventEnd', 0, 'Command Center', '#FF3B30', '$now');
        ''');
      }
    }

    // Seed default Focus Guard policy if empty
    final policyCountResult = _db.select('SELECT COUNT(*) as count FROM focus_policies;');
    if ((policyCountResult.first['count'] as int) == 0) {
      _db.execute('''
        INSERT INTO focus_policies (id, name, monitored_targets_json, grace_seconds, cooldown_seconds, block_mode, prompt_text)
        VALUES (
          'policy-default',
          'Default Deep Work Shield',
          'com.instagram.android,com.zhiliaoapp.musically,com.twitter.android,com.google.android.youtube,com.reddit.frontpage,com.discord,chrome.exe,Discord.exe',
          5,
          60,
          'reminder',
          'You are distracted. Return to your task.'
        );
      ''');
    }
  }

  void close() {
    _db.close();
  }

  /// Exports all core user data to a local JSON string (Master Plan Stage 6)
  Future<String> exportDataJson() async {
    final tasks = _db.select('SELECT * FROM tasks;');
    final habits = _db.select('SELECT * FROM habits;');
    final projects = _db.select('SELECT * FROM projects;');
    final notes = _db.select('SELECT * FROM notes;');
    final events = _db.select('SELECT * FROM events;');
    final focusPolicies = _db.select('SELECT * FROM focus_policies;');

    final data = {
      'version': 1,
      'app': 'FOCUS Personal OS',
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map((r) => Map<String, dynamic>.from(r)).toList(),
      'habits': habits.map((r) => Map<String, dynamic>.from(r)).toList(),
      'projects': projects.map((r) => Map<String, dynamic>.from(r)).toList(),
      'notes': notes.map((r) => Map<String, dynamic>.from(r)).toList(),
      'events': events.map((r) => Map<String, dynamic>.from(r)).toList(),
      'focus_policies': focusPolicies.map((r) => Map<String, dynamic>.from(r)).toList(),
    };

    return jsonEncode(data);
  }

  /// Imports JSON backup into local SQLite with conflict resolution
  Future<int> importDataJson(String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    int importedCount = 0;

    _db.execute('BEGIN TRANSACTION;');
    try {
      if (data.containsKey('tasks') && data['tasks'] is List) {
        for (final row in data['tasks']) {
          _db.execute('''
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
            row['id'],
            row['title'],
            row['description'] ?? '',
            row['status'] ?? 'todo',
            row['priority'] ?? 2,
            row['due_at_utc'],
            row['created_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
            row['updated_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
          ]);
          importedCount++;
        }
      }

      if (data.containsKey('habits') && data['habits'] is List) {
        for (final row in data['habits']) {
          _db.execute('''
            INSERT INTO habits (id, name, schedule_rule, created_at_utc)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              schedule_rule = excluded.schedule_rule;
          ''', [
            row['id'],
            row['name'],
            row['schedule_rule'] ?? 'daily',
            row['created_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
          ]);
          importedCount++;
        }
      }

      if (data.containsKey('projects') && data['projects'] is List) {
        for (final row in data['projects']) {
          _db.execute('''
            INSERT INTO projects (id, name, description, color_hex, deadline_utc, created_at_utc)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              name = excluded.name,
              description = excluded.description,
              color_hex = excluded.color_hex,
              deadline_utc = excluded.deadline_utc;
          ''', [
            row['id'],
            row['name'],
            row['description'] ?? '',
            row['color_hex'] ?? '#FF3B30',
            row['deadline_utc'],
            row['created_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
          ]);
          importedCount++;
        }
      }

      if (data.containsKey('notes') && data['notes'] is List) {
        for (final row in data['notes']) {
          _db.execute('''
            INSERT INTO notes (id, title, content, tags, created_at_utc, updated_at_utc)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              title = excluded.title,
              content = excluded.content,
              tags = excluded.tags,
              updated_at_utc = excluded.updated_at_utc;
          ''', [
            row['id'],
            row['title'],
            row['content'] ?? '',
            row['tags'] ?? '',
            row['created_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
            row['updated_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
          ]);
          importedCount++;
        }
      }

      if (data.containsKey('events') && data['events'] is List) {
        for (final row in data['events']) {
          _db.execute('''
            INSERT INTO events (id, title, description, starts_at_utc, ends_at_utc, is_all_day, location, color_hex, created_at_utc)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              title = excluded.title,
              description = excluded.description,
              starts_at_utc = excluded.starts_at_utc,
              ends_at_utc = excluded.ends_at_utc,
              is_all_day = excluded.is_all_day,
              location = excluded.location,
              color_hex = excluded.color_hex;
          ''', [
            row['id'],
            row['title'],
            row['description'] ?? '',
            row['starts_at_utc'],
            row['ends_at_utc'],
            row['is_all_day'] ?? 0,
            row['location'] ?? '',
            row['color_hex'] ?? '#FF3B30',
            row['created_at_utc'] ?? DateTime.now().toUtc().toIso8601String(),
          ]);
          importedCount++;
        }
      }

      _db.execute('COMMIT;');
      return importedCount;
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }
}
