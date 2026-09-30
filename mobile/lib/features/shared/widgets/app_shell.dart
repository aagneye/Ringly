import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/outbox_providers.dart';
import '../../../providers/pending_actions_provider.dart';
import 'app_drawer.dart';
import 'circular_menu_button.dart';
import 'nav_destinations.dart';
import 'ringly_bottom_bar.dart';

/// The persistent scaffold that wraps every top-level page.
///
/// Renders the page [child] above [RinglyBottomBar] (five tabs, raised Record
/// button). A circular white menu button floats in the top-left and opens the
/// drawer. The selected tab is derived from the current route, so deep-linking
/// straight to `/pipeline` highlights the right tab without any extra state.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navIndexForPath(GoRouterState.of(context).uri.path);
    final badge = ref.watch(pendingActionsCountProvider);
    // Keep the offline outbox draining for the app's lifetime.
    ref.watch(outboxStarterProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 12,
              left: 16,
              // Builder gives a context below the Scaffold, so openDrawer
              // resolves without holding a GlobalKey across rebuilds.
              child: Builder(
                builder: (inner) => CircularMenuButton(
                  onTap: () => Scaffold.of(inner).openDrawer(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RinglyBottomBar(
        selectedIndex: index < 0 ? 0 : index,
        actionsBadgeCount: badge,
        onSelected: (i) => context.goNamed(kNavDestinations[i].routeName),
      ),
    );
  }
}
