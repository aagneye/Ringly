import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'circular_menu_button.dart';
import 'nav_destinations.dart';

/// The persistent scaffold that wraps every top-level page.
///
/// Renders the page [child] above a white bottom navigation bar built from
/// [kNavDestinations]. A circular white menu button floats in the top-left and
/// opens a drawer. The selected tab is derived from the current route, so
/// deep-linking straight to `/pipeline` highlights the right tab without any
/// extra state.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = kNavDestinations.indexWhere(
      (d) => location.startsWith(d.location),
    );
    // Default to the first tab if the current route isn't one of the
    // destinations (keeps the bar from showing a broken selection).
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    return Scaffold(
      key: scaffoldKey,
      drawer: const _AppDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 12,
              left: 16,
              child: CircularMenuButton(
                onTap: () => scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.accent.withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex(context),
            elevation: 0,
            height: 64,
            backgroundColor: AppColors.surface,
            onDestinationSelected: (index) {
              context.goNamed(kNavDestinations[index].routeName);
            },
            destinations: [
              for (final d in kNavDestinations)
                NavigationDestination(
                  icon: Icon(d.icon, color: AppColors.textSecondary),
                  selectedIcon: Icon(d.selectedIcon, color: AppColors.accent),
                  label: d.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The slide-in drawer opened by the circular menu button. Lists the same
/// destinations as the bottom bar plus a sign-out entry that returns to login.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Ringly',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            for (final d in kNavDestinations)
              ListTile(
                leading: Icon(d.icon, color: AppColors.textSecondary),
                title: Text(
                  d.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  context.goNamed(d.routeName);
                },
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.textSecondary,
              ),
              title: Text(
                'Sign out',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.goNamed('login');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
