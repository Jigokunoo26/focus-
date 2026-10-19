import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/audit_event_item.dart';
import '../../domain/models/event_item.dart';
import '../../domain/models/habit_item.dart';
import '../../domain/models/note_item.dart';
import '../../domain/models/project_item.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/models/task_item.dart';
import '../../domain/services/daily_productivity_service.dart';
import '../../domain/services/reminder_reconciliation_service.dart';
import '../../platform/home_widget_service.dart';
import '../../platform/local_notification_scheduler.dart';
import '../../platform/notification_scheduler.dart';
import '../database/app_database.dart';
import '../repositories/local_audit_repository.dart';
import '../repositories/local_event_repository.dart';
import '../repositories/local_habit_repository.dart';
import '../repositories/local_note_repository.dart';
import '../repositories/local_project_repository.dart';
import '../repositories/local_reminder_repository.dart';
import '../repositories/local_task_repository.dart';
import '../repositories/local_critical_alert_repository.dart';
import '../repositories/local_focus_guard_repository.dart';
import '../../domain/models/critical_alert_models.dart';
import '../../domain/models/focus_guard_models.dart';
import '../../domain/services/alert_policy_engine.dart';
import '../../domain/services/focus_session_coordinator.dart';
import '../../platform/platform_alert_adapter.dart';

// Database Instance Provider
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  return await AppDatabase.getInstance();
});

// Repositories
final taskRepositoryProvider = FutureProvider<LocalTaskRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalTaskRepository(db);
});

final reminderRepositoryProvider = FutureProvider<LocalReminderRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalReminderRepository(db);
});

final habitRepositoryProvider = FutureProvider<LocalHabitRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalHabitRepository(db);
});

final projectRepositoryProvider = FutureProvider<LocalProjectRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalProjectRepository(db);
});

final noteRepositoryProvider = FutureProvider<LocalNoteRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalNoteRepository(db);
});

final eventRepositoryProvider = FutureProvider<LocalEventRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalEventRepository(db);
});

// Audit Repository & Log Provider
final auditRepositoryProvider = FutureProvider<LocalAuditRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalAuditRepository(db);
});

final auditLogProvider = FutureProvider<List<AuditEventItem>>((ref) async {
  final repo = await ref.watch(auditRepositoryProvider.future);
  return repo.getRecentAuditEvents();
});

// Notification Scheduler Provider with Stage 3 Interactive Actions
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  final scheduler = LocalNotificationScheduler();
  scheduler.initialize();
  scheduler.setActionCallback((actionId, reminderId) async {
    try {
      final reminderRepo = await ref.read(reminderRepositoryProvider.future);
      final auditRepo = await ref.read(auditRepositoryProvider.future);
      final taskRepo = await ref.read(taskRepositoryProvider.future);
      final reminder = await reminderRepo.getReminderById(reminderId);

      if (actionId == 'action_complete') {
        if (reminder != null) {
          await reminderRepo.updateReminderState(reminderId, ReminderState.delivered);
          if (reminder.ownerType == 'task' && reminder.ownerId != null) {
            await taskRepo.updateTaskStatus(reminder.ownerId!, TaskStatus.completed);
            ref.invalidate(taskListProvider);
          }
          await auditRepo.logEvent(
            id: const Uuid().v4(),
            eventType: 'COMPLETED',
            ownerId: reminder.ownerId,
            title: 'Completed via Notification Action',
            details: 'Task "${reminder.title}" completed directly from lock screen/notification.',
            createdAt: DateTime.now(),
          );
          ref.invalidate(auditLogProvider);
        }
      } else if (actionId == 'action_snooze_15') {
        if (reminder != null) {
          final newTrigger = DateTime.now().add(const Duration(minutes: 15));
          final snoozed = reminder.copyWith(
            triggerAt: newTrigger,
            state: ReminderState.scheduled,
          );
          await reminderRepo.saveReminder(snoozed);
          await scheduler.schedule(snoozed);
          await auditRepo.logEvent(
            id: const Uuid().v4(),
            eventType: 'SNOOZED',
            ownerId: reminder.ownerId,
            title: 'Snoozed 15 Minutes',
            details: 'Alarm postponed to ${newTrigger.toLocal().toString().substring(11, 16)}',
            createdAt: DateTime.now(),
          );
          ref.invalidate(reminderRepositoryProvider);
          ref.invalidate(auditLogProvider);
        }
      }
    } catch (e) {
      debugPrint('Notification action error: $e');
    }
  });
  return scheduler;
});

