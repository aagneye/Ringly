import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/theme/app_colors.dart';
import 'settings_section.dart';

/// "Connections": integrations and the phone's contacts permission.
class ConnectionsSection extends StatelessWidget {
  const ConnectionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Connections',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.extension_outlined),
          title: const Text('Integrations'),
          subtitle: const Text('Ringly owns its calendar and exports .ics files'),
          trailing: const Icon(Icons.chevron_right),
          // Full-screen settings sits outside the tab shell; pop back to it,
          // then land on Home where integrations live.
          onTap: () {
            if (context.canPop()) context.pop();
            context.goNamed(AppRoutes.home);
          },
        ),
        const Divider(height: 1, color: AppColors.border),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.contacts_outlined),
          title: Text('Contacts'),
          subtitle: Text(
            'Ringly matches spoken names to your contacts. Grant the contacts '
            'permission when prompted; it\'s only read on-device.',
          ),
          isThreeLine: true,
        ),
      ],
    );
  }
}
