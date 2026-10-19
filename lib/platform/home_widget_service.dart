import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../domain/models/task_item.dart';
import '../domain/models/habit_item.dart';
import '../domain/services/daily_productivity_service.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.com.focus.personalOs';

  static const String overviewAndroidWidgetName = 'FocusOverviewWidgetProvider';
  static const String overviewIOSWidgetName = 'FocusOverviewWidget';

  static const String quickActionsAndroidWidgetName = 'FocusQuickActionsWidgetProvider';
  static const String quickActionsIOSWidgetName = 'FocusQuickActionsWidget';

  static const String tasksAndroidWidgetName = 'FocusTasksWidgetProvider';
  static const String tasksIOSWidgetName = 'FocusTasksWidget';

  static const String habitsAndroidWidgetName = 'FocusHabitsWidgetProvider';
  static const String habitsIOSWidgetName = 'FocusHabitsWidget';

  static const String timerAndroidWidgetName = 'FocusTimerWidgetProvider';
  static const String timerIOSWidgetName = 'FocusTimerWidget';

  /// Initializes home widget plugin and configures iOS App Group
  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('HomeWidget initialization error: $e');
    }
  }

  /// Syncs daily productivity score, top tasks, habits, and focus metrics with all home screen widgets
  static Future<void> syncAllWidgetsData({
    required DailyProductivityScore score,
    required List<TaskItem> tasks,
    required List<HabitItem> habits,
    String timerStatus = 'STANDBY',
    String timerDisplay = '25:00',
    String timerSubtitle = 'Target: Deep Focus Session',
  }) async {
    if (kIsWeb) return;
    try {
      final nowTime = DateFormat('HH:mm').format(DateTime.now());
      final timeStamp = 'Updated $nowTime • Offline';

      // 1. Overview data
      await HomeWidget.saveWidgetData<String>('score_pct', '${score.totalScore}%');
      await HomeWidget.saveWidgetData<String>('score_title', score.tierLabel);
      await HomeWidget.saveWidgetData<String>(
        'tasks_summary',
        '${score.tasksCompleted} of ${score.tasksTotal} tasks done',
      );
      await HomeWidget.saveWidgetData<String>(
        'habits_summary',
        '${score.habitsCompleted} of ${score.habitsTotal} habits completed',
      );
      await HomeWidget.saveWidgetData<String>('time_text', timeStamp);

      // 2. Tasks Widget data
      final pendingTasks = tasks.where((t) => t.status != TaskStatus.completed).toList();
      await HomeWidget.saveWidgetData<String>(
        'tasks_count_badge',
        '${pendingTasks.length} PENDING',
      );

      // Task 1
      if (pendingTasks.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('task_1_title', pendingTasks[0].title);
        await HomeWidget.saveWidgetData<String>(
          'task_1_priority',
          _formatPriority(pendingTasks[0].priority),
        );
      } else {
        await HomeWidget.saveWidgetData<String>('task_1_title', 'All tasks completed!');
        await HomeWidget.saveWidgetData<String>('task_1_priority', 'DONE');
      }

      // Task 2
      if (pendingTasks.length > 1) {
        await HomeWidget.saveWidgetData<String>('task_2_title', pendingTasks[1].title);
        await HomeWidget.saveWidgetData<String>(
          'task_2_priority',
          _formatPriority(pendingTasks[1].priority),
        );
      } else {
        await HomeWidget.saveWidgetData<String>('task_2_title', 'No additional tasks');
        await HomeWidget.saveWidgetData<String>('task_2_priority', '');
      }

      // Task 3
      if (pendingTasks.length > 2) {
        await HomeWidget.saveWidgetData<String>('task_3_title', pendingTasks[2].title);
        await HomeWidget.saveWidgetData<String>(
          'task_3_priority',
          _formatPriority(pendingTasks[2].priority),
        );
      } else {
        await HomeWidget.saveWidgetData<String>('task_3_title', '');
        await HomeWidget.saveWidgetData<String>('task_3_priority', '');
      }

      // 3. Habits Widget data
      final totalHabits = habits.length;
      final completedHabits = habits.where((h) => h.isCompletedToday).length;
      final maxStreak = habits.fold<int>(0, (max, h) => h.currentStreak > max ? h.currentStreak : max);

      await HomeWidget.saveWidgetData<String>(
        'habits_streak_badge',
        '${maxStreak}D STREAK',
      );
      await HomeWidget.saveWidgetData<String>(
        'habits_count_label',
        '$completedHabits / $totalHabits COMPLETED',
      );

      if (habits.isNotEmpty) {
        final h1 = habits[0];
        await HomeWidget.saveWidgetData<String>(
          'habit_1_text',
          '${h1.isCompletedToday ? "✓" : "○"} ${h1.name}',
        );
      } else {
        await HomeWidget.saveWidgetData<String>('habit_1_text', 'No active habits set');
      }

      if (habits.length > 1) {
        final h2 = habits[1];
        await HomeWidget.saveWidgetData<String>(
          'habit_2_text',
          '${h2.isCompletedToday ? "✓" : "○"} ${h2.name}',
        );
      } else {
        await HomeWidget.saveWidgetData<String>('habit_2_text', '');
      }

      // 4. Timer Widget data
      await HomeWidget.saveWidgetData<String>('timer_status', timerStatus);
      await HomeWidget.saveWidgetData<String>('timer_display', timerDisplay);
      await HomeWidget.saveWidgetData<String>('timer_subtitle', timerSubtitle);

      // Trigger re-render of all outside-of-app widgets
      await Future.wait([
        HomeWidget.updateWidget(
          androidName: overviewAndroidWidgetName,
          iOSName: overviewIOSWidgetName,
        ),
        HomeWidget.updateWidget(
          androidName: quickActionsAndroidWidgetName,
          iOSName: quickActionsIOSWidgetName,
        ),
        HomeWidget.updateWidget(
          androidName: tasksAndroidWidgetName,
          iOSName: tasksIOSWidgetName,
        ),
        HomeWidget.updateWidget(
          androidName: habitsAndroidWidgetName,
          iOSName: habitsIOSWidgetName,
        ),
        HomeWidget.updateWidget(
          androidName: timerAndroidWidgetName,
          iOSName: timerIOSWidgetName,
        ),
      ]);
    } catch (e) {
      debugPrint('HomeWidget sync error: $e');
    }
  }

  static String _formatPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'CRIT';
      case TaskPriority.medium:
        return 'MED';
      case TaskPriority.low:
        return 'LOW';
      case TaskPriority.none:
        return 'NORM';
    }
  }

  /// Backward compatible helper
  static Future<void> syncProductivityData(DailyProductivityScore score) async {
    // Falls back to empty lists for minimal sync
    await syncAllWidgetsData(score: score, tasks: const [], habits: const []);
  }

  /// Registers deep link callback listener from home screen widget clicks
  static StreamSubscription<Uri?> listenToWidgetClicks(void Function(Uri uri) onUri) {
    return HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        onUri(uri);
      }
    });
  }

  /// Checks if application was initially launched by tapping a home screen widget
  static Future<Uri?> getInitiallyLaunchedUri() async {
    if (kIsWeb) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }
}
