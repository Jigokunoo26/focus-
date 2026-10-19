import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/providers/database_provider.dart';
import 'platform/home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent SQLite database
  await AppDatabase.getInstance();

  // Initialize HomeWidget App Group
  await HomeWidgetService.initialize();

  runApp(
    const ProviderScope(
      child: FocusPersonalOSApp(),
    ),
  );
}

class FocusPersonalOSApp extends ConsumerStatefulWidget {
  const FocusPersonalOSApp({super.key});

  @override
  ConsumerState<FocusPersonalOSApp> createState() => _FocusPersonalOSAppState();
}

class _FocusPersonalOSAppState extends ConsumerState<FocusPersonalOSApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initHomeWidgetListener();
  }

  void _initHomeWidgetListener() async {
    final initialUri = await HomeWidgetService.getInitiallyLaunchedUri();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
    _sub = HomeWidgetService.listenToWidgetClicks((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final host = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
    switch (host) {
      case 'add_task':
      case 'tasks':
        appRouter.push('/tasks');
        break;
      case 'focus':
      case 'focus_start':
        appRouter.push('/focus');
        break;
      case 'habits':
        appRouter.push('/habits');
        break;
      case 'calendar':
        appRouter.push('/calendar');
        break;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'FOCUS — Personal OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
