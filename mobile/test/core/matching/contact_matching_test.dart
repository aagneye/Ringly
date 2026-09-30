import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/matching/contact_matching.dart';

void main() {
  group('normaliseName', () {
    test('lowercases and collapses whitespace', () {
      expect(normaliseName('  Priya   Sharma '), 'priya sharma');
    });

    test('strips accents', () {
      expect(normaliseName('José Álvarez'), 'jose alvarez');
    });

    test('strips punctuation', () {
      expect(normaliseName("O'Brien-Smith"), 'o brien smith');
    });

    test('returns empty for punctuation only', () {
      expect(normaliseName('---'), '');
    });
  });

  group('normaliseCompany', () {
    test('drops legal suffixes and filler words', () {
      expect(normaliseCompany('The Northwind Group Ltd.'), 'northwind');
    });

    test('treats variants as equal', () {
      expect(normaliseCompany('Acme Technologies Inc'), normaliseCompany('acme'));
    });

    test('joins multi-word names so spacing slips do not matter', () {
      expect(normaliseCompany('North Wind'), 'northwind');
      expect(normaliseCompany('Northwind'), 'northwind');
    });

    test('falls back to the original when every token is noise', () {
      expect(normaliseCompany('The Group'), 'thegroup');
    });

    test('returns empty for an empty input', () {
      expect(normaliseCompany(''), '');
    });
  });

  group('firstName', () {
    test('takes the leading token', () {
      expect(firstName('Priya Sharma'), 'priya');
    });

    test('handles a single name', () {
      expect(firstName('Ahmed'), 'ahmed');
    });
  });

  group('editDistance', () {
    test('is zero for identical strings', () {
      expect(editDistance('priya', 'priya'), 0);
    });

    test('counts a single substitution', () {
      expect(editDistance('priya', 'preya'), 1);
    });

    test('counts a deletion', () {
      expect(editDistance('priya', 'prya'), 1);
    });

    test('exits early past the cap', () {
      expect(editDistance('priya', 'christopher', cap: 3), greaterThan(3));
    });
  });

  group('matchContact', () {
    final candidates = <MatchCandidate>[
      const MatchCandidate(id: 'c1', normalisedName: 'priya sharma', normalisedCompany: 'northwind'),
      const MatchCandidate(id: 'c2', normalisedName: 'ahmed khan', normalisedCompany: 'kessler'),
      const MatchCandidate(id: 'c3', normalisedName: 'sam torres', normalisedCompany: 'acme'),
      const MatchCandidate(id: 'c4', normalisedName: 'sam whitfield', normalisedCompany: 'vertex'),
    ];

    test('matches on an exact normalised name', () {
      expect(
        matchContact('Priya Sharma', null, candidates),
        const MatchResult(id: 'c1', confidence: MatchConfidence.exact),
      );
    });

    test('matches a first name when the company agrees', () {
      expect(
        matchContact('Priya', 'The Northwind Group', candidates),
        const MatchResult(id: 'c1', confidence: MatchConfidence.company),
      );
    });

    test('absorbs a transcription slip when the company agrees', () {
      expect(
        matchContact('Preya Sharma', 'Northwind', candidates),
        const MatchResult(id: 'c1', confidence: MatchConfidence.fuzzy),
      );
    });

    test('matches a unique first name with no company given', () {
      expect(
        matchContact('Ahmed', null, candidates),
        const MatchResult(id: 'c2', confidence: MatchConfidence.fuzzy),
      );
    });

    test('refuses an ambiguous first name with no company', () {
      expect(matchContact('Sam', null, candidates), isNull);
    });

    test('disambiguates a duplicated first name using the company', () {
      expect(
        matchContact('Sam', 'Vertex', candidates),
        const MatchResult(id: 'c4', confidence: MatchConfidence.company),
      );
    });

    test('returns null for an unknown contact', () {
      expect(matchContact('Rajesh Patel', 'Globex', candidates), isNull);
    });

    test('returns null for an empty name', () {
      expect(matchContact('', 'Northwind', candidates), isNull);
    });

    test('returns null against an empty candidate list', () {
      expect(matchContact('Priya', 'Northwind', const []), isNull);
    });
  });
}
