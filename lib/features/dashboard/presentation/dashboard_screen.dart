import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/providers/database_provider.dart';
import '../../screen_builder/presentation/screen_builder_screen.dart';
import '../../tasks/presentation/task_create_dialog.dart';
import '../../tasks/presentation/voice_capture_dialog.dart';
import 'widgets/agenda_glance_widget.dart';
import 'widgets/clock_date_widget.dart';
import 'widgets/countdown_widget.dart';
import 'widgets/daily_overview_widget.dart';
import 'widgets/device_status_widget.dart';
import 'widgets/focus_timer_widget.dart';
import 'widgets/habit_streak_widget.dart';
import 'widgets/quick_actions_widget.dart';
import 'widgets/task_glance_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showAddTask(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const TaskCreateDialog(),
    );
  }

  void _showVoiceCapture(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => VoiceCaptureDialog(
        onConfirmed: (text, type) {
          if (type == 'task') {
            ref.read(taskListProvider.notifier).addTask(title: text);
          } else if (type == 'note') {
            ref.read(noteListProvider.notifier).addNote(title: text);
          }
        },
      ),
    );
  }

  Widget? _buildWidgetById(String id, BuildContext context, WidgetRef ref) {
    switch (id) {
      case 'clock_date':
        return ClockDateWidget(onTap: () => context.push('/tasks'));
      case 'quick_actions':
        return QuickActionsWidget(
          onAddTask: () => _showAddTask(context),
          onStartFocus: () => context.push('/focus'),
          onLogHabit: () => context.push('/habits'),
          onVoiceCapture: () => _showVoiceCapture(context, ref),
        );
      case 'daily_overview':
        return DailyOverviewWidget(onTap: () => context.push('/tasks'));
      case 'task_glance':
        return TaskGlanceWidget(
          onViewAll: () => context.push('/tasks'),
          onAddTask: () => _showAddTask(context),
        );
      case 'focus_timer':
        return const FocusTimerWidget();
      case 'habit_streak':
        return HabitStreakWidget(onManageHabits: () => context.push('/habits'));
      case 'countdown':
        return CountdownWidget(targetDate: DateTime.now().add(const Duration(days: 14)));
      case 'agenda_glance':
        return AgendaGlanceWidget(onOpenCalendar: () => context.push('/calendar'));
      case 'device_status':
        return DeviceStatusWidget(onOpenHealth: () => context.push('/reminders'));
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final activeLayout = ref.watch(activeLayoutProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: AppTokens.space20,
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Text(
              'FOCUS',
              style: AppTypography.display(isDark: isDark).copyWith(
                fontSize: 20,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
                  width: 0.8,
                ),
              ),
              child: Text(
                'v1.0 OS',
                style: AppTypography.label(isDark: isDark).copyWith(fontSize: 9),
              ),
            ),
          ],
        ),
        actions: [
          // Focus Guard Command Center
          IconButton(
            icon: const Icon(LucideIcons.shieldAlert, size: 18, color: AppColors.urgent),
            tooltip: 'Focus Guard Command Center',
            onPressed: () => context.push('/focus-guard'),
          ),
          // Reminders & System Health
          IconButton(
            icon: const Icon(LucideIcons.bell, size: 18),
            tooltip: 'Reminders & Notifications',
            onPressed: () => context.push('/reminders'),
          ),
          // Theme Toggle
          IconButton(
            icon: Icon(
              isDark ? LucideIcons.sun : LucideIcons.moon,
              size: 18,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          if (MediaQuery.of(context).size.width >= 720) ...[
            IconButton(
              icon: const Icon(LucideIcons.calendar, size: 18),
              tooltip: 'Calendar & Agenda',
              onPressed: () => context.push('/calendar'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.folder, size: 18),
              tooltip: 'Projects & Milestones',
              onPressed: () => context.push('/projects'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.fileText, size: 18),
              tooltip: 'Notes & Quick Capture',
              onPressed: () => context.push('/notes'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.layoutGrid, size: 18),
              tooltip: 'Customize Layout',
              onPressed: () => context.push('/screen-builder'),
            ),
            IconButton(
              icon: const Icon(LucideIcons.settings, size: 18),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.moreVertical, size: 18),
              tooltip: 'Navigation Menu',
              onSelected: (route) => context.push(route),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: '/focus-guard',
                  child: Row(
                    children: [
                      Icon(LucideIcons.shieldAlert, size: 16, color: AppColors.urgent),
                      SizedBox(width: 10),
                      Text('Focus Guard (Phase 7)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/calendar',
                  child: Row(
                    children: [
                      Icon(LucideIcons.calendar, size: 16),
                      SizedBox(width: 10),
                      Text('Calendar & Agenda'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/projects',
                  child: Row(
                    children: [
                      Icon(LucideIcons.folder, size: 16),
                      SizedBox(width: 10),
                      Text('Projects & Milestones'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/notes',
                  child: Row(
                    children: [
                      Icon(LucideIcons.fileText, size: 16),
                      SizedBox(width: 10),
                      Text('Notes & Knowledge'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/screen-builder',
                  child: Row(
                    children: [
                      Icon(LucideIcons.layoutGrid, size: 16),
                      SizedBox(width: 10),
                      Text('Customize Layout'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: '/settings',
                  child: Row(
                    children: [
                      Icon(LucideIcons.settings, size: 16),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: AppTokens.space8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final isCompactMobile = constraints.maxWidth < 360;
            final horizontalPadding = isCompactMobile
                ? AppTokens.space12
                : (isWide ? AppTokens.space24 : AppTokens.space16);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppTokens.space12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isWide
                      ? _buildDynamicDesktopGrid(activeLayout, context, ref)
                      : _buildDynamicMobileStack(activeLayout, context, ref),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDynamicMobileStack(List<String> layout, BuildContext context, WidgetRef ref) {
    final widgets = layout
        .map((id) => _buildWidgetById(id, context, ref))
        .where((w) => w != null)
        .cast<Widget>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final widget in widgets) ...[
          widget,
          const SizedBox(height: AppTokens.space12),
        ],
        const SizedBox(height: AppTokens.space24),
      ],
    );
  }

  Widget _buildDynamicDesktopGrid(List<String> layout, BuildContext context, WidgetRef ref) {
    final widgets = layout
        .map((id) => _buildWidgetById(id, context, ref))
        .where((w) => w != null)
        .cast<Widget>()
        .toList();

    final leftWidgets = <Widget>[];
    final rightWidgets = <Widget>[];

    for (var i = 0; i < widgets.length; i++) {
      if (i % 2 == 0) {
        leftWidgets.add(widgets[i]);
      } else {
        rightWidgets.add(widgets[i]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              for (final w in leftWidgets) ...[
                w,
                const SizedBox(height: AppTokens.space16),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppTokens.space16),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              for (final w in rightWidgets) ...[
                w,
                const SizedBox(height: AppTokens.space16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
