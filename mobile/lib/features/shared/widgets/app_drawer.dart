import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/memo/local_memo.dart';
import '../../../providers/memo_providers.dart';
import 'nav_destinations.dart';

/// The slide-in drawer opened by the circular menu button.
///
/// Grouped to mirror the settings screen: the five nav destinations up top,
/// then Connections / Voice / Data / AI shortcuts, and Sign out at the bottom.
/// The Data group carries a badge counting memos still waiting to sync.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    final memos = ref.watch(memosProvider).value ?? const <LocalMemo>[];
    final pending = memos
        .where((m) =>
            m.status == MemoStatus.pending || m.status == MemoStatus.syncing)
        .length;

    void goHome() {
      Navigator.of(context).pop();
      context.goNamed(AppRoutes.home);
    }

    void openSettings() {
      Navigator.of(context).pop();
      // Full-screen, so push over the shell rather than replacing the tab.
      context.pushNamed(AppRoutes.settings);
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Ringly', style: textTheme.headlineMedium),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'test123@gmail.com',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _GroupLabel('Navigate'),
                  for (final d in kNavDestinations)
                    _DrawerItem(
                      icon: d.icon,
                      label: d.label,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.goNamed(d.routeName);
                      },
                    ),
                  _GroupLabel('Connections'),
                  _DrawerItem(
                    icon: Icons.extension_outlined,
                    label: 'Integrations',
                    onTap: goHome,
                  ),
                  _GroupLabel('Voice & transcription'),
                  _DrawerItem(
                    icon: Icons.mic_none_outlined,
                    label: 'Transcription settings',
                    onTap: openSettings,
                  ),
                  _GroupLabel('Data & privacy'),
                  _DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Data & privacy',
                    badgeCount: pending,
                    onTap: openSettings,
                  ),
                  _GroupLabel('AI'),
                  _DrawerItem(
                    icon: Icons.insights_outlined,
                    label: 'Models & usage',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.goNamed(AppRoutes.models);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: openSettings,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _DrawerItem(
              icon: Icons.logout,
              label: 'Sign out',
              onTap: () {
                Navigator.of(context).pop();
                context.goNamed(AppRoutes.login);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A small-caps section label between drawer groups.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

/// One tappable drawer row, optionally carrying a numeric badge.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: badgeCount == 0
          ? null
          : CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.accent,
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: AppColors.onAccent, fontSize: 11),
              ),
            ),
      onTap: onTap,
    );
  }
}
