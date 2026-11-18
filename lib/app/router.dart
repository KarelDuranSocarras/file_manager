import 'package:go_router/go_router.dart';

import '../features/settings/presentation/pages/settings_page.dart';
import '../features/sync/presentation/pages/activity_page.dart';
import '../features/sync/presentation/pages/home_page.dart';
import '../features/sync/presentation/pages/trash_page.dart';
import 'shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/actividad',
          builder: (context, state) => const ActivityPage(),
        ),
        GoRoute(
          path: '/papelera',
          builder: (context, state) => const TrashPage(),
        ),
        GoRoute(
          path: '/ajustes',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
