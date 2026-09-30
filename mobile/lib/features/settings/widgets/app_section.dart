import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import 'settings_section.dart';

/// "App": version, open-source licenses, and sign out.
class AppSection extends StatelessWidget {
  const AppSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'App',
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('About'),
          subtitle: Text('Ringly 1.0.0'),
        ),
        const Divider(height: 1, color: AppColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Ringly',
            applicationVersion: '1.0.0',
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () => context.goNamed(AppRoutes.login),
        ),
      ],
    );
  }
}
