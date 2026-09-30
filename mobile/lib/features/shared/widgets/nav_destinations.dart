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
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String routeName;
  final String location;
}

/// The four top-level destinations shown in the bottom nav bar, in order.
const List<NavDestinationSpec> kNavDestinations = [
  NavDestinationSpec(
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    label: 'Today',
    routeName: AppRoutes.today,
    location: '/today',
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
  ),
  NavDestinationSpec(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    label: 'Models',
    routeName: AppRoutes.models,
    location: '/models',
  ),
];
