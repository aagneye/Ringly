/// Resolving a spoken name to a stored contact.
///
/// A voice memo gives you "spoke to priya at northwind" — no ID, inconsistent
/// casing, and a transcriber that may render "Northwind" as "North Wind". If
/// matching fails the memory silently forks into two half-contacts, which
/// defeats the entire point of the product, so this module is deliberately
/// conservative and heavily tested.
///
/// This is a faithful Dart port of src/lib/domain/contact-matching.ts. Dart's
/// standard library has no `String.normalize('NFKD')`, so accent stripping is
/// done with an explicit map of common Latin letters (see [_accentMap]) rather
/// than Unicode decomposition.
library;

/// Words that carry no identifying signal in a company name.
const Set<String> _companyNoise = {
  'inc',
  'inc.',
  'llc',
  'ltd',
  'ltd.',
  'limited',
  'corp',
  'corp.',
  'corporation',
  'co',
  'co.',
  'company',
  'gmbh',
  'plc',
  'pvt',
  'private',
  'the',
  'group',
  'holdings',
  'technologies',
  'technology',
  'labs',
  'lab',
  'solutions',
  'systems',
  'services',
  'software',
};

/// Accented Latin letters mapped to their base letter. Dart has no NFKD, so we
/// approximate the `.normalize('NFKD').replace(/[\u0300-\u036f]/g, '')` step of
/// the TypeScript original for the letters that actually turn up in names.
const Map<String, String> _accentMap = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
  'ð': 'd', 'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
  'ĥ': 'h', 'ħ': 'h',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i', 'ı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
  'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
  'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's',
  'ţ': 't', 'ť': 't', 'ŧ': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ŵ': 'w',
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
};

/// Replace accented letters with their base letter. Case-insensitive: we
/// lowercase before lookup, matching where `normaliseName` lowercases anyway.
String _stripAccents(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final mapped = _accentMap[lower];
    if (mapped != null) {
      // Preserve nothing about case: normaliseName lowercases immediately after.
      buffer.write(mapped);
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

final RegExp _nonAlphaNum = RegExp(r'[^a-z0-9\s]');
final RegExp _whitespace = RegExp(r'\s+');

/// Lowercase, strip accents and punctuation, collapse whitespace.
String normaliseName(String input) {
  return _stripAccents(input)
      .toLowerCase()
      .replaceAll(_nonAlphaNum, ' ')
      .replaceAll(_whitespace, ' ')
      .trim();
}

/// Normalise a company name and drop legal suffixes and filler words, so
/// "The Northwind Group Ltd." and "northwind" compare equal.
String normaliseCompany(String input) {
  final base = normaliseName(input);
  if (base.isEmpty) return '';

  final words = base.split(' ');
  final kept = words.where((word) => !_companyNoise.contains(word)).toList();
  // If every token was noise, fall back to the normalised original rather than
  // returning an empty key that would match every other all-noise company.
  return (kept.isNotEmpty ? kept : words).join('');
}

/// First name only, for greeting and for loose matching.
String firstName(String input) {
  final normalised = normaliseName(input);
  final parts = normalised.split(' ');
  return parts.isNotEmpty ? parts[0] : '';
}

/// Levenshtein distance, capped for early exit.
///
/// Used to absorb transcription slips like "Priya" versus "Prea". Capping keeps
/// it linear in practice and stops a long string pair from dominating a request.
int editDistance(String a, String b, {int cap = 3}) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > cap) return cap + 1;

  var previous = List<int>.generate(b.length + 1, (i) => i);

  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    var rowMin = i;

    for (var j = 1; j <= b.length; j++) {
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      final insertion = current[j - 1] + 1;
      final deletion = previous[j] + 1;
      final value = [substitution, insertion, deletion].reduce((x, y) => x < y ? x : y);
      current[j] = value;
      if (value < rowMin) rowMin = value;
    }

    if (rowMin > cap) return cap + 1;
    previous = current;
  }

  return previous[b.length];
}

/// A stored contact, pre-normalised for matching.
class MatchCandidate {
  const MatchCandidate({
    required this.id,
    required this.normalisedName,
    required this.normalisedCompany,
  });

  final String id;
  final String normalisedName;
  final String? normalisedCompany;
}

/// How confident a match is: exact name, name plus company, or fuzzy.
enum MatchConfidence { exact, company, fuzzy }

/// The stored contact a spoken name resolved to, and how sure we are.
class MatchResult {
  const MatchResult({required this.id, required this.confidence});

  final String id;
  final MatchConfidence confidence;

  @override
  bool operator ==(Object other) =>
      other is MatchResult && other.id == id && other.confidence == confidence;

  @override
  int get hashCode => Object.hash(id, confidence);

  @override
  String toString() => 'MatchResult(id: $id, confidence: ${confidence.name})';
}

String _firstToken(String value) {
  final parts = value.split(' ');
  return parts.isNotEmpty ? parts[0] : '';
}

/// Pick the stored contact a spoken name refers to.
///
/// Ordered by how much evidence each rule requires, strongest first. A fuzzy
/// name match is only trusted when the company also agrees, because merging two
/// different clients is far more damaging than creating a duplicate the user can
/// see and fix.
MatchResult? matchContact(
  String spokenName,
  String? spokenCompany,
  List<MatchCandidate> candidates,
) {
  final name = normaliseName(spokenName);
  if (name.isEmpty) return null;

  final company =
      (spokenCompany != null && spokenCompany.isNotEmpty) ? normaliseCompany(spokenCompany) : null;

  for (final c in candidates) {
    if (c.normalisedName == name) {
      return MatchResult(id: c.id, confidence: MatchConfidence.exact);
    }
  }

  if (company != null) {
    final sameCompany = candidates.where((c) => c.normalisedCompany == company).toList();

    for (final c in sameCompany) {
      if (_firstToken(c.normalisedName) == _firstToken(name)) {
        return MatchResult(id: c.id, confidence: MatchConfidence.company);
      }
    }

    for (final c in sameCompany) {
      if (editDistance(c.normalisedName, name, cap: 2) <= 2) {
        return MatchResult(id: c.id, confidence: MatchConfidence.fuzzy);
      }
    }
  }

  // No company to corroborate: only accept a unique first-name match, so that
  // two contacts both called "Sam" never silently collapse into one.
  final spokenFirst = _firstToken(name);
  final firstNameMatches =
      candidates.where((c) => _firstToken(c.normalisedName) == spokenFirst).toList();
  if (firstNameMatches.length == 1) {
    return MatchResult(id: firstNameMatches[0].id, confidence: MatchConfidence.fuzzy);
  }

  return null;
}
