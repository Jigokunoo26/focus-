import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/data/database/app_database.dart';
import 'package:focus_app/data/repositories/local_audit_repository.dart';
import 'package:focus_app/data/repositories/local_event_repository.dart';
import 'package:focus_app/data/repositories/local_habit_repository.dart';
import 'package:focus_app/data/repositories/local_note_repository.dart';
import 'package:focus_app/data/repositories/local_project_repository.dart';
import 'package:focus_app/data/repositories/local_reminder_repository.dart';
import 'package:focus_app/data/repositories/local_task_repository.dart';
import 'package:focus_app/domain/models/event_item.dart';
import 'package:focus_app/domain/models/habit_item.dart';
import 'package:focus_app/domain/models/note_item.dart';
import 'package:focus_app/domain/models/project_item.dart';
import 'package:focus_app/domain/models/reminder_item.dart';
import 'package:focus_app/domain/models/task_item.dart';
import 'package:flutter/material.dart';
import 'package:focus_app/core/widgets/responsive_scaffold.dart';
import 'package:focus_app/domain/services/daily_productivity_service.dart';
import 'package:focus_app/domain/services/reminder_reconciliation_service.dart';
import 'package:focus_app/platform/home_widget_service.dart';
import 'package:focus_app/platform/notification_scheduler.dart';

class FakeNotificationScheduler implements NotificationScheduler {
  final List<ReminderItem> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(ReminderItem reminder) async {
    scheduled.add(reminder);
  }

  @override
  Future<void> cancel(String reminderId) async {
    cancelled.add(reminderId);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
  }

  @override
  Future<NotificationHealthStatus> getStatus() async {
    return NotificationHealthStatus(
      notificationsAllowed: true,
      exactAlarmsAllowed: true,
      upcomingScheduledCount: scheduled.length,
      lastReconciledAt: DateTime.now(),
    );
  }

  @override
  Future<void> showInstantTestNotification({required String title, required String body}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FOCUS Local Operating System — Repository & Engine Tests', () {
    late AppDatabase db;
    late LocalTaskRepository taskRepo;
    late LocalReminderRepository reminderRepo;
    late LocalHabitRepository habitRepo;
    late LocalProjectRepository projectRepo;
    late LocalNoteRepository noteRepo;
    late LocalEventRepository eventRepo;
    late LocalAuditRepository auditRepo;

    setUp(() async {
      db = await AppDatabase.getInstance(inMemory: true);
      taskRepo = LocalTaskRepository(db);
      reminderRepo = LocalReminderRepository(db);
      habitRepo = LocalHabitRepository(db);
      projectRepo = LocalProjectRepository(db);
      noteRepo = LocalNoteRepository(db);
      eventRepo = LocalEventRepository(db);
      auditRepo = LocalAuditRepository(db);
    });

    tearDown(() {
      db.close();
    });

    test('SQLite initial schema and seeding completes successfully', () async {
      final tasks = await taskRepo.getTasks();
      expect(tasks, isNotEmpty);
      expect(tasks.any((t) => t.title.contains('Review Master Implementation Plan')), isTrue);

      final habits = await habitRepo.getHabits();
      expect(habits, isNotEmpty);

      final projects = await projectRepo.getProjects();
      expect(projects, isNotEmpty);
    });

    test('Task Lifecycle: create, update status, and delete in local SQLite', () async {
      final now = DateTime.now();
      final newTask = TaskItem(
        id: 'test-task-1',
        title: 'Verify Stage 1 Deliverables',
        description: 'Automated test item',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        createdAt: now,
        updatedAt: now,
      );

      await taskRepo.saveTask(newTask);

      final retrieved = await taskRepo.getTaskById('test-task-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Verify Stage 1 Deliverables'));
      expect(retrieved.status, equals(TaskStatus.todo));

      // Toggle status to completed
      await taskRepo.updateTaskStatus('test-task-1', TaskStatus.completed);
      final updated = await taskRepo.getTaskById('test-task-1');
      expect(updated!.status, equals(TaskStatus.completed));
      expect(updated.completedAt, isNotNull);

      // Delete task
      await taskRepo.deleteTask('test-task-1');
      final afterDelete = await taskRepo.getTaskById('test-task-1');
      expect(afterDelete, isNull);
    });

