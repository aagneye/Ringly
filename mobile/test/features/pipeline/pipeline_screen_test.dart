import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/models/deal.dart';
import 'package:ringly_mobile/features/pipeline/pipeline_screen.dart';
import 'package:ringly_mobile/providers/data_providers.dart';

BoardDeal _deal(
  String id, {
  required String stage,
  int urgency = 0,
  int daysSinceContact = 12,
}) {
  return BoardDeal(
    id: id,
    title: 'Deal $id',
    stage: stage,
    contactId: 'c$id',
    contactName: 'Contact $id',
    company: 'Northwind',
    nextAction: 'Follow up',
    deadline: null,
    budget: null,
    sentiment: null,
    lastContactAt: DateTime(2026, 9, 20),
    health: 50,
    signals: urgency == 0
        ? const []
        : [
            DriftSignal(
              dealId: id,
              reason: 'gone_quiet',
              urgency: urgency,
              explanation: 'No contact for $daysSinceContact days',
              daysSinceContact: daysSinceContact,
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
    columns: [for (final e in byStage.entries) BoardColumn(stage: e.key, deals: e.value)],
    total: deals.length,
  );
}

Future<void> _pump(WidgetTester tester, Board board) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [boardProvider.overrideWith((ref) async => board)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: PipelineScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders stage groups with counts', (tester) async {
    await _pump(
      tester,
      _board([
        _deal('1', stage: 'proposal', urgency: 80),
        _deal('2', stage: 'proposal'),
        _deal('3', stage: 'new'),
      ]),
    );

    expect(find.text('Pipeline'), findsOneWidget);
    expect(find.text('3 open deals'), findsOneWidget);
    expect(find.text('Proposal · 2'), findsOneWidget);
    expect(find.text('New · 1'), findsOneWidget);
  });

  testWidgets('the Going quiet filter hides non-quiet deals', (tester) async {
    await _pump(
      tester,
      _board([
        _deal('quiet', stage: 'proposal', urgency: 80),
        _deal('calm', stage: 'new'),
      ]),
    );

    // Both stages visible under All.
    expect(find.text('Deal quiet'), findsOneWidget);
    expect(find.text('Deal calm'), findsOneWidget);

    await tester.tap(find.text('Going quiet'));
    await tester.pump();

    expect(find.text('Deal quiet'), findsOneWidget);
    expect(find.text('Deal calm'), findsNothing);
  });

  testWidgets('shows the empty state on an empty board', (tester) async {
    await _pump(tester, const Board(columns: [], total: 0));
    expect(find.textContaining('No deals yet'), findsOneWidget);
  });
}
