import 'package:flutter/material.dart';
import '../../../app.dart';

/// A single bottom-nav destination: the icon, its label, and the named route
/// it navigates to.
///
/// Kept as a plain data list so [AppShell] can render the bar and resolve the
/// selected index from the current route without hardcoding the mapping in
/// two places.
class NavDestinationSpec {
  const NavDestinationSpec({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.routeName,
    required this.location,
    this.isPrimary = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String routeName;
  final String location;

  /// The raised centre action (Record). Rendered as a circular accent button
  /// instead of a flat tab, because capture is the core loop of the product.
  final bool isPrimary;
}

/// The five top-level destinations shown in the bottom nav bar, in order.
///
/// Record sits in the centre so it is always one thumb-tap away. Actions is
/// the approval queue — the only place irreversible things happen.
const List<NavDestinationSpec> kNavDestinations = [
  NavDestinationSpec(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
    routeName: AppRoutes.home,
    location: '/home',
  ),
  NavDestinationSpec(
    icon: Icons.view_kanban_outlined,
    selectedIcon: Icons.view_kanban,
    label: 'Pipeline',
    routeName: AppRoutes.pipeline,
    location: '/pipeline',
  ),
  NavDestinationSpec(
    icon: Icons.mic_none_outlined,
    selectedIcon: Icons.mic,
    label: 'Record',
    routeName: AppRoutes.recorder,
    location: '/recorder',
    isPrimary: true,
  ),
  NavDestinationSpec(
    icon: Icons.task_alt_outlined,
    selectedIcon: Icons.task_alt,
    label: 'Actions',
    routeName: AppRoutes.actions,
    location: '/actions',
  ),
  NavDestinationSpec(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    label: 'Models',
    routeName: AppRoutes.models,
    location: '/models',
  ),
];

/// Index of the destination matching [path], or -1 when none does.
int navIndexForPath(String path) =>
    kNavDestinations.indexWhere((d) => path.startsWith(d.location));
