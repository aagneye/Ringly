import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/models/briefing.dart';
import 'package:ringly_mobile/data/models/deal.dart';
import 'package:ringly_mobile/data/models/health.dart';
import 'package:ringly_mobile/data/models/today.dart';
import 'package:ringly_mobile/data/models/usage.dart';
import 'package:ringly_mobile/features/home/widgets/ai_activity_section.dart';
import 'package:ringly_mobile/features/home/widgets/briefing_card.dart';
import 'package:ringly_mobile/features/home/widgets/integrations_section.dart';
import 'package:ringly_mobile/features/home/widgets/needs_you_card.dart';
import 'package:ringly_mobile/features/home/widgets/pipeline_pulse_section.dart';
import 'package:ringly_mobile/features/home/widgets/todays_calls_section.dart';
import 'package:ringly_mobile/providers/data_providers.dart';

Future<void> _pump(WidgetTester tester, Widget child, List overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides],
      retry: (_, _) => null,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

TodaySnapshot _today({int drafts = 0, int reminders = 0, int events = 0}) {
  final now = DateTime(2026, 9, 30, 10);
  return TodaySnapshot(
    now: now,
    drafts: [
      for (var i = 0; i < drafts; i++)
        PendingDraft(
          id: 'x$i',
          subject: 'Subject $i',
          body: 'Body',
          reasoning: null,
          createdAt: now,
          dealId: 'd1',
          dealTitle: 'Deal',
          contactName: 'Priya Sharma',
          contactEmail: 'priya@example.com',
        ),
    ],
    reminders: [
      for (var i = 0; i < reminders; i++)
        TodayReminder(
          id: 'r$i',
          message: 'Reminder $i',
          dueAt: now,
          createdBy: 'agent',
          dealId: 'd1',
          dealTitle: 'Deal',
          contactName: 'Priya Sharma',
        ),
    ],
    events: [
      for (var i = 0; i < events; i++)
        TodayEvent(
          id: 'e$i',
          title: 'Call $i',
          startsAt: DateTime(2026, 9, 30, 11, 30),
          endsAt: null,
          location: null,
          dealId: 'd1',
          contactName: 'Priya Sharma',
          company: 'Northwind',
        ),
    ],
  );
}

