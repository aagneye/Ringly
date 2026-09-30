import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/models/deal.dart';
import 'package:ringly_mobile/data/models/deal_detail.dart';
import 'package:ringly_mobile/features/deal_detail/deal_detail_screen.dart';
import 'package:ringly_mobile/providers/deal_providers.dart';

DealDetail _detail() => DealDetail(
      deal: const DealInfo(
        id: 'd1',
        title: 'Northwind rollout',
        stage: 'proposal',
        nextAction: 'Send revised proposal',
        deadline: null,
        budget: r'$40k',
        concerns: 'Onboarding time',
        sentiment: 'positive',
        lastContactAt: null,
        createdAt: null,
        contactId: 'c1',
        contactName: 'Priya Sharma',
        company: 'Northwind',
        email: 'priya@northwind.test',
        role: 'VP Ops',
        summary: null,
      ),
      health: 42,
      signals: const [
        DriftSignal(
          dealId: 'd1',
          reason: 'gone_quiet',
          urgency: 70,
          explanation: 'No contact for 12 days',
          daysSinceContact: 12,
          daysUntilDeadline: null,
        ),
      ],
      notes: [
        DealNote(
          id: 'n1',
          rawTranscript: 'She wants it by Friday',
          gist: 'Proposal due Friday',
          createdAt: DateTime(2026, 9, 18, 10),
          durationSeconds: 45,
          source: 'voice',
        ),
      ],
      drafts: [
        DealDraft(
          id: 'x1',
          subject: 'Following up',
          body: 'Hi Priya',
          status: 'draft',
          createdAt: DateTime(2026, 9, 19),
        ),
      ],
      reminders: const [],
      events: const [],
      actions: [
        DealAction(
          id: 'a1',
          tool: 'manual_stage_change',
          status: 'applied',
          source: 'manual',
          summary: 'You moved this to Proposal',
          createdAt: DateTime(2026, 9, 19, 12),
        ),
      ],
      facts: const [
        CompanyFact(
          fact: 'Raised a Series B',
          sourceUrl: 'https://www.techcrunch.com/northwind',
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, DealDetail detail) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dealDetailProvider('d1').overrideWith((ref) async => detail),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const DealDetailScreen(dealId: 'd1'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the header, brief button and timeline', (tester) async {
    await _pump(tester, _detail());

    expect(find.text('Northwind rollout'), findsWidgets); // app bar + possibly timeline
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('priya@northwind.test'), findsOneWidget);
    expect(find.text('Brief me'), findsOneWidget);
    expect(find.text('Send revised proposal'), findsOneWidget);
    expect(find.textContaining('No contact for 12 days'), findsWidgets);
  });

  testWidgets('shows company facts with a source host', (tester) async {
    await _pump(tester, _detail());
    await tester.scrollUntilVisible(find.text('Company facts'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Company facts'), findsOneWidget);
    expect(find.text('Raised a Series B'), findsOneWidget);
    expect(find.text('techcrunch.com'), findsOneWidget);
  });

  testWidgets('merges notes and actions into the timeline', (tester) async {
    await _pump(tester, _detail());
    await tester.scrollUntilVisible(find.text('Proposal due Friday'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Proposal due Friday'), findsOneWidget);
    expect(find.text('You moved this to Proposal'), findsOneWidget);
  });

  testWidgets('links to a pending draft', (tester) async {
    await _pump(tester, _detail());
    await tester.scrollUntilVisible(find.text('1 draft waiting for you'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('1 draft waiting for you'), findsOneWidget);
  });
}
