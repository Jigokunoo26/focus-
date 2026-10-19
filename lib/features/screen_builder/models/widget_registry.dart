import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WidgetDescriptor {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category; // 'Core', 'Productivity', 'Focus', 'System'

  const WidgetDescriptor({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });
}

class WidgetRegistry {
  WidgetRegistry._();

  static const List<WidgetDescriptor> availableWidgets = [
    WidgetDescriptor(
      id: 'clock_date',
      name: 'Clock & Date',
      description: 'Monospace Nothing-style clock with live seconds and date',
      icon: LucideIcons.clock,
      category: 'Core',
    ),
    WidgetDescriptor(
      id: 'quick_actions',
      name: 'Quick Action Bar',
      description: 'One-tap buttons to add task, start focus, log habit, or dictate',
      icon: LucideIcons.zap,
      category: 'Core',
    ),
    WidgetDescriptor(
      id: 'daily_overview',
      name: 'Daily Overview',
      description: 'Completion progress ring with active & urgent metrics',
      icon: LucideIcons.target,
      category: 'Productivity',
    ),
    WidgetDescriptor(
      id: 'task_glance',
      name: 'Priority Tasks Glance',
      description: 'Top priority tasks with inline checkoff and priority indicators',
      icon: LucideIcons.checkSquare,
      category: 'Productivity',
    ),
    WidgetDescriptor(
      id: 'focus_timer',
      name: 'Focus Session Block',
      description: '25-minute Pomodoro timer with Apple-style progress ring',
      icon: LucideIcons.timer,
      category: 'Focus',
    ),
    WidgetDescriptor(
      id: 'habit_streak',
      name: 'Habit Streaks',
      description: 'Track daily streaks with quick-tap completion pills',
      icon: LucideIcons.flame,
      category: 'Focus',
    ),
    WidgetDescriptor(
      id: 'countdown',
      name: 'Milestone Countdown',
      description: 'Countdown to next project deadline or important date',
      icon: LucideIcons.hourglass,
      category: 'Productivity',
    ),
    WidgetDescriptor(
      id: 'agenda_glance',
      name: 'Today Agenda & Events',
      description: 'Snapshot of upcoming scheduled events and agenda timeline',
      icon: LucideIcons.calendar,
      category: 'Productivity',
    ),
    WidgetDescriptor(
      id: 'device_status',
      name: 'System & Security',
      description: 'Durable SQLite status, local privacy guarantee, and platform host',
      icon: LucideIcons.shieldCheck,
      category: 'System',
    ),
  ];

  static WidgetDescriptor? getById(String id) {
    try {
      return availableWidgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  // Preset Layouts
  static const Map<String, List<String>> presets = {
    'Full Command Center': [
      'clock_date',
      'quick_actions',
      'daily_overview',
      'task_glance',
      'focus_timer',
      'habit_streak',
      'countdown',
      'device_status',
    ],
    'Deep Work Focus': [
      'clock_date',
      'focus_timer',
      'task_glance',
      'habit_streak',
    ],
    'Minimalist OS': [
      'clock_date',
      'quick_actions',
      'task_glance',
    ],
  };
}
