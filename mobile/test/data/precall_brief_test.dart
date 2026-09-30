import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/models/precall_brief.dart';

void main() {
  group('PrecallBrief.fromJson', () {
    test('parses snake_case model output plus camelCase context', () {
      final brief = PrecallBrief.fromJson(const {
        'where_we_are': 'Mid-proposal, waiting on budget sign-off.',
        'they_care_about': ['onboarding time', 'price'],
        'you_promised': [
          {'promise': 'Send revised proposal', 'appears_done': false},
          {'promise': 'Share the case study', 'appears_done': true},
        ],
        'ask_about': ['When can they start?', 'Who signs off?'],
        'contactName': 'Priya Sharma',
        'company': 'Northwind',
        'dealTitle': 'Northwind rollout',
        'stage': 'proposal',
        'firstConversation': false,
      });

      expect(brief.whereWeAre, 'Mid-proposal, waiting on budget sign-off.');
      expect(brief.theyCareAbout, ['onboarding time', 'price']);
      expect(brief.youPromised.length, 2);
      expect(brief.askAbout.length, 2);
      expect(brief.contactName, 'Priya Sharma');
      expect(brief.company, 'Northwind');
      expect(brief.firstConversation, isFalse);
    });

    test('openPromises puts not-done promises first', () {
      final brief = PrecallBrief.fromJson(const {
        'where_we_are': 'x',
        'they_care_about': [],
        'you_promised': [
          {'promise': 'Done thing', 'appears_done': true},
          {'promise': 'Undone thing', 'appears_done': false},
          {'promise': 'Another done', 'appears_done': true},
        ],
        'ask_about': [],
        'contactName': 'Sam',
        'dealTitle': 'Deal',
        'stage': 'new',
        'firstConversation': false,
      });

      expect(brief.openPromises.first.promise, 'Undone thing');
      expect(brief.openPromises.first.appearsDone, isFalse);
      expect(brief.openPromises.last.appearsDone, isTrue);
    });

    test('tolerates a first-conversation brief with empty lists', () {
      final brief = PrecallBrief.fromJson(const {
        'where_we_are': 'First conversation — nothing on file.',
        'contactName': 'New Person',
        'dealTitle': 'New deal',
        'stage': 'new',
        'firstConversation': true,
      });

      expect(brief.firstConversation, isTrue);
      expect(brief.theyCareAbout, isEmpty);
      expect(brief.youPromised, isEmpty);
      expect(brief.askAbout, isEmpty);
      expect(brief.company, isNull);
    });
  });
}
