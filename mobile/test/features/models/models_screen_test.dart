import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/models/usage.dart';
import 'package:ringly_mobile/features/models/models_screen.dart';
import 'package:ringly_mobile/providers/data_providers.dart';

TierUsage _tier(String tier, {required int calls, int promptTokens = 0, int completionTokens = 0, int avgLatencyMs = 0, int failures = 0}) =>
    TierUsage(
      tier: tier,
      model: 'm',
      label: tier,
      rationale: '',
      calls: calls,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      avgLatencyMs: avgLatencyMs,
      failures: failures,
    );

Future<void> _pump(WidgetTester tester, List<Object> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides.cast()],
      retry: (_, _) => null,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ModelsScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ModelsScreen', () {
    testWidgets('renders all four tiers from the static catalogue without data',
        (tester) async {
      await _pump(tester, [
        usageProvider.overrideWith((ref) => Future.error(const NetworkException('down'))),
      ]);
      await tester.pump();

      // Lightning and Super are above the fold.
      expect(find.text('Lightning'), findsOneWidget);
      expect(find.text('nvidia/Nemotron-3_5-Lightning'), findsOneWidget);

      // Ultra and Omni are further down — scroll to them.
      await tester.scrollUntilVisible(find.text('Ultra'), 200);
      expect(find.text('Ultra'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Omni'), 200);
      expect(find.text('Omni'), findsOneWidget);
    });

    testWidgets('error state still shows the catalogue plus a notice', (tester) async {
      await _pump(tester, [
        usageProvider.overrideWith((ref) => Future.error(const NetworkException('down'))),
      ]);
      await tester.pump();

      expect(find.text('Lightning'), findsOneWidget);
      expect(find.textContaining('Can\'t reach'), findsOneWidget);
      // Stats fall back to dashes.
      expect(find.text('— calls'), findsWidgets);
    });

    testWidgets('merges two FAST rows into a single per-tier count', (tester) async {
      await _pump(tester, [
        usageProvider.overrideWith(
          (ref) async => UsageSummary(
            tiers: [
              _tier('FAST', calls: 7, promptTokens: 500, completionTokens: 100),
              _tier('FAST', calls: 5, promptTokens: 300, completionTokens: 100),
              _tier('BALANCED', calls: 3),
            ],
            recent: const [],
            totalCalls: 15,
            totalPromptTokens: 800,
            totalCompletionTokens: 200,
          ),
        ),
      ]);
      await tester.pump();

      // 7 + 5 = 12 FAST calls shown as one pill.
      expect(find.text('12 calls'), findsOneWidget);
      expect(find.text('3 calls'), findsOneWidget);
      // Totals card.
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('zero usage shows 0 calls, not a dash', (tester) async {
      await _pump(tester, [
        usageProvider.overrideWith(
          (ref) async => const UsageSummary(
            tiers: [],
            recent: [],
            totalCalls: 0,
            totalPromptTokens: 0,
            totalCompletionTokens: 0,
          ),
        ),
      ]);
      await tester.pump();

      // Two tiers are above the fold showing 0 calls.
      expect(find.text('0 calls'), findsWidgets);
      // Scroll down and the lower tiers also show 0, not a dash.
      await tester.scrollUntilVisible(find.text('Omni'), 200);
      expect(find.text('— calls'), findsNothing);
    });
  });
}
