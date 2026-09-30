import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/widgets/app_shell.dart';

/// Route names, defined once so every `context.goNamed(...)` call in the app
/// refers to a constant instead of a raw string. Matches the page list in
/// docs/flutter-migration-plan.md section 4.
abstract final class AppRoutes {
  static const today = 'today';
  static const pipeline = 'pipeline';
  static const recorder = 'recorder';
  static const models = 'models';
  static const dealDetail = 'deal-detail';
  static const draftReview = 'draft-review';
}

/// The router skeleton. Each route below is a temporary placeholder screen
/// until its feature phase (G–L in the migration plan) replaces it — kept
/// buildable at every commit rather than left half-wired.
final GoRouter appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    GoRoute(
      path: '/today',
      name: AppRoutes.today,
      builder: (context, state) => const AppShell(
        child: _PlaceholderPage(title: 'Today'),
      ),
    ),
    GoRoute(
      path: '/pipeline',
      name: AppRoutes.pipeline,
      builder: (context, state) => const AppShell(
        child: _PlaceholderPage(title: 'Pipeline'),
      ),
    ),
    GoRoute(
      path: '/recorder',
      name: AppRoutes.recorder,
      builder: (context, state) => const AppShell(
        child: _PlaceholderPage(title: 'Record a memo'),
      ),
    ),
    GoRoute(
      path: '/models',
      name: AppRoutes.models,
      builder: (context, state) => const AppShell(
        child: _PlaceholderPage(title: 'Models'),
      ),
    ),
  ],
);

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — coming in a later phase')),
    );
  }
}

/// Root widget. Wrapped in ProviderScope by the entrypoints (main_dev.dart /
/// main_prod.dart), not here — this widget has no opinion on which backend
/// it talks to.
class RinglyApp extends StatelessWidget {
  const RinglyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ringly',
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