    test('Habit Tracking: toggle daily completion and streak records', () async {
      final habits = await habitRepo.getHabits();
      final target = habits.first;

      // Toggle today
      await habitRepo.toggleHabitToday(target.id);
      final allUpdated = await habitRepo.getHabits();
      final updated = allUpdated.firstWhere((h) => h.id == target.id);
      expect(updated.isCompletedToday, isTrue);

      // Untoggle
      await habitRepo.toggleHabitToday(target.id);
      final allUntoggled = await habitRepo.getHabits();
      final untoggled = allUntoggled.firstWhere((h) => h.id == target.id);
      expect(untoggled.isCompletedToday, isFalse);
    });

    test('Project Management: create project, verify linkable task container', () async {
      final now = DateTime.now();
      final project = ProjectItem(
        id: 'proj-omega',
        name: 'Project Omega',
        description: 'Offline-first core system',
        colorHex: '#FF3B30',
        deadline: now.add(const Duration(days: 30)),
        createdAt: now,
      );

      await projectRepo.saveProject(project);
      final retrieved = await projectRepo.getProjectById('proj-omega');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Project Omega'));

      await projectRepo.deleteProject('proj-omega');
      final afterDelete = await projectRepo.getProjectById('proj-omega');
      expect(afterDelete, isNull);
    });

    test('Notes & Knowledge: create note with tags and content', () async {
      final now = DateTime.now();
      final note = NoteItem(
        id: 'note-secret',
        title: 'Master Architecture Principles',
        content: '# Local-First\n- Zero cloud calls\n- 100% deterministic SQLite',
        tags: 'architecture, security',
        createdAt: now,
        updatedAt: now,
      );

      await noteRepo.saveNote(note);
      final retrieved = await noteRepo.getNoteById('note-secret');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Master Architecture Principles'));
      expect(retrieved.tags, contains('architecture'));

      await noteRepo.deleteNote('note-secret');
      final afterDelete = await noteRepo.getNoteById('note-secret');
      expect(afterDelete, isNull);
    });

    test('Vertical Slice: Reminders Engine & 14-Day Rolling Window Reconciliation', () async {
      final fakeScheduler = FakeNotificationScheduler();
      final reconService = ReminderReconciliationService(reminderRepo, fakeScheduler);

      final now = DateTime.now();

      // Reminder A: In 2 days (within 14-day rolling window)
      final nearReminder = ReminderItem(
        id: 'rem-near',
        title: 'System Health Check',
        triggerAt: now.add(const Duration(days: 2)),
        notificationId: 101,
        state: ReminderState.pending,
        createdAt: now,
      );

      // Reminder B: In 25 days (outside 14-day rolling window)
      final distantReminder = ReminderItem(
        id: 'rem-distant',
        title: 'Monthly Review',
        triggerAt: now.add(const Duration(days: 25)),
        notificationId: 102,
        state: ReminderState.pending,
        createdAt: now,
      );

      await reminderRepo.saveReminder(nearReminder);
      await reminderRepo.saveReminder(distantReminder);

      // Run idempotent reconciliation
      final scheduledCount = await reconService.reconcileAll();

      // Only nearReminder (plus any seeded reminders within 14 days) should be scheduled
      expect(scheduledCount, greaterThanOrEqualTo(1));
      expect(fakeScheduler.scheduled.any((r) => r.id == 'rem-near'), isTrue);
      expect(fakeScheduler.scheduled.any((r) => r.id == 'rem-distant'), isFalse);

      // Verify DB state updated to scheduled
      final allReminders = await reminderRepo.getReminders();
      final refreshedNear = allReminders.firstWhere((r) => r.id == 'rem-near');
      expect(refreshedNear.state, equals(ReminderState.scheduled));
    });

