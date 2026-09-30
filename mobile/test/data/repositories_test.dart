import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/data/repositories/briefing_repository.dart';
import 'package:ringly_mobile/data/repositories/deals_repository.dart';
import 'package:ringly_mobile/data/repositories/health_repository.dart';
import 'package:ringly_mobile/data/repositories/today_repository.dart';
import 'package:ringly_mobile/data/repositories/usage_repository.dart';

import '../support/fake_adapter.dart';

void main() {
  group('HealthRepository', () {
    test('parses the configured flags', () async {
      final adapter = FakeAdapter({
        'GET /api/health': (_) => const FakeResponse.ok(
              {'ok': true, 'nebius': true, 'database': false, 'tavily': true},
            ),
      });
      final health = await HealthRepository(fakeClient(adapter)).fetch();
      expect(health.nebius, isTrue);
      expect(health.database, isFalse);
      expect(health.canProcessMemos, isFalse);
    });

    test('turns a dropped connection into NetworkException', () async {
      final adapter = FakeAdapter({'GET /api/health': offline});
      expect(
        HealthRepository(fakeClient(adapter)).fetch(),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('TodayRepository', () {
    test('parses reminders, events and drafts', () async {
      final adapter = FakeAdapter({
        'GET /api/today': (_) => const FakeResponse.ok({
              'reminders': [
                {
                  'id': 'r1',
                  'message': 'Send the proposal',
                  'dueAt': '2026-09-30T09:00:00.000Z',
                  'createdBy': 'agent',
                  'dealId': 'd1',
                  'dealTitle': 'Northwind rollout',
                  'contactName': 'Priya Sharma',
                },
              ],
              'events': [
                {
                  'id': 'e1',
                  'title': 'Call with Priya',
                  'startsAt': '2026-09-30T11:00:00.000Z',
                  'endsAt': null,
                  'location': null,
                  'dealId': 'd1',
                  'contactName': 'Priya Sharma',
                  'company': 'Northwind',
                },
              ],
              'drafts': [
                {
                  'id': 'x1',
                  'subject': 'Following up',
                  'body': 'Hi Priya',
                  'reasoning': null,
                  'createdAt': '2026-09-30T08:00:00.000Z',
                  'dealId': 'd1',
                  'dealTitle': 'Northwind rollout',
                  'contactName': 'Priya Sharma',
                  'contactEmail': 'priya@northwind.test',
                },
              ],
              'now': '2026-09-30T10:00:00.000Z',
            }),
      });
      final today = await TodayRepository(fakeClient(adapter)).fetch();
      expect(today.reminders.single.message, 'Send the proposal');
      expect(today.events.single.company, 'Northwind');
      expect(today.drafts.single.contactEmail, 'priya@northwind.test');
      expect(today.pendingActionCount, 2);
    });

    test('maps database_not_configured to its typed exception', () async {
      final adapter = FakeAdapter({
        'GET /api/today': (_) => const FakeResponse(503, {
              'error': 'DATABASE_URL is not set.',
              'code': 'database_not_configured',
            }),
      });
      expect(
        TodayRepository(fakeClient(adapter)).fetch(),
        throwsA(isA<DatabaseNotConfiguredException>()),
      );
    });
  });

  group('DealsRepository', () {
    test('parses board columns and drift signals', () async {
      final adapter = FakeAdapter({
        'GET /api/deals': (_) => const FakeResponse.ok({
              'columns': [
                {
                  'stage': 'proposal',
                  'deals': [
                    {
                      'id': 'd1',
                      'title': 'Northwind rollout',
                      'stage': 'proposal',
                      'contactId': 'c1',
                      'contactName': 'Priya Sharma',
                      'company': 'Northwind',
                      'health': 42,
                      'signals': [
                        {
                          'dealId': 'd1',
                          'reason': 'gone_quiet',
                          'urgency': 70,
                          'explanation': 'No contact for 12 days',
                          'daysSinceContact': 12,
                          'daysUntilDeadline': null,
                        },
                      ],
                      'noteCount': 3,
                      'pendingDraftCount': 1,
                    },
                  ],
                },
                {'stage': 'won', 'deals': []},
              ],
              'total': 1,
            }),
      });
      final board = await DealsRepository(fakeClient(adapter)).fetchBoard();
      expect(board.total, 1);
      expect(board.countFor('proposal'), 1);
      expect(board.quietDeals.single.topSignal?.daysSinceContact, 12);
    });

    test('updateStage PATCHes the new stage', () async {
      final adapter = FakeAdapter({
        'PATCH /api/deals/d1': (_) => const FakeResponse.ok({'ok': true}),
      });
      await DealsRepository(fakeClient(adapter)).updateStage('d1', 'won');
      expect(adapter.requests.single.data, {'stage': 'won'});
    });
  });

  group('UsageRepository', () {
    test('parses tiers and totals', () async {
      final adapter = FakeAdapter({
        'GET /api/usage': (_) => const FakeResponse.ok({
              'tiers': [
                {
                  'tier': 'FAST',
                  'model': 'nvidia/Nemotron-3_5-Lightning',
                  'calls': 40,
                  'promptTokens': 1000,
                  'completionTokens': 200,
                  'avgLatencyMs': 350,
                  'failures': 0,
                  'label': 'Nemotron 3.5 Lightning',
                  'rationale': 'Schema-constrained extraction',
                },
              ],
              'recent': [],
              'actionCounts': [],
              'totals': {'calls': 40, 'promptTokens': 1000, 'completionTokens': 200},
            }),
      });
      final usage = await UsageRepository(fakeClient(adapter)).fetch();
      expect(usage.callsFor('FAST'), 40);
      expect(usage.callsFor('REASONING'), 0);
      expect(usage.totalTokens, 1200);
    });
  });

  group('BriefingRepository', () {
    test('sends force=1 only when forced', () async {
      final adapter = FakeAdapter({
        'GET /api/briefing': (_) => const FakeResponse.ok({
              'headline': 'Two things today.',
              'spokenText': 'Priya is waiting on the proposal.',
              'items': [
                {'title': 'Proposal', 'detail': 'Due today', 'deal_id': 'd1', 'kind': 'reminder'},
              ],
              'cached': false,
              'empty': false,
              'runId': 'run1',
            }),
      });
      final repo = BriefingRepository(fakeClient(adapter));

      final briefing = await repo.fetch();
      expect(briefing.items.single.dealId, 'd1');
      expect(adapter.requests.last.queryParameters, isEmpty);

      await repo.fetch(force: true);
      expect(adapter.requests.last.queryParameters, {'force': '1'});
    });
  });
}
