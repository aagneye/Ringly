import 'package:ringly_mobile/data/contacts/contacts_source.dart';
import 'package:ringly_mobile/data/contacts/device_contact.dart';

/// A [ContactsSource] with no platform channel — tests set the permission it
/// reports and the contacts it returns, and can assert whether a prompt was
/// requested.
class FakeContactsSource implements ContactsSource {
  FakeContactsSource({
    this.status = ContactsPermission.denied,
    this.contacts = const [],
    ContactsPermission? afterRequest,
  }) : _afterRequest = afterRequest;

  /// The permission returned by [permission] when not requesting.
  ContactsPermission status;

  /// What [permission(request: true)] resolves to; defaults to [status].
  final ContactsPermission? _afterRequest;

  /// Contacts returned by [load] when granted.
  List<DeviceContact> contacts;

  /// True once [permission(request: true)] has been called.
  bool requested = false;

  @override
  Future<ContactsPermission> permission({bool request = false}) async {
    if (request) {
      requested = true;
      status = _afterRequest ?? status;
    }
    return status;
  }

  @override
  Future<List<DeviceContact>> load() async {
    if (status != ContactsPermission.granted) return const [];
    return contacts;
  }
}
