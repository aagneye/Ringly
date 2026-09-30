import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/data/repositories/deal_detail_repository.dart';

import '../support/fake_adapter.dart';

void main() {
  group('DealDetailRepository', () {
    test('fetch requests the deal by id and parses it', () async {
      final adapter = FakeAdapter({
        'GET /api/deals/d1': (_) => const FakeResponse.ok({
              'deal': {
                'id': 'd1',
                'title': 'Northwind rollout',
                'stage': 'proposal',
                'contactId': 'c1',
                'contactName': 'Priya Sharma',
                'company': 'Northwind',
              },
              'health': 55,
              'signals': [],
              'notes': [],
              'drafts': [],
              'reminders': [],
              'events': [],
              'actions': [],
              'facts': [],
            }),
      });

      final detail = await DealDetailRepository(fakeClient(adapter)).fetch('d1');
      expect(detail.deal.title, 'Northwind rollout');
      expect(detail.health, 55);
      expect(adapter.requests.single.path, '/api/deals/d1');
    });

    test('fetchBrief hits the brief endpoint and parses it', () async {
      final adapter = FakeAdapter({
        'GET /api/deals/d1/brief': (_) => const FakeResponse.ok({
              'where_we_are': 'Mid-proposal.',
              'they_care_about': ['price'],
              'you_promised': [
                {'promise': 'Send proposal', 'appears_done': false},
              ],
              'ask_about': ['When to start?'],
              'contactName': 'Priya Sharma',
              'company': 'Northwind',
              'dealTitle': 'Northwind rollout',
              'stage': 'proposal',
              'firstConversation': false,
            }),
      });

      final brief = await DealDetailRepository(fakeClient(adapter)).fetchBrief('d1');
      expect(brief.whereWeAre, 'Mid-proposal.');
      expect(brief.openPromises.single.appearsDone, isFalse);
      expect(adapter.requests.single.path, '/api/deals/d1/brief');
    });

    test('encodes an id with special characters', () async {
      final adapter = FakeAdapter({
        'GET /api/deals/a%2Fb': (_) => const FakeResponse.ok({
              'deal': {'id': 'a/b', 'title': 't', 'contactId': 'c', 'contactName': 'n'},
            }),
      });

      await DealDetailRepository(fakeClient(adapter)).fetch('a/b');
      expect(adapter.requests.single.path, '/api/deals/a%2Fb');
    });

    test('maps a 404 to a RinglyApiException', () async {
      final adapter = FakeAdapter({
        'GET /api/deals/missing': (_) => const FakeResponse(404, {
              'error': 'That deal does not exist.',
              'code': 'deal_not_found',
            }),
      });

      expect(
        DealDetailRepository(fakeClient(adapter)).fetch('missing'),
        throwsA(isA<RinglyApiException>()),
      );
    });

    test('turns a dropped connection into NetworkException', () async {
      final adapter = FakeAdapter({'GET /api/deals/d1': offline});
      expect(
        DealDetailRepository(fakeClient(adapter)).fetch('d1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
