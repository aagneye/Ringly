import 'package:flutter/material.dart';

/// Placeholder bottom-nav scaffold.
///
/// Filled in properly in Phase M once the four top-level pages (Today,
/// Pipeline, Recorder, Models — see docs/flutter-migration-plan.md section 4)
/// exist. Kept as a real, buildable widget now rather than deferred, so
/// app.dart has something concrete to route to while those pages are built
/// feature by feature.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
