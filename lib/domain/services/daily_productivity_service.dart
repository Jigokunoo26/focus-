import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../models/habit_item.dart';
import '../models/task_item.dart';

enum ProductivityTier {
  optimal,
  strong,
  onTrack,
  starting,
}

class DailyProductivityScore {
  final int totalScore; // 0 - 100
  final ProductivityTier tier;
  final String tierLabel;
  final Color color;
  final int tasksCompleted;
  final int tasksTotal;
  final int habitsCompleted;
  final int habitsTotal;
  final int focusMinutes;
  final String actionableSummary;

  const DailyProductivityScore({
    required this.totalScore,
    required this.tier,
    required this.tierLabel,
    required this.color,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.habitsCompleted,
    required this.habitsTotal,
    required this.focusMinutes,
    required this.actionableSummary,
  });
}

class DailyProductivityService {
  const DailyProductivityService();

  /// Calculates a deterministic, non-AI productivity score (0 - 100)
  /// using transparent weighted formulas:
  /// - Tasks Completed: up to 45 points
  /// - Habits Maintained: up to 35 points
  /// - Focus Engagement: up to 20 points
  DailyProductivityScore calculate({
    required List<TaskItem> tasks,
    required List<HabitItem> habits,
    int focusMinutes = 25,
  }) {
    // 1. Task Score (up to 45 pts)
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final double taskRatio = totalTasks > 0 ? (completedTasks / totalTasks) : 1.0;
    final int taskPoints = (taskRatio * 45).round();

    // 2. Habit Score (up to 35 pts)
    final totalHabits = habits.length;
    final completedHabits = habits.where((h) => h.isCompletedToday).length;
    final double habitRatio = totalHabits > 0 ? (completedHabits / totalHabits) : 1.0;
    final int habitPoints = (habitRatio * 35).round();

    // 3. Focus Score (up to 20 pts, baseline goal = 50 min)
    final double focusRatio = (focusMinutes / 50.0).clamp(0.0, 1.0);
    final int focusPoints = (focusRatio * 20).round();

    final int totalScore = (taskPoints + habitPoints + focusPoints).clamp(0, 100);

    // Productivity Tier
    final ProductivityTier tier;
    final String tierLabel;
    final Color color;
    final String actionableSummary;

    if (totalScore >= 85) {
      tier = ProductivityTier.optimal;
      tierLabel = 'OPTIMAL';
      color = AppColors.accent;
      actionableSummary = 'Peak efficiency reached today. All key outcomes and habits on track.';
    } else if (totalScore >= 70) {
      tier = ProductivityTier.strong;
      tierLabel = 'STRONG';
      color = AppColors.info;
      actionableSummary = 'Steady momentum. Complete remaining pending items to reach peak.';
    } else if (totalScore >= 45) {
      tier = ProductivityTier.onTrack;
      tierLabel = 'ON TRACK';
      color = AppColors.warning;
      actionableSummary = 'Good progress. Check off habits and priority tasks to boost output.';
    } else {
      tier = ProductivityTier.starting;
      tierLabel = 'STARTING';
      color = AppColors.textTertiaryDark;
      actionableSummary = 'Day underway. Execute your highest priority task to build momentum.';
    }

    return DailyProductivityScore(
      totalScore: totalScore,
      tier: tier,
      tierLabel: tierLabel,
      color: color,
      tasksCompleted: completedTasks,
      tasksTotal: totalTasks,
      habitsCompleted: completedHabits,
      habitsTotal: totalHabits,
      focusMinutes: focusMinutes,
      actionableSummary: actionableSummary,
    );
  }
}
