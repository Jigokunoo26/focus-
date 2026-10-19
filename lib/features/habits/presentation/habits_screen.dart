import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';
import '../../../data/providers/database_provider.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final TextEditingController _newHabitController = TextEditingController();

  void _showAddHabitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEW ROUTINE / HABIT', style: AppTypography.label(isDark: isDark)),
                const SizedBox(height: AppTokens.space12),
                TextField(
                  controller: _newHabitController,
                  autofocus: true,
                  style: AppTypography.titleMedium(isDark: isDark),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Read 20 pages or Study block',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: AppTokens.space20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MinimalButton(
                      label: 'Cancel',
                      variant: MinimalButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    MinimalButton(
                      label: 'Save Habit',
                      variant: MinimalButtonVariant.accent,
                      onPressed: () {
                        final name = _newHabitController.text.trim();
                        if (name.isNotEmpty) {
                          ref.read(habitListProvider.notifier).addHabit(name: name);
                          _newHabitController.clear();
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitsAsync = ref.watch(habitListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Habits & Streaks', style: AppTypography.titleLarge(isDark: isDark)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        onPressed: _showAddHabitDialog,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: habitsAsync.when(
              data: (habits) {
                if (habits.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.flame,
                    title: 'No habits yet',
                    subtitle: 'Start building daily streaks and routines.',
                    actionLabel: 'Create Habit',
                    onAction: _showAddHabitDialog,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space16,
                  ),
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space12),
            itemBuilder: (context, index) {
              final habit = habits[index];
              return GlassCard(
                padding: const EdgeInsets.all(AppTokens.space16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => ref.read(habitListProvider.notifier).toggleToday(habit.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: habit.isCompletedToday
                              ? AppColors.accent
                              : (isDark ? AppColors.darkGlassBackground : AppColors.lightGlassBackground),
                          border: Border.all(
                            color: habit.isCompletedToday
                                ? AppColors.accent
                                : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                            width: 1.5,
                          ),
                        ),
                        child: habit.isCompletedToday
                            ? const Icon(LucideIcons.check, size: 16, color: AppColors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            style: AppTypography.titleMedium(isDark: isDark).copyWith(
                              decoration: habit.isCompletedToday ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Best streak: ${habit.bestStreak} days • ${habit.scheduleRule.toUpperCase()}',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.flame, size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            '${habit.currentStreak}d',
                            style: AppTypography.metricSmall(isDark: isDark).copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    ),
  ),
),
);
  }
}
