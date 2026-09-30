import '../../core/matching/contact_matching.dart';
import 'device_contact.dart';

/// A matched device contact plus how confident the match is.
class ContactMatch {
  const ContactMatch({required this.contact, required this.confidence});

  final DeviceContact contact;
  final MatchConfidence confidence;
}

/// Resolves a spoken name (and optional company) against the phone's contacts.
///
/// Builds [MatchCandidate]s once at construction so repeated resolves are cheap,
/// then delegates the actual decision to [matchContact] — the same conservative
/// logic used on the server, ported in contact_matching.dart.
class ContactResolver {
  ContactResolver(List<DeviceContact> contacts)
      : _byId = {for (final c in contacts) c.id: c},
        _candidates = [
          for (final c in contacts)
            MatchCandidate(
              id: c.id,
              normalisedName: normaliseName(c.displayName),
              normalisedCompany:
                  (c.company != null && c.company!.isNotEmpty) ? normaliseCompany(c.company!) : null,
            ),
        ];

  final Map<String, DeviceContact> _byId;
  final List<MatchCandidate> _candidates;

  /// Returns the best contact for [spokenName]/[spokenCompany], or null when
  /// there is no name to match or no confident candidate.
  ContactMatch? resolve(String? spokenName, String? spokenCompany) {
    if (spokenName == null || spokenName.trim().isEmpty) return null;

    final result = matchContact(spokenName, spokenCompany, _candidates);
    if (result == null) return null;

    final contact = _byId[result.id];
    if (contact == null) return null;

    return ContactMatch(contact: contact, confidence: result.confidence);
  }
}
