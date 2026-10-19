import 'package:go_router/go_router.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/focus/presentation/focus_guard_screen.dart';
import '../../features/focus/presentation/focus_session_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/reminders/presentation/reminders_screen.dart';
import '../../features/screen_builder/presentation/screen_builder_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/tasks',
      builder: (context, state) => const TasksScreen(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/reminders',
      builder: (context, state) => const RemindersScreen(),
    ),
    GoRoute(
      path: '/habits',
      builder: (context, state) => const HabitsScreen(),
    ),
    GoRoute(
      path: '/focus',
      builder: (context, state) => const FocusSessionScreen(),
    ),
    GoRoute(
      path: '/focus-guard',
      builder: (context, state) => const FocusGuardScreen(),
    ),
    GoRoute(
      path: '/projects',
      builder: (context, state) => const ProjectsScreen(),
    ),
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NotesScreen(),
    ),
    GoRoute(
      path: '/screen-builder',
      builder: (context, state) => const ScreenBuilderScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
