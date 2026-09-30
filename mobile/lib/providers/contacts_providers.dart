import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contacts/contact_resolver.dart';
import '../data/contacts/contacts_source.dart';
import '../data/contacts/device_contact.dart';

/// The device address-book reader. Overridden with a fake in tests.
final contactsSourceProvider = Provider<ContactsSource>(
  (ref) => const FlutterContactsSource(),
);

/// Current contacts permission, read *without* prompting the user.
///
/// The connect card watches this to decide whether to show a "Connect" button
/// or the resolved match. Requesting permission is a deliberate user action, so
/// it never happens here — only [ContactsSource.permission] with request: true
/// (called from the button) does that.
final contactsPermissionProvider = FutureProvider<ContactsPermission>(
  (ref) => ref.watch(contactsSourceProvider).permission(),
);

/// True when contacts are readable. Drives the Integrations row and the
/// suggestion card. Defaults to false while the permission check is in flight.
final contactsConnectedProvider = Provider<bool>((ref) {
  return ref.watch(contactsPermissionProvider).value == ContactsPermission.granted;
});

/// Every device contact, or an empty list when permission is not granted.
final deviceContactsProvider = FutureProvider<List<DeviceContact>>(
  (ref) => ref.watch(contactsSourceProvider).load(),
);

/// A resolver built over the loaded contacts. Empty (matches nothing) until
/// contacts have loaded.
final contactResolverProvider = Provider<ContactResolver>((ref) {
  final contacts = ref.watch(deviceContactsProvider).value ?? const [];
  return ContactResolver(contacts);
});
