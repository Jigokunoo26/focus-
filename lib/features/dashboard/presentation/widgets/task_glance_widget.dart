import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/widget_shell.dart';
import '../../../../data/providers/database_provider.dart';
import '../../../../domain/models/task_item.dart';

class TaskGlanceWidget extends ConsumerWidget {
  final VoidCallback onViewAll;
  final VoidCallback onAddTask;

  const TaskGlanceWidget({
    super.key,
    required this.onViewAll,
    required this.onAddTask,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskListProvider);

    return WidgetShell(
      title: 'Priority Tasks',
      icon: LucideIcons.checkCircle2,
      statusTag: 'TODAY',
      trailing: GestureDetector(
        onTap: onViewAll,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VIEW ALL',
              style: AppTypography.label(isDark: isDark).copyWith(
                color: isDark ? AppColors.white : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: isDark ? AppColors.white : AppColors.textPrimaryLight,
            ),
          ],
        ),
      ),
      child: tasksAsync.when(
        data: (tasks) {
          final pendingTasks = tasks.where((t) => !t.isCompleted).take(4).toList();

          if (pendingTasks.isEmpty) {
            return EmptyState(
              icon: LucideIcons.checkCheck,
              title: 'All caught up',
              subtitle: 'No pending priority tasks for today.',
              actionLabel: 'Add Task',
              onAction: onAddTask,
            );
          }

          return Column(
            children: pendingTasks.map((task) {
              return _TaskGlanceRow(
                task: task,
                isDark: isDark,
                onToggle: () => ref.read(taskListProvider.notifier).toggleComplete(task.id),
              );
            }).toList(),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppTokens.space16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (err, _) => Text(
          'Error loading tasks',
          style: AppTypography.bodySmall(isDark: isDark),
        ),
      ),
    );
  }
}

class _TaskGlanceRow extends StatelessWidget {
  final TaskItem task;
  final bool isDark;
  final VoidCallback onToggle;

  const _TaskGlanceRow({
    required this.task,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.high:
        priorityColor = AppColors.urgent;
        break;
      case TaskPriority.medium:
        priorityColor = AppColors.warning;
        break;
      case TaskPriority.low:
      case TaskPriority.none:
        priorityColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space6),
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppTokens.borderSmall,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space4,
            vertical: AppTokens.space6,
          ),
          child: Row(
            children: [
              // Checkbox indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
                    width: 1.5,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(LucideIcons.check, size: 12, color: AppColors.accent)
                    : null,
              ),
              const SizedBox(width: AppTokens.space12),

              // Title & Description
              Expanded(
                child: Text(
                  task.title,
                  style: AppTypography.body(isDark: isDark).copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted
                        ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Priority Dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: priorityColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
