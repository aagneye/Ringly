import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../data/contacts/contacts_source.dart';
import '../../providers/contacts_providers.dart';

/// A reusable row for connecting the phone's contacts.
///
/// Shows the current permission state and the right action for it:
///   - not granted yet → a "Connect" button that prompts, then refreshes the
///     contacts providers so the rest of the UI reacts;
///   - permanently denied → "Open settings", since only the OS can re-grant it;
///   - granted → a quiet "Connected" confirmation.
///
/// Used by the suggestion card, and available to the settings screen later.
class ConnectContactsTile extends ConsumerWidget {
  const ConnectContactsTile({super.key});

  Future<void> _connect(WidgetRef ref) async {
    final permission = await ref.read(contactsSourceProvider).permission(request: true);
    if (permission == ContactsPermission.permanentlyDenied) {
      await openAppSettings();
    }
    // Re-read permission and reload contacts regardless of the outcome.
    ref
      ..invalidate(contactsPermissionProvider)
      ..invalidate(deviceContactsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final permission = ref.watch(contactsPermissionProvider);

    final state = permission.value ?? ContactsPermission.denied;
    final granted = state == ContactsPermission.granted;
    final permanent = state == ContactsPermission.permanentlyDenied;

    return ListTile(
      dense: true,
      leading: const Icon(Icons.contacts_outlined, color: AppColors.textSecondary),
      title: Text('Phone contacts', style: textTheme.bodyMedium),
      subtitle: Text(
        granted
            ? 'Connected — used to match spoken names'
            : permanent
                ? 'Turned off — enable Contacts in Settings'
                : 'Not connected',
        style: textTheme.bodySmall,
      ),
      trailing: granted
          ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20)
          : permanent
              ? TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open settings'),
                )
              : TextButton(
                  onPressed: () => _connect(ref),
                  child: const Text('Connect'),
                ),
    );
  }
}