// Reminder Reconciliation Service Provider
final reconciliationServiceProvider = FutureProvider<ReminderReconciliationService>((ref) async {
  final reminderRepo = await ref.watch(reminderRepositoryProvider.future);
  final scheduler = ref.watch(notificationSchedulerProvider);
  final auditRepo = await ref.watch(auditRepositoryProvider.future);
  return ReminderReconciliationService(reminderRepo, scheduler, auditRepo: auditRepo);
});

// Task List AsyncNotifier with Reminder Engine Integration
class TaskListNotifier extends AsyncNotifier<List<TaskItem>> {
  @override
  Future<List<TaskItem>> build() async {
    final repo = await ref.watch(taskRepositoryProvider.future);
    return repo.getTasks();
  }

  Future<void> addTask({
    required String title,
    String description = '',
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
    String? projectId,
    bool isCritical = false,
    DuePolicy duePolicy = DuePolicy.strict,
    int leadMinutes = 15,
    QuietHoursPolicy quietHoursPolicy = QuietHoursPolicy.silent,
    bool genericLockscreen = false,
  }) async {
    final taskRepo = await ref.read(taskRepositoryProvider.future);
    final reminderRepo = await ref.read(reminderRepositoryProvider.future);
    final scheduler = ref.read(notificationSchedulerProvider);

    final now = DateTime.now();
    final taskId = const Uuid().v4();
    final newTask = TaskItem(
      id: taskId,
      title: title.trim(),
      description: description.trim(),
      priority: isCritical ? TaskPriority.high : priority,
      dueAt: dueAt,
      projectId: projectId,
      createdAt: now,
      updatedAt: now,
    );

    if (isCritical && dueAt != null) {
      // Phase 5 Critical Alert Transaction
      final criticalRepo = await ref.read(criticalAlertRepositoryProvider.future);
      final alertEngine = await ref.read(alertPolicyEngineProvider.future);
      final auditRepo = await ref.read(auditRepositoryProvider.future);

      final schedule = TaskSchedule(
        taskId: taskId,
        localDateTime: dueAt.toIso8601String(),
        zoneId: DateTime.now().timeZoneName,
        duePolicy: duePolicy,
        graceMinutes: 10,
      );

      final rule = AlertRule(
        id: 'rule-$taskId',
        taskId: taskId,
        leadMinutes: leadMinutes,
        channel: 'alarm',
        escalationSteps: const [10, 20, 30],
        quietHoursPolicy: quietHoursPolicy,
        enabled: true,
      );

      final fireAtUtc = dueAt.subtract(Duration(minutes: leadMinutes)).toUtc();
      final occurrence = TaskOccurrence(
        id: 'occ-$taskId-0',
        taskId: taskId,
        plannedAtUtc: fireAtUtc,
        localDate: '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}',
        zoneId: DateTime.now().timeZoneName,
        revision: 1,
        state: AlertState.scheduled,
      );

      final outboxItem = OutboxItem(
        id: 'outbox-$taskId-0',
        command: 'SCHEDULE',
        occurrenceId: occurrence.id,
        revision: 1,
        fireAtUtc: fireAtUtc,
        payloadJson: jsonEncode({
          'taskId': taskId,
          'title': genericLockscreen ? 'Critical Task Reminder' : title.trim(),
          'duePolicy': duePolicy.name,
          'genericPrivacy': genericLockscreen,
        }),
        createdAtUtc: now.toUtc(),
      );

      await criticalRepo.saveCriticalTaskTransaction(
        task: newTask,
        schedule: schedule,
        rule: rule,
        occurrence: occurrence,
        outboxItem: outboxItem,
      );

      // Trigger engine outbox replay
      await alertEngine.processOutbox();

      await auditRepo.logEvent(
        id: const Uuid().v4(),
        eventType: 'CRITICAL_TASK_SCHEDULED',
        ownerId: taskId,
        title: 'Critical Alert Scheduled',
        details: 'Atomic schedule with ${leadMinutes}m lead time and ${duePolicy.name} policy.',
        createdAt: now,
      );
    } else {
      // 1. Durably commit standard task
      await taskRepo.saveTask(newTask);

      // 2. If due date specified, schedule reminder according to Section 7 pipeline
      if (dueAt != null && dueAt.isAfter(now)) {
        final reminder = ReminderItem(
          id: 'rem-$taskId',
          ownerType: 'task',
          ownerId: taskId,
          title: title.trim(),
          notes: description.isNotEmpty ? description : 'FOCUS OS Task Due',
          triggerAt: dueAt,
          state: ReminderState.scheduled,
          notificationId: LocalNotificationScheduler.deriveNotificationId('rem-$taskId'),
          createdAt: now,
        );

        // Durably commit reminder before OS schedule
        await reminderRepo.saveReminder(reminder);
        // Schedule native notification
        await scheduler.schedule(reminder);
      }
    }

    ref.invalidateSelf();
  }

