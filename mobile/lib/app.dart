import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/memo/memo_result_screen.dart';
import 'features/recorder/recorder_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shared/widgets/app_shell.dart';
import 'features/shared/widgets/placeholder_page.dart';

/// Route names, defined once so every `context.goNamed(...)` call in the app
/// refers to a constant instead of a raw string. Matches the page list in
/// docs/flutter-migration-plan.md section 4.
abstract final class AppRoutes {
  static const login = 'login';
  static const signup = 'signup';
  static const dashboard = 'dashboard';
  static const home = 'home';
  static const actions = 'actions';
  static const settings = 'settings';
  static const memoResult = 'memo-result';
  static const today = 'today';
  static const pipeline = 'pipeline';
  static const recorder = 'recorder';
  static const models = 'models';
  static const dealDetail = 'deal-detail';
  static const draftReview = 'draft-review';
}

/// The router skeleton. Each route below is a temporary placeholder screen
/// until its feature phase replaces it — kept buildable at every commit rather
/// than left half-wired.
///
/// A factory rather than a single global so widget tests can start the app on
/// any route (e.g. straight onto `/home`) without walking through login.
GoRouter createRouter({String initialLocation = '/login'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/login',
      name: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      name: AppRoutes.signup,
      builder: (context, state) => const SignupScreen(),
    ),
    // Kept as an alias so older links and the auth flow land on Home.
    GoRoute(
      path: '/dashboard',
      name: AppRoutes.dashboard,
      redirect: (context, state) => '/home',
    ),
    GoRoute(
      path: '/home',
      name: AppRoutes.home,
      builder: (context, state) => const AppShell(child: HomeScreen()),
    ),
    GoRoute(
      path: '/pipeline',
      name: AppRoutes.pipeline,
      builder: (context, state) => const AppShell(
        child: PlaceholderPage(title: 'Pipeline'),
      ),
    ),
    GoRoute(
      path: '/recorder',
      name: AppRoutes.recorder,
      builder: (context, state) => const AppShell(child: RecorderScreen()),
    ),
    GoRoute(
      path: '/actions',
      name: AppRoutes.actions,
      builder: (context, state) => const AppShell(
        child: PlaceholderPage(title: 'Actions'),
      ),
    ),
    GoRoute(
      path: '/models',
      name: AppRoutes.models,
      builder: (context, state) => const AppShell(
        child: PlaceholderPage(title: 'Models'),
      ),
    ),
    // Full-screen detail with its own back button, outside the tab shell.
    GoRoute(
      path: '/memo/:id',
      name: AppRoutes.memoResult,
      builder: (context, state) => MemoResultScreen(memoId: state.pathParameters['id']!),
    ),

    // Full-screen: one deal, with the pre-call brief.
    GoRoute(
      path: '/deal/:id',
      name: AppRoutes.dealDetail,
      builder: (context, state) => const PlaceholderPage(title: 'Deal'),
    ),

    // Full-screen: grouped settings, opened from the drawer.
    GoRoute(
      path: '/settings',
      name: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

final GoRouter appRouter = createRouter();

/// Root widget. Wrapped in ProviderScope by the entrypoints (main_dev.dart /
/// main_prod.dart), not here — this widget has no opinion on which backend
/// it talks to.
class RinglyApp extends StatelessWidget {
  const RinglyApp({super.key, this.router});

  /// Overridable for tests; defaults to the app-wide router.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ringly',
      theme: AppTheme.light(),
      routerConfig: router ?? appRouter,
    );
  }
}
