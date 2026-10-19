import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/widget_shell.dart';
import '../../../../data/providers/database_provider.dart';
import '../../../../domain/models/task_item.dart';

class DailyOverviewWidget extends ConsumerWidget {
  final VoidCallback? onTap;

  const DailyOverviewWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskListProvider);
    final score = ref.watch(dailyProductivityScoreProvider);

    return WidgetShell(
      title: 'Daily Productivity',
      icon: LucideIcons.target,
      statusTag: score.tierLabel,
      onTap: onTap,
      child: tasksAsync.when(
        data: (tasks) {
          final completed = score.tasksCompleted;
          final total = score.tasksTotal;
          final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress).length;
          final urgent = tasks.where((t) => t.priority == TaskPriority.high && !t.isCompleted).length;
          final progress = score.totalScore / 100.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Progress Ring showing overall productivity score
              ProgressRing(
                progress: progress,
                size: 74,
                strokeWidth: 6.5,
                color: score.color,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.totalScore}%',
                      style: AppTypography.metricSmall(isDark: isDark).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? AppColors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space16),

              // Metrics Breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed of $total tasks done',
                      style: AppTypography.titleMedium(isDark: isDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      score.actionableSummary,
                      style: AppTypography.bodySmall(isDark: isDark).copyWith(
                        fontSize: 11.5,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Wrap(
                      spacing: AppTokens.space6,
                      runSpacing: AppTokens.space4,
                      children: [
                        _metricBadge(
                          label: '$inProgress Active',
                          color: AppColors.info,
                          isDark: isDark,
                        ),
                        _metricBadge(
                          label: '${score.habitsCompleted}/${score.habitsTotal} Habits',
                          color: AppColors.accent,
                          isDark: isDark,
                        ),
                        if (urgent > 0)
                          _metricBadge(
                            label: '$urgent Urgent',
                            color: AppColors.urgent,
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => Text(
          'Error loading summary',
          style: AppTypography.bodySmall(isDark: isDark),
        ),
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