  Future<void> toggleComplete(String taskId) async {
    final currentTasks = state.value ?? [];
    final target = currentTasks.firstWhere((t) => t.id == taskId);
    final newStatus = target.isCompleted ? TaskStatus.todo : TaskStatus.completed;

    final taskRepo = await ref.read(taskRepositoryProvider.future);
    final reminderRepo = await ref.read(reminderRepositoryProvider.future);
    final scheduler = ref.read(notificationSchedulerProvider);

    await taskRepo.updateTaskStatus(taskId, newStatus);

    if (newStatus == TaskStatus.completed) {
      await scheduler.cancel('rem-$taskId');
      await reminderRepo.updateReminderState('rem-$taskId', ReminderState.delivered);

      // Phase 5: Acknowledge active occurrences if any
      try {
        final criticalRepo = await ref.read(criticalAlertRepositoryProvider.future);
        final alertEngine = await ref.read(alertPolicyEngineProvider.future);
        final occurrences = await criticalRepo.getOccurrencesForTask(taskId);
        for (final occ in occurrences) {
          if (!occ.state.isTerminal) {
            await alertEngine.handleAcknowledge(occ.id);
          }
        }
      } catch (e) {
        debugPrint('Error acknowledging critical occurrences: $e');
      }
    }

    ref.invalidateSelf();
  }

  Future<void> toggleTaskCompletion(String taskId) => toggleComplete(taskId);

  Future<void> createSubtask({
    required String parentTaskId,
    required String title,
  }) async {
    final taskRepo = await ref.read(taskRepositoryProvider.future);
    final now = DateTime.now();
    final subtask = TaskItem(
      id: const Uuid().v4(),
      title: title.trim(),
      parentTaskId: parentTaskId,
      priority: TaskPriority.low,
      createdAt: now,
      updatedAt: now,
    );
    await taskRepo.saveTask(subtask);
    ref.invalidateSelf();
  }

