import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/models/deal.dart';
import 'package:ringly_mobile/features/pipeline/pipeline_grouping.dart';

BoardDeal _deal(
  String id, {
  required String stage,
  int urgency = 0,
  DateTime? lastContactAt,
}) {
  return BoardDeal(
    id: id,
    title: 'Deal $id',
    stage: stage,
    contactId: 'c$id',
    contactName: 'Contact $id',
    company: 'Co',
    nextAction: null,
    deadline: null,
    budget: null,
    sentiment: null,
    lastContactAt: lastContactAt,
    health: 50,
    signals: urgency == 0
        ? const []
        : [
            DriftSignal(
              dealId: id,
              reason: 'gone_quiet',
              urgency: urgency,
              explanation: 'Quiet',
              daysSinceContact: 10,
              daysUntilDeadline: null,
            ),
          ],
    noteCount: 0,
    pendingDraftCount: 0,
  );
}

Board _board(List<BoardDeal> deals) {
  final byStage = <String, List<BoardDeal>>{};
  for (final deal in deals) {
    byStage.putIfAbsent(deal.stage, () => []).add(deal);
  }
  return Board(
    columns: [for (final entry in byStage.entries) BoardColumn(stage: entry.key, deals: entry.value)],
    total: deals.length,
  );
}

void main() {
  group('groupForPipeline', () {
    test('returns open stages in board order and drops empty ones', () {
      final board = _board([
        _deal('1', stage: 'proposal'),
        _deal('2', stage: 'new'),
      ]);
      final groups = groupForPipeline(board);
      expect(groups.map((g) => g.stage), ['new', 'proposal']);
    });

    test('hides won and lost unless showClosed is true', () {
      final board = _board([
        _deal('1', stage: 'new'),
        _deal('2', stage: 'won'),
        _deal('3', stage: 'lost'),
      ]);

      expect(groupForPipeline(board).map((g) => g.stage), ['new']);
      expect(
        groupForPipeline(board, showClosed: true).map((g) => g.stage),
        ['new', 'won', 'lost'],
      );
    });

    test('sorts quiet deals first, most urgent first', () {
      final board = _board([
        _deal('calm', stage: 'proposal', lastContactAt: DateTime(2026, 9, 20)),
        _deal('urgent', stage: 'proposal', urgency: 90),
        _deal('mild', stage: 'proposal', urgency: 40),
      ]);
      final proposal = groupForPipeline(board).single;
      expect(proposal.deals.map((d) => d.id), ['urgent', 'mild', 'calm']);
    });

    test('among non-quiet deals, most recent contact comes first', () {
      final board = _board([
        _deal('old', stage: 'new', lastContactAt: DateTime(2026, 9, 1)),
        _deal('recent', stage: 'new', lastContactAt: DateTime(2026, 9, 25)),
      ]);
      final group = groupForPipeline(board).single;
      expect(group.deals.map((d) => d.id), ['recent', 'old']);
    });

    test('group label and count are set', () {
      final board = _board([
        _deal('1', stage: 'proposal'),
        _deal('2', stage: 'proposal'),
      ]);
      final group = groupForPipeline(board).single;
      expect(group.label, 'Proposal');
      expect(group.count, 2);
    });
  });

  group('totalOpen', () {
    test('counts only open deals', () {
      final board = _board([
        _deal('1', stage: 'new'),
        _deal('2', stage: 'proposal'),
        _deal('3', stage: 'won'),
        _deal('4', stage: 'lost'),
      ]);
      expect(totalOpen(board), 2);
    });
  });
}
