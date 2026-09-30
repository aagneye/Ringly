import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/models/deal_detail.dart';

void main() {
  group('DealDetail.fromJson', () {
    test('parses a full payload', () {
      final detail = DealDetail.fromJson(const {
        'deal': {
          'id': 'd1',
          'title': 'Northwind rollout',
          'stage': 'proposal',
          'nextAction': 'Send revised proposal',
          'deadline': '2026-10-05T00:00:00.000Z',
          'budget': '\$40k',
          'concerns': 'Onboarding time',
          'sentiment': 'positive',
          'lastContactAt': '2026-09-18T10:00:00.000Z',
          'createdAt': '2026-09-01T10:00:00.000Z',
          'contactId': 'c1',
          'contactName': 'Priya Sharma',
          'company': 'Northwind',
          'email': 'priya@northwind.test',
          'role': 'VP Ops',
          'summary': 'Warm lead',
        },
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
        'notes': [
          {
            'id': 'n1',
            'rawTranscript': 'She wants the proposal by Friday',
            'gist': 'Proposal due Friday',
            'createdAt': '2026-09-18T10:00:00.000Z',
            'durationSeconds': 45,
            'source': 'voice',
          },
        ],
        'drafts': [
          {
            'id': 'x1',
            'subject': 'Following up',
            'body': 'Hi Priya',
            'status': 'draft',
            'createdAt': '2026-09-19T10:00:00.000Z',
          },
        ],
        'reminders': [
          {
            'id': 'r1',
            'message': 'Send the proposal',
            'dueAt': '2026-09-20T09:00:00.000Z',
            'status': 'pending',
          },
        ],
        'events': [
          {
            'id': 'e1',
            'title': 'Call with Priya',
            'startsAt': '2026-09-21T11:00:00.000Z',
            'endsAt': '2026-09-21T11:30:00.000Z',
            'location': 'Zoom',
          },
        ],
        'actions': [
          {
            'id': 'a1',
            'tool': 'manual_stage_change',
            'status': 'applied',
            'source': 'manual',
            'summary': 'You moved this to Proposal',
            'createdAt': '2026-09-19T12:00:00.000Z',
          },
          {
            'id': 'a2',
            'tool': 'set_reminder',
            'status': 'applied',
            'source': 'memo',
            'summary': 'Reminder to send the proposal',
            'createdAt': '2026-09-18T10:05:00.000Z',
          },
        ],
        'facts': [
          {
            'fact': 'Raised a \$20M Series B',
            'sourceUrl': 'https://www.techcrunch.com/northwind',
          },
        ],
      });

      expect(detail.deal.title, 'Northwind rollout');
      expect(detail.deal.contactName, 'Priya Sharma');
      expect(detail.deal.email, 'priya@northwind.test');
      expect(detail.health, 42);
      expect(detail.topSignal?.daysSinceContact, 12);
      expect(detail.notes.single.display, 'Proposal due Friday');
      expect(detail.notes.single.durationSeconds, 45);
      expect(detail.pendingDraftCount, 1);
      expect(detail.reminders.single.message, 'Send the proposal');
      expect(detail.events.single.location, 'Zoom');
      expect(detail.actions.first.isManual, isTrue);
      expect(detail.actions[1].isManual, isFalse);
      expect(detail.facts.single.sourceHost, 'techcrunch.com');
    });

    test('tolerates a sparse payload with missing fields', () {
      final detail = DealDetail.fromJson(const {
        'deal': {
          'id': 'd2',
          'title': 'Bare deal',
          'contactId': 'c2',
          'contactName': 'Sam',
        },
      });

      expect(detail.deal.stage, 'new');
      expect(detail.deal.company, isNull);
      expect(detail.deal.deadline, isNull);
      expect(detail.health, 100);
      expect(detail.signals, isEmpty);
      expect(detail.notes, isEmpty);
      expect(detail.drafts, isEmpty);
      expect(detail.reminders, isEmpty);
      expect(detail.events, isEmpty);
      expect(detail.actions, isEmpty);
      expect(detail.facts, isEmpty);
      expect(detail.topSignal, isNull);
      expect(detail.pendingDraftCount, 0);
    });

    test('note display falls back to the raw transcript when gist is empty', () {
      final detail = DealDetail.fromJson(const {
        'deal': {'id': 'd3', 'title': 't', 'contactId': 'c', 'contactName': 'n'},
        'notes': [
          {'id': 'n1', 'rawTranscript': 'The raw words', 'gist': ''},
        ],
      });
      expect(detail.notes.single.display, 'The raw words');
    });
  });
}
