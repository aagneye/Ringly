import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/health.dart';
import '../../../providers/data_providers.dart';
import 'home_section.dart';

/// One connection row: what it is, and whether it's live.
class IntegrationStatus {
  const IntegrationStatus({
    required this.icon,
    required this.name,
    required this.detail,
    required this.connected,
  });

  final IconData icon;
  final String name;
  final String detail;
  final bool connected;
}

/// Build the integration rows from server health plus device-side facts.
///
/// Email and calendar are always available: drafts hand off to the user's own
/// mail client via mailto:, and meetings export as .ics files — no OAuth.
List<IntegrationStatus> integrationsFor(
  HealthStatus health, {
  bool contactsConnected = false,
}) =>
    [
      IntegrationStatus(
        icon: Icons.auto_awesome,
        name: 'Nemotron on Nebius',
        detail: health.nebius ? 'Connected' : 'Add NEBIUS_API_KEY on the server',
        connected: health.nebius,
      ),
      IntegrationStatus(
        icon: Icons.storage_outlined,
        name: 'Pipeline database',
        detail: health.database ? 'Connected' : 'Add DATABASE_URL on the server',
        connected: health.database,
      ),
      IntegrationStatus(
        icon: Icons.travel_explore,
        name: 'Tavily company research',
        detail: health.tavily ? 'Connected' : 'Optional — add TAVILY_API_KEY',
        connected: health.tavily,
      ),
      const IntegrationStatus(
        icon: Icons.mail_outline,
        name: 'Email',
        detail: 'Drafts open in your own mail app',
        connected: true,
      ),
      const IntegrationStatus(
        icon: Icons.event_outlined,
        name: 'Calendar',
        detail: 'Meetings export as .ics',
        connected: true,
      ),
      IntegrationStatus(
        icon: Icons.contacts_outlined,
        name: 'Contacts',
        detail: contactsConnected ? 'Used to match names' : 'Not connected',
        connected: contactsConnected,
      ),
    ];

/// Which integrations are live, plus anything waiting to sync.
class IntegrationsSection extends ConsumerWidget {
  const IntegrationsSection({super.key, this.contactsConnected = false});

  final bool contactsConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeSection(
      title: 'Integrations',
      child: AsyncSectionBody<HealthStatus>(
        value: ref.watch(healthProvider),
        builder: (health) => SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final row in integrationsFor(health, contactsConnected: contactsConnected))
                ListTile(
                  dense: true,
                  leading: Icon(row.icon, color: AppColors.textSecondary),
                  title: Text(row.name, style: Theme.of(context).textTheme.bodyMedium),
                  subtitle: Text(row.detail, style: Theme.of(context).textTheme.bodySmall),
                  trailing: Icon(
                    row.connected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: row.connected ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