    test('Stage 2 — Calendar & Event Persistence: create, query by date, and delete', () async {
      final now = DateTime.now();
      final event = EventItem(
        id: 'event-sprint',
        title: 'Stage 2 Architecture Review',
        description: 'Verify subtasks, calendar agenda, and productivity scoring',
        startsAt: now.add(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 2)),
        isAllDay: false,
        location: 'Focus Chamber',
        colorHex: '#FF3B30',
        createdAt: now,
      );

      await eventRepo.saveEvent(event);

      final events = await eventRepo.getEvents();
      expect(events.any((e) => e.id == 'event-sprint'), isTrue);

      final todayEvents = await eventRepo.getEventsForDate(now);
      expect(todayEvents.any((e) => e.id == 'event-sprint'), isTrue);

      await eventRepo.deleteEvent('event-sprint');
      final afterDelete = await eventRepo.getEvents();
      expect(afterDelete.any((e) => e.id == 'event-sprint'), isFalse);
    });

    test('Stage 2 — Subtask Hierarchy: create parent task, link subtasks, and verify', () async {
      final now = DateTime.now();
      final parentTask = TaskItem(
        id: 'parent-task-1',
        title: 'Launch Stage 2 Core Productivity',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        createdAt: now,
        updatedAt: now,
      );
      final subtask1 = TaskItem(
        id: 'subtask-1-1',
        title: 'Build Calendar & Agenda Screen',
        parentTaskId: 'parent-task-1',
        status: TaskStatus.completed,
        priority: TaskPriority.medium,
        createdAt: now,
        updatedAt: now,
      );
      final subtask2 = TaskItem(
        id: 'subtask-1-2',
        title: 'Project Milestones & Deliverables',
        parentTaskId: 'parent-task-1',
        status: TaskStatus.todo,
        priority: TaskPriority.medium,
        createdAt: now,
        updatedAt: now,
      );

      await taskRepo.saveTask(parentTask);
      await taskRepo.saveTask(subtask1);
      await taskRepo.saveTask(subtask2);

      final allTasks = await taskRepo.getTasks();
      final children = allTasks.where((t) => t.parentTaskId == 'parent-task-1').toList();
      expect(children.length, equals(2));
      expect(children.where((t) => t.isCompleted).length, equals(1));

      // Cleanup
      await taskRepo.deleteTask('subtask-1-1');
      await taskRepo.deleteTask('subtask-1-2');
      await taskRepo.deleteTask('parent-task-1');
    });

    test('Stage 2 — Daily Productivity Scoring: deterministic calculations', () {
      const service = DailyProductivityService();
      final now = DateTime.now();

      final tasks = [
        TaskItem(id: 't1', title: 'Task 1', status: TaskStatus.completed, priority: TaskPriority.high, createdAt: now, updatedAt: now),
        TaskItem(id: 't2', title: 'Task 2', status: TaskStatus.completed, priority: TaskPriority.medium, createdAt: now, updatedAt: now),
        TaskItem(id: 't3', title: 'Task 3', status: TaskStatus.todo, priority: TaskPriority.low, createdAt: now, updatedAt: now),
      ];

      final habits = [
        HabitItem(id: 'h1', name: 'Habit 1', isCompletedToday: true, createdAt: now),
        HabitItem(id: 'h2', name: 'Habit 2', isCompletedToday: false, createdAt: now),
      ];

      final score = service.calculate(
        tasks: tasks,
        habits: habits,
        focusMinutes: 50,
      );

      // (2/3 * 45) = 30 pts + (1/2 * 35) = 18 pts + (50/50 * 20) = 20 pts = 68 pts
      expect(score.totalScore, equals(68));
      expect(score.tier, equals(ProductivityTier.onTrack));
      expect(score.tierLabel, equals('ON TRACK'));
      expect(score.tasksCompleted, equals(2));
      expect(score.tasksTotal, equals(3));
      expect(score.habitsCompleted, equals(1));
      expect(score.habitsTotal, equals(2));
    });

    test('Stage 3 — Local Audit Trail: durable logging and recent events query', () async {
      final now = DateTime.now();

      await auditRepo.logEvent(
        id: 'audit-1',
        eventType: 'SCHEDULED',
        title: 'Task Reminder Scheduled',
        details: 'Exact alarm queued for Sprint Planning',
        createdAt: now,
      );

      await auditRepo.logEvent(
        id: 'audit-2',
        eventType: 'COMPLETED',
        title: 'Task Checked Off',
        details: 'Completed directly from notification action',
        createdAt: now.add(const Duration(minutes: 5)),
      );

      final recent = await auditRepo.getRecentAuditEvents(limit: 10);
      expect(recent.length, greaterThanOrEqualTo(2));
      expect(recent.any((e) => e.eventType == 'SCHEDULED'), isTrue);
      expect(recent.any((e) => e.eventType == 'COMPLETED'), isTrue);
    });

    test('Stage 3 — Reconciliation Audit Integration: rolling window reconciliation logs RECONCILED', () async {
      final fakeScheduler = FakeNotificationScheduler();
      final reconService = ReminderReconciliationService(
        reminderRepo,
        fakeScheduler,
        auditRepo: auditRepo,
      );

      final now = DateTime.now();
      final reminder = ReminderItem(
        id: 'rem-audit-test',
        title: 'Audit Reconciliation Test',
        triggerAt: now.add(const Duration(days: 3)),
        notificationId: 991,
        state: ReminderState.pending,
        createdAt: now,
      );
      await reminderRepo.saveReminder(reminder);

      final count = await reconService.reconcileAll();
      expect(count, greaterThanOrEqualTo(1));

      final auditEvents = await auditRepo.getRecentAuditEvents();
      expect(auditEvents.any((e) => e.eventType == 'RECONCILED'), isTrue);
    });

    test('Stage 3 — Outside-of-App Home Screen Widgets: multi-widget data synchronization executes gracefully', () async {
      final score = const DailyProductivityScore(
        totalScore: 85,
        tier: ProductivityTier.optimal,
        tierLabel: 'OPTIMAL',
        color: Colors.green,
        tasksCompleted: 3,
        tasksTotal: 4,
        habitsCompleted: 2,
        habitsTotal: 2,
        focusMinutes: 25,
        actionableSummary: 'Outstanding focus block',
      );

      final now = DateTime.now();
      final tasks = [
        TaskItem(
          id: 't-w1',
          title: 'Widget Top Task',
          priority: TaskPriority.high,
          createdAt: now,
          updatedAt: now,
        ),
        TaskItem(
          id: 't-w2',
          title: 'Widget Second Task',
          priority: TaskPriority.medium,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final habits = [
        HabitItem(id: 'h-w1', name: 'Morning Routine', currentStreak: 5, isCompletedToday: true, createdAt: now),
        HabitItem(id: 'h-w2', name: 'Read Documentation', currentStreak: 3, isCompletedToday: false, createdAt: now),
      ];

      // Verification that HomeWidgetService.syncAllWidgetsData runs without unhandled exceptions
      await expectLater(
        HomeWidgetService.syncAllWidgetsData(
          score: score,
          tasks: tasks,
          habits: habits,
          timerStatus: 'STANDBY',
          timerDisplay: '25:00',
        ),
        completes,
      );
    });

    testWidgets('Responsive Alignment — Layout across compact phone (<360dp), standard phone, and tablet (>=600dp)', (tester) async {
      // 1. Compact screen test (320x568 - iPhone SE / compact Android)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Center(child: Text('Compact Phone')));
            },
          ),
        ),
      );

      expect(ResponsiveUtils.isCompact(capturedContext), isTrue);
      expect(ResponsiveUtils.isTablet(capturedContext), isFalse);
      expect(ResponsiveUtils.horizontalPadding(capturedContext), equals(12.0));

      // 2. Standard screen test (390x844 - iPhone 14/15/16)
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Center(child: Text('Standard Phone')));
            },
          ),
        ),
      );

      expect(ResponsiveUtils.isCompact(capturedContext), isFalse);
      expect(ResponsiveUtils.isTablet(capturedContext), isFalse);
      expect(ResponsiveUtils.horizontalPadding(capturedContext), equals(16.0));

      // 3. Tablet screen test (768x1024 - iPad / Foldable)
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: Center(child: Text('Tablet')));
            },
          ),
        ),
      );

      expect(ResponsiveUtils.isTablet(capturedContext), isTrue);
      expect(ResponsiveUtils.isCompact(capturedContext), isFalse);
      expect(ResponsiveUtils.horizontalPadding(capturedContext), equals(24.0));
    });
  });
}
