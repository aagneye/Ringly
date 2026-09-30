import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../data/contacts/contact_resolver.dart';
import '../../data/contacts/contacts_source.dart';
import '../../data/models/memo_result.dart';
import '../../providers/contacts_providers.dart';

/// "Did you mean…?" — cross-checks the person a memo was filed against with the
/// phone's own contacts.
///
/// Shows nothing at all unless the match is worth a second look (a fuzzy/new
/// match, or a freshly created contact). When contacts aren't connected it
/// offers a one-tap connect; when they are, it looks the name up locally and,
/// if it finds someone, shows who — honestly labelled as informational, since
/// the backend has no endpoint to merge the two.
class ContactSuggestion extends ConsumerWidget {
  const ContactSuggestion({super.key, required this.target, required this.extraction});

  final MemoTarget target;
  final MemoExtraction extraction;

  Future<void> _connect(WidgetRef ref) async {
    final permission = await ref.read(contactsSourceProvider).permission(request: true);
    if (permission == ContactsPermission.permanentlyDenied) {
      await openAppSettings();
    }
    ref
      ..invalidate(contactsPermissionProvider)
      ..invalidate(deviceContactsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only worth surfacing when the filing is uncertain or brand-new.
    if (!target.isUncertain && !target.createdContact) {
      return const SizedBox.shrink();
    }

    final connected = ref.watch(contactsConnectedProvider);
    if (!connected) {
      return _ConnectCard(
        contactName: extraction.contactName ?? target.contactName,
        onConnect: () => _connect(ref),
      );
    }

    final resolver = ref.watch(contactResolverProvider);
    final match = resolver.resolve(
      extraction.contactName ?? target.contactName,
      extraction.company ?? target.company,
    );
    if (match == null) return const SizedBox.shrink();

    return _MatchCard(match: match, filedUnder: target.contactName);
  }
}

/// Shown when contacts aren't connected yet: explains the value, offers connect.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.contactName, required this.onConnect});

  final String contactName;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.contacts_outlined, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect your contacts so Ringly can match names like "$contactName"',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(onPressed: onConnect, child: const Text('Connect')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a device contact matches: who it is, how to reach them, and an
/// honest note that this is informational only.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.filedUnder});

  final ContactMatch match;
  final String filedUnder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final contact = match.contact;
    final company =
        (contact.company != null && contact.company!.isNotEmpty) ? ' at ${contact.company}' : '';
    final reach = contact.primaryContactLine;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_search_outlined, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Did you mean ${contact.displayName}$company?',
                          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (reach != null) ...[
                          const SizedBox(height: 4),
                          Text(reach, style: textTheme.bodySmall),
                        ],
                        const SizedBox(height: 6),
                        Text('From your phone\'s contacts', style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Ringly filed this under $filedUnder. Edit the deal if that\'s wrong.',
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