void main() {
  group('NeedsYouCard', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await _pump(tester, const NeedsYouCard(), [
        todayProvider.overrideWith((ref) => Completer<TodaySnapshot>().future),
      ]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows counts when things are waiting', (tester) async {
      await _pump(tester, const NeedsYouCard(), [
        todayProvider.overrideWith((ref) async => _today(drafts: 2, reminders: 1)),
      ]);
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('drafts to approve'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('collapses to a calm line when empty', (tester) async {
      await _pump(tester, const NeedsYouCard(), [
        todayProvider.overrideWith((ref) async => _today()),
      ]);
      await tester.pump();
      expect(find.textContaining('all caught up'), findsOneWidget);
    });

    testWidgets('explains a missing database instead of erroring', (tester) async {
      await _pump(tester, const NeedsYouCard(), [
        todayProvider.overrideWith(
          (ref) => Future.error(const DatabaseNotConfiguredException(message: 'x')),
        ),
      ]);
      await tester.pump();
      expect(find.textContaining('DATABASE_URL'), findsOneWidget);
    });

    testWidgets('explains an unreachable server', (tester) async {
      await _pump(tester, const NeedsYouCard(), [
        todayProvider.overrideWith((ref) => Future.error(const NetworkException('down'))),
      ]);
      await tester.pump();
      expect(find.textContaining('Can\'t reach'), findsOneWidget);
    });
  });

  group('TodaysCallsSection', () {
    testWidgets('lists calls with time and a Brief me button', (tester) async {
      await _pump(tester, const TodaysCallsSection(), [
        todayProvider.overrideWith((ref) async => _today(events: 1)),
      ]);
      await tester.pump();
      expect(find.text('Call 0'), findsOneWidget);
      expect(find.text('11:30'), findsOneWidget);
      expect(find.text('Brief me'), findsOneWidget);
    });

    testWidgets('says so when the calendar is empty', (tester) async {
      await _pump(tester, const TodaysCallsSection(), [
        todayProvider.overrideWith((ref) async => _today()),
      ]);
      await tester.pump();
      expect(find.textContaining('No calls'), findsOneWidget);
    });
  });

  group('BriefingCard', () {
    testWidgets('renders the headline and items', (tester) async {
      await _pump(tester, const BriefingCard(), [
        briefingProvider.overrideWith(
          (ref) async => const Briefing(
            headline: 'Two things today.',
            spokenText: 'Priya is waiting.',
            items: [
              BriefingItem(title: 'Proposal', detail: 'Due today', dealId: 'd1', kind: 'reminder'),
            ],
            cached: true,
            empty: false,
          ),
        ),
      ]);
      await tester.pump();
      expect(find.text('Two things today.'), findsOneWidget);
      expect(find.text('Proposal'), findsOneWidget);
      expect(find.text('Nemotron Ultra · today'), findsOneWidget);
    });
  });

  group('PipelinePulseSection', () {
    testWidgets('prompts for a first memo on an empty board', (tester) async {
      await _pump(tester, const PipelinePulseSection(), [
        boardProvider.overrideWith((ref) async => const Board(columns: [], total: 0)),
      ]);
      await tester.pump();
      expect(find.textContaining('No deals yet'), findsOneWidget);
    });

    testWidgets('lists quiet deals with their explanation', (tester) async {
      const deal = BoardDeal(
        id: 'd1',
        title: 'Rollout',
        stage: 'proposal',
        contactId: 'c1',
        contactName: 'Priya',
        company: 'Northwind',
        nextAction: null,
        deadline: null,
        budget: null,
        sentiment: null,
        lastContactAt: null,
        health: 40,
        signals: [
          DriftSignal(
            dealId: 'd1',
            reason: 'gone_quiet',
            urgency: 80,
            explanation: 'No contact for 12 days',
            daysSinceContact: 12,
            daysUntilDeadline: null,
          ),
        ],
        noteCount: 1,
        pendingDraftCount: 0,
      );
      await _pump(tester, const PipelinePulseSection(), [
        boardProvider.overrideWith(
          (ref) async => const Board(
            columns: [BoardColumn(stage: 'proposal', deals: [deal])],
            total: 1,
          ),
        ),
      ]);
      await tester.pump();
      expect(find.text('1 open deals'), findsOneWidget);
      expect(find.textContaining('No contact for 12 days'), findsOneWidget);
    });
  });

  group('AiActivitySection', () {
    testWidgets('shows per-tier call counts', (tester) async {
      await _pump(tester, const AiActivitySection(), [
        usageProvider.overrideWith(
          (ref) async => const UsageSummary(
            tiers: [
              TierUsage(
                tier: 'FAST',
                model: 'm',
                label: 'Lightning',
                rationale: '',
                calls: 12,
                promptTokens: 900,
                completionTokens: 300,
                avgLatencyMs: 200,
                failures: 0,
              ),
            ],
            recent: [],
            totalCalls: 12,
            totalPromptTokens: 900,
            totalCompletionTokens: 300,
          ),
        ),
      ]);
      await tester.pump();
      expect(find.textContaining('12 Nemotron calls'), findsOneWidget);
      expect(find.textContaining('1.2k tokens'), findsOneWidget);
    });
  });

  group('integrationsFor', () {
    test('email and calendar are always available', () {
      const health = HealthStatus(ok: true, nebius: false, database: false, tavily: false);
      final rows = integrationsFor(health);
      expect(rows.firstWhere((r) => r.name == 'Email').connected, isTrue);
      expect(rows.firstWhere((r) => r.name == 'Calendar').connected, isTrue);
      expect(rows.firstWhere((r) => r.name == 'Nemotron on Nebius').connected, isFalse);
      expect(rows.firstWhere((r) => r.name == 'Contacts').connected, isFalse);
    });
  });
}
