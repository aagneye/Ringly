import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'nav_destinations.dart';

/// The persistent scaffold that wraps every top-level page.
///
/// Renders the page [child] above a white bottom navigation bar built from
/// [kNavDestinations]. The selected tab is derived from the current route, so
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
    return Scaffold(
      body: child,
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
