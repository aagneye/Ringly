import 'package:flutter/material.dart';

/// A temporary stand-in for a tab whose feature has not been built yet.
///
/// Deliberately has no Scaffold or AppBar: it renders inside [AppShell], which
/// already provides the frame, the floating menu button and the bottom bar.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 68, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Coming soon.', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
