/// One entry read from the phone's address book.
///
/// A trimmed-down view of the platform contact: just the fields Ringly uses to
/// match a spoken name and to show "here's who I think you meant". Kept
/// separate from the plugin's own `Contact` type so the matching and UI layers
/// don't depend on flutter_contacts and stay trivially testable.
class DeviceContact {
  const DeviceContact({
    required this.id,
    required this.displayName,
    this.company,
    this.phones = const [],
    this.emails = const [],
  });

  final String id;
  final String displayName;

  /// First non-empty organisation company, if any.
  final String? company;

  /// Raw phone numbers, in the order the platform returned them.
  final List<String> phones;

  /// Email addresses, in the order the platform returned them.
  final List<String> emails;

  /// The first phone or email, whichever exists — for the one-line "reach them
  /// at" hint on the suggestion card.
  String? get primaryContactLine =>
      phones.isNotEmpty ? phones.first : (emails.isNotEmpty ? emails.first : null);
}
