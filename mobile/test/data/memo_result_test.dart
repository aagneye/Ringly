import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/models/memo_result.dart';

/// A full /api/notes response with three actions (one applied, one awaiting
/// approval, one failed), traces, and every extraction field set.
Map<String, dynamic> _fullResponse() => {
      'noteId': 'n1',
      'transcript': 'Spoke to Priya at Northwind about the rollout.',
      'transcriptionProvider': 'nemotron-omni',
      'extraction': {
        'gist': 'Priya is happy but wants pricing by Friday.',
        'contact_name': 'Priya Sharma',
        'company': 'Northwind',
        'stage_guess': 'proposal',
        'next_action': 'Send pricing',
        'deadline': 'Friday',
        'budget': '\$40k',
        'concerns': 'Timeline',
        'sentiment': 'positive',
      },
      'target': {
        'contactId': 'c1',
        'contactName': 'Priya Sharma',
        'company': 'Northwind',
        'dealId': 'd1',
        'dealTitle': 'Northwind rollout',
        'stage': 'proposal',
        'matchConfidence': 'exact',
        'createdContact': false,
        'createdDeal': false,
      },
      'report': {
        'actions': [
          {
            'tool': 'set_reminder',
            'status': 'applied',
            'summary': 'Reminder to send pricing on Friday',
            'created': {'reminderId': 'r1'},
          },
          {
            'tool': 'draft_email',
            'status': 'awaiting_approval',
            'summary': 'Drafted a follow-up to Priya',
            'created': {'draftId': 'x1'},
          },
          {
            'tool': 'lookup_company',
            'status': 'failed',
            'summary': 'Look up Northwind',
            'error': 'Tavily unavailable',
          },
        ],
      },
      'traces': {
        'traces': [
          {'task': 'extract', 'tier': 'FAST', 'latencyMs': 320},
          {'task': 'plan', 'tier': 'BALANCED', 'latencyMs': 1400},
        ],
      },
      'noActionReason': null,
    };

void main() {
  group('MemoResult.fromJson', () {
    test('parses the whole story of a memo', () {
      final result = MemoResult.fromJson(_fullResponse());

      expect(result.noteId, 'n1');
      expect(result.transcript, startsWith('Spoke to Priya'));
      expect(result.transcriptionProvider, 'nemotron-omni');
      expect(result.noActionReason, isNull);

      // Extraction fields.
      expect(result.extraction.gist, contains('pricing by Friday'));
      expect(result.extraction.contactName, 'Priya Sharma');
      expect(result.extraction.company, 'Northwind');
      expect(result.extraction.sentiment, 'positive');

      // Target.
      expect(result.target.contactId, 'c1');
      expect(result.target.dealTitle, 'Northwind rollout');
      expect(result.target.matchConfidence, 'exact');
      expect(result.target.isUncertain, isFalse);

      // Actions, in order, with statuses and created ids.
      expect(result.actions, hasLength(3));
      expect(result.actions[0].isApplied, isTrue);
      expect(result.actions[0].reminderId, 'r1');
      expect(result.actions[1].awaitsApproval, isTrue);
      expect(result.actions[1].draftId, 'x1');
      expect(result.actions[2].failed, isTrue);
      expect(result.actions[2].error, 'Tavily unavailable');

      // Traces.
      expect(result.traces, hasLength(2));
      expect(result.traces.first.task, 'extract');
      expect(result.traces.first.tier, 'FAST');
      expect(result.traces.first.latencyMs, 320);
    });

    test('keeps the raw response verbatim for on-device storage', () {
      final json = _fullResponse();
      final result = MemoResult.fromJson(json);
      expect(result.raw, same(json));
      expect(result.raw['noteId'], 'n1');
    });

    test('tookNoAction is true and reason is kept when nothing was done', () {
      final result = MemoResult.fromJson({
        'noteId': 'n2',
        'transcript': 'Just thinking out loud.',
        'transcriptionProvider': 'client-text',
        'extraction': {'gist': 'A musing'},
        'target': {
          'contactId': 'c1',
          'contactName': 'Priya',
          'dealId': 'd1',
          'dealTitle': 'Deal',
          'stage': 'lead',
          'createdContact': false,
          'createdDeal': false,
        },
        'report': {'actions': []},
        'traces': {'traces': []},
        'noActionReason': 'Nothing actionable in this memo.',
      });

      expect(result.tookNoAction, isTrue);
      expect(result.awaitingApprovalCount, 0);
      expect(result.noActionReason, 'Nothing actionable in this memo.');
    });

    test('awaitingApprovalCount counts only awaiting_approval actions', () {
      final result = MemoResult.fromJson(_fullResponse());
      expect(result.awaitingApprovalCount, 1);
    });
  });

  group('MemoExtraction.fields', () {
    test('are labelled and returned in reading order, skipping nulls', () {
      const extraction = MemoExtraction(
        gist: 'g',
        contactName: 'Priya',
        stageGuess: 'proposal',
        deadline: 'Friday',
      );
      expect(extraction.fields, [
        ('Who', 'Priya'),
        ('Stage', 'proposal'),
        ('Deadline', 'Friday'),
      ]);
    });

    test('is empty when nothing but the gist was extracted', () {
      const extraction = MemoExtraction(gist: 'g');
      expect(extraction.fields, isEmpty);
    });
  });

  group('MemoTarget.isUncertain', () {
    test('is true for fuzzy and new matches', () {
      expect(_targetWith('fuzzy').isUncertain, isTrue);
      expect(_targetWith('new').isUncertain, isTrue);
    });

    test('is false for exact and company matches', () {
      expect(_targetWith('exact').isUncertain, isFalse);
      expect(_targetWith('company').isUncertain, isFalse);
    });

    test('defaults matchConfidence to new when the server omits it', () {
      final target = MemoTarget.fromJson({
        'contactId': 'c1',
        'contactName': 'Priya',
        'dealId': 'd1',
        'dealTitle': 'Deal',
        'stage': 'lead',
        'createdContact': true,
        'createdDeal': true,
      });
      expect(target.matchConfidence, 'new');
      expect(target.isUncertain, isTrue);
    });
  });
}

MemoTarget _targetWith(String confidence) => MemoTarget(
      contactId: 'c1',
      contactName: 'Priya',
      company: 'Northwind',
      dealId: 'd1',
      dealTitle: 'Deal',
      stage: 'proposal',
      matchConfidence: confidence,
      createdContact: false,
      createdDeal: false,
    );
