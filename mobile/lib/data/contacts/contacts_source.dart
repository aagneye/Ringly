import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';

import 'device_contact.dart';

/// The three permission states Ringly cares about.
///
/// [denied] means "not granted yet, but we can still ask". [permanentlyDenied]
/// means the user tapped "don't ask again" — only the OS settings page can fix
/// it, so the UI must send them there rather than prompt again in vain.
enum ContactsPermission { granted, denied, permanentlyDenied }

/// Reads the device address book. An interface so tests can supply a fake
/// without touching the platform channel.
abstract interface class ContactsSource {
  /// Current permission state. Pass [request] true to prompt the user if they
  /// haven't answered yet; false to only read the current status silently.
  Future<ContactsPermission> permission({bool request = false});

  /// All contacts, as [DeviceContact]s. Returns an empty list when permission
  /// is not granted.
  Future<List<DeviceContact>> load();
}

/// Real implementation backed by the flutter_contacts plugin.
class FlutterContactsSource implements ContactsSource {
  const FlutterContactsSource();

  @override
  Future<ContactsPermission> permission({bool request = false}) async {
    if (request) {
      // requestPermission returns true only when granted. When it returns
      // false, fall through to permission_handler to tell "denied" from
      // "permanently denied" so the caller can route to app settings.
      final granted = await fc.FlutterContacts.requestPermission(readonly: true);
      if (granted) return ContactsPermission.granted;
    }
    return _statusFromHandler(await Permission.contacts.status);
  }

  static ContactsPermission _statusFromHandler(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return ContactsPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return ContactsPermission.permanentlyDenied;
    }
    return ContactsPermission.denied;
  }

  @override
  Future<List<DeviceContact>> load() async {
    if (await permission() != ContactsPermission.granted) return const [];

    final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
    return [
      for (final c in contacts)
        DeviceContact(
          id: c.id,
          displayName: c.displayName,
          company: _firstCompany(c.organizations),
          phones: [
            for (final p in c.phones)
              if (p.number.trim().isNotEmpty) p.number.trim(),
          ],
          emails: [
            for (final e in c.emails)
              if (e.address.trim().isNotEmpty) e.address.trim(),
          ],
        ),
    ];
  }

  static String? _firstCompany(List<fc.Organization> organizations) {
    for (final org in organizations) {
      if (org.company.trim().isNotEmpty) return org.company.trim();
    }
    return null;
  }
}