  Future<void> deleteTask(String taskId) async {
    final taskRepo = await ref.read(taskRepositoryProvider.future);
    final reminderRepo = await ref.read(reminderRepositoryProvider.future);
    final scheduler = ref.read(notificationSchedulerProvider);

    await scheduler.cancel('rem-$taskId');
    await reminderRepo.deleteReminder('rem-$taskId');

    // Phase 5: Cancel occurrences
    try {
      final criticalRepo = await ref.read(criticalAlertRepositoryProvider.future);
      final alertEngine = await ref.read(alertPolicyEngineProvider.future);
      final occurrences = await criticalRepo.getOccurrencesForTask(taskId);
      for (final occ in occurrences) {
        if (!occ.state.isTerminal) {
          await alertEngine.transitionOccurrence(occ.id, AlertState.cancelled);
        }
      }
    } catch (e) {
      debugPrint('Error cancelling critical occurrences: $e');
    }

    // Also delete any subtasks attached to this task
    final allTasks = state.value ?? [];
    for (final sub in allTasks.where((t) => t.parentTaskId == taskId)) {
      await taskRepo.deleteTask(sub.id);
    }

    await taskRepo.deleteTask(taskId);

    ref.invalidateSelf();
  }
}

final taskListProvider = AsyncNotifierProvider<TaskListNotifier, List<TaskItem>>(
  TaskListNotifier.new,
);

// Habit List AsyncNotifier
class HabitListNotifier extends AsyncNotifier<List<HabitItem>> {
  @override
  Future<List<HabitItem>> build() async {
    final repo = await ref.watch(habitRepositoryProvider.future);
    return repo.getHabits();
  }

  Future<void> toggleToday(String habitId) async {
    final repo = await ref.read(habitRepositoryProvider.future);
    await repo.toggleHabitToday(habitId);
    ref.invalidateSelf();
  }

  Future<void> addHabit({required String name, String rule = 'daily'}) async {
    final repo = await ref.read(habitRepositoryProvider.future);
    final newHabit = HabitItem(
      id: const Uuid().v4(),
      name: name.trim(),
      scheduleRule: rule,
      createdAt: DateTime.now(),
    );
    await repo.saveHabit(newHabit);
    ref.invalidateSelf();
  }
}

final habitListProvider = AsyncNotifierProvider<HabitListNotifier, List<HabitItem>>(
  HabitListNotifier.new,
);

// Projects AsyncNotifier
class ProjectListNotifier extends AsyncNotifier<List<ProjectItem>> {
  @override
  Future<List<ProjectItem>> build() async {
    final repo = await ref.watch(projectRepositoryProvider.future);
    return repo.getProjects();
  }

  Future<void> addProject({
    required String name,
    String description = '',
    String colorHex = '#FF3B30',
    DateTime? deadline,
  }) async {
    final repo = await ref.read(projectRepositoryProvider.future);
    final newProject = ProjectItem(
      id: const Uuid().v4(),
      name: name.trim(),
      description: description.trim(),
      colorHex: colorHex,
      deadline: deadline,
      createdAt: DateTime.now(),
    );
    await repo.saveProject(newProject);
    ref.invalidateSelf();
  }

  Future<void> deleteProject(String id) async {
    final repo = await ref.read(projectRepositoryProvider.future);
    await repo.deleteProject(id);
    ref.invalidateSelf();
  }
}

final projectListProvider = AsyncNotifierProvider<ProjectListNotifier, List<ProjectItem>>(
  ProjectListNotifier.new,
);

// Notes AsyncNotifier
class NoteListNotifier extends AsyncNotifier<List<NoteItem>> {
  @override
  Future<List<NoteItem>> build() async {
    final repo = await ref.watch(noteRepositoryProvider.future);
    return repo.getNotes();
  }

  Future<void> addNote({
    required String title,
    String content = '',
    String tags = '',
  }) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    final now = DateTime.now();
    final newNote = NoteItem(
      id: const Uuid().v4(),
      title: title.trim(),
      content: content.trim(),
      tags: tags.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await repo.saveNote(newNote);
    ref.invalidateSelf();
  }

  Future<void> deleteNote(String id) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.deleteNote(id);
    ref.invalidateSelf();
  }
}

