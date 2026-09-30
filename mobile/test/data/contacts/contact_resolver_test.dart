import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/matching/contact_matching.dart';
import 'package:ringly_mobile/data/contacts/contact_resolver.dart';
import 'package:ringly_mobile/data/contacts/device_contact.dart';

void main() {
  final contacts = <DeviceContact>[
    const DeviceContact(
      id: 'p1',
      displayName: 'Priya Sharma',
      company: 'The Northwind Group Ltd.',
      phones: ['+1 555 0100'],
      emails: ['priya@northwind.example'],
    ),
    const DeviceContact(id: 'a1', displayName: 'Ahmed Khan', company: 'Kessler'),
    const DeviceContact(id: 's1', displayName: 'Sam Torres', company: 'Acme'),
    const DeviceContact(id: 's2', displayName: 'Sam Whitfield', company: 'Vertex'),
    const DeviceContact(id: 'j1', displayName: 'José Álvarez', company: 'Ibérica'),
  ];

  final resolver = ContactResolver(contacts);

  test('resolves a unique first name with no company', () {
    final match = resolver.resolve('Ahmed', null);
    expect(match, isNotNull);
    expect(match!.contact.id, 'a1');
    expect(match.confidence, MatchConfidence.fuzzy);
  });

  test('disambiguates a duplicated first name using the company', () {
    final match = resolver.resolve('Sam', 'Vertex');
    expect(match, isNotNull);
    expect(match!.contact.id, 's2');
    expect(match.confidence, MatchConfidence.company);
  });

  test('matches on company even when the stored name has legal suffixes', () {
    final match = resolver.resolve('Priya', 'Northwind');
    expect(match, isNotNull);
    expect(match!.contact.id, 'p1');
    expect(match.confidence, MatchConfidence.company);
  });

  test('matches through accents', () {
    final match = resolver.resolve('Jose Alvarez', null);
    expect(match, isNotNull);
    expect(match!.contact.id, 'j1');
    expect(match.confidence, MatchConfidence.exact);
  });

  test('returns null for an ambiguous first name with no company', () {
    expect(resolver.resolve('Sam', null), isNull);
  });

  test('returns null when nobody matches', () {
    expect(resolver.resolve('Rajesh Patel', 'Globex'), isNull);
  });

  test('returns null for a null or empty spoken name', () {
    expect(resolver.resolve(null, 'Northwind'), isNull);
    expect(resolver.resolve('   ', 'Northwind'), isNull);
  });

  test('returns null against an empty address book', () {
    expect(ContactResolver(const []).resolve('Priya', 'Northwind'), isNull);
  });
}
