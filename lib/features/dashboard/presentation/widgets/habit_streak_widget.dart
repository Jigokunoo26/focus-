import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widget_shell.dart';
import '../../../../data/providers/database_provider.dart';

class HabitStreakWidget extends ConsumerWidget {
  final VoidCallback onManageHabits;

  const HabitStreakWidget({super.key, required this.onManageHabits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsAsync = ref.watch(habitListProvider);

    return WidgetShell(
      title: 'Daily Habits',
      icon: LucideIcons.flame,
      statusTag: 'STREAKS',
      trailing: GestureDetector(
        onTap: onManageHabits,
        child: Icon(
          LucideIcons.arrowUpRight,
          size: 16,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
      child: habitsAsync.when(
        data: (habits) {
          if (habits.isEmpty) {
            return Text(
              'No habits tracked yet',
              style: AppTypography.bodySmall(isDark: isDark),
            );
          }

          return Column(
            children: habits.take(3).map((habit) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.space4),
                child: Row(
                  children: [
                    // Check toggle
                    GestureDetector(
                      onTap: () => ref.read(habitListProvider.notifier).toggleToday(habit.id),
                      child: AnimatedContainer(
                        duration: AppTokens.durationFast,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: habit.isCompletedToday
                              ? AppColors.accent
                              : (isDark ? AppColors.darkGlassBackground : AppColors.lightGlassBackground),
                          border: Border.all(
                            color: habit.isCompletedToday
                                ? AppColors.accent
                                : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                            width: 1.2,
                          ),
                        ),
                        child: habit.isCompletedToday
                            ? const Icon(LucideIcons.check, size: 13, color: AppColors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),

                    // Habit Name
                    Expanded(
                      child: Text(
                        habit.name,
                        style: AppTypography.body(isDark: isDark).copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: habit.isCompletedToday ? TextDecoration.lineThrough : null,
                          color: habit.isCompletedToday
                              ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Streak Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.flame, size: 11, color: AppColors.accent),
                          const SizedBox(width: 3),
                          Text(
                            '${habit.currentStreak}d',
                            style: AppTypography.label(isDark: isDark).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
        loading: () => const SizedBox(height: 40),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}