final noteListProvider = AsyncNotifierProvider<NoteListNotifier, List<NoteItem>>(
  NoteListNotifier.new,
);

// Event List AsyncNotifier (Calendar & Agenda Timeline)
class EventListNotifier extends AsyncNotifier<List<EventItem>> {
  @override
  Future<List<EventItem>> build() async {
    final repo = await ref.watch(eventRepositoryProvider.future);
    return repo.getEvents();
  }

  Future<void> createEvent({
    required String title,
    String? description,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isAllDay = false,
    String? location,
    String colorHex = '#FF3B30',
  }) async {
    final repo = await ref.read(eventRepositoryProvider.future);
    final newEvent = EventItem(
      id: const Uuid().v4(),
      title: title.trim(),
      description: description?.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      isAllDay: isAllDay,
      location: location?.trim(),
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );
    await repo.saveEvent(newEvent);
    ref.invalidateSelf();
  }

  Future<void> deleteEvent(String id) async {
    final repo = await ref.read(eventRepositoryProvider.future);
    await repo.deleteEvent(id);
    ref.invalidateSelf();
  }
}

final eventListProvider = AsyncNotifierProvider<EventListNotifier, List<EventItem>>(
  EventListNotifier.new,
);

// Daily Productivity Score Provider
final dailyProductivityServiceProvider = Provider<DailyProductivityService>((ref) {
  return const DailyProductivityService();
});

final dailyProductivityScoreProvider = Provider<DailyProductivityScore>((ref) {
  final service = ref.watch(dailyProductivityServiceProvider);
  final tasks = ref.watch(taskListProvider).value ?? [];
  final habits = ref.watch(habitListProvider).value ?? [];
  final score = service.calculate(tasks: tasks, habits: habits);
  HomeWidgetService.syncAllWidgetsData(
    score: score,
    tasks: tasks,
    habits: habits,
  );
  return score;
});

// Theme Mode Notifier (Dark default as specified by Nothing OS design)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// Platform Alert Adapter
final platformAlertAdapterProvider = Provider<PlatformAlertAdapter>((ref) {
  return MethodChannelPlatformAlertAdapter();
});

// Phase 5: Critical Alert Repository & Policy Engine
final criticalAlertRepositoryProvider = FutureProvider<LocalCriticalAlertRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalCriticalAlertRepository(db);
});

final alertPolicyEngineProvider = FutureProvider<AlertPolicyEngine>((ref) async {
  final alertRepo = await ref.watch(criticalAlertRepositoryProvider.future);
  final auditRepo = await ref.watch(auditRepositoryProvider.future);
  final adapter = ref.watch(platformAlertAdapterProvider);
  return AlertPolicyEngine(alertRepo, auditRepo, adapter);
});

// Phase 7: Focus Guard Repository & Session Coordinator
final focusGuardRepositoryProvider = FutureProvider<LocalFocusGuardRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LocalFocusGuardRepository(db);
});

final focusSessionCoordinatorProvider = FutureProvider<FocusSessionCoordinator>((ref) async {
  final focusRepo = await ref.watch(focusGuardRepositoryProvider.future);
  final adapter = ref.watch(platformAlertAdapterProvider);
  return FocusSessionCoordinator(focusRepo, adapter);
});

final activeFocusPolicyProvider = FutureProvider<FocusPolicy>((ref) async {
  final repo = await ref.watch(focusGuardRepositoryProvider.future);
  return repo.getActivePolicy();
});

final activeFocusSessionProvider = FutureProvider<FocusSession?>((ref) async {
  final repo = await ref.watch(focusGuardRepositoryProvider.future);
  return repo.getActiveSession();
});

final focusEventsHistoryProvider = FutureProvider<List<FocusEvent>>((ref) async {
  final repo = await ref.watch(focusGuardRepositoryProvider.future);
  return repo.getRecentFocusEvents();
});
