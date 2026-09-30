import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/models/precall_brief.dart';
import 'package:ringly_mobile/features/deal_detail/widgets/precall_brief_sheet.dart';
import 'package:ringly_mobile/providers/deal_providers.dart';

Future<void> _open(WidgetTester tester, PrecallBrief brief) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        precallBriefProvider('d1').overrideWith((ref) async => brief),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPrecallBrief(context, 'd1'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

PrecallBrief _brief({bool firstConversation = false}) => PrecallBrief(
      whereWeAre: 'Mid-proposal, waiting on budget sign-off.',
      theyCareAbout: const ['onboarding time', 'price'],
      youPromised: const [
        Promise(promise: 'Send revised proposal', appearsDone: false),
        Promise(promise: 'Share case study', appearsDone: true),
      ],
      askAbout: const ['When can they start?', 'Who signs off?'],
      contactName: 'Priya Sharma',
      company: 'Northwind',
      dealTitle: 'Northwind rollout',
      stage: 'proposal',
      firstConversation: firstConversation,
    );

void main() {
  testWidgets('renders every section from the overridden provider', (tester) async {
    await _open(tester, _brief());

    expect(find.text('Priya Sharma · Northwind'), findsOneWidget);
    expect(find.text('Pre-call brief · Nemotron Super'), findsOneWidget);
    expect(find.text('Where we are'), findsOneWidget);
    expect(find.textContaining('waiting on budget'), findsOneWidget);
    expect(find.text('They care about'), findsOneWidget);
    expect(find.textContaining('onboarding time'), findsOneWidget);
    expect(find.text('You promised'), findsOneWidget);
    expect(find.text('Not done yet'), findsOneWidget);
    expect(find.text('Ask about'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Who signs off?'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Who signs off?'), findsOneWidget);
  });

  testWidgets('shows the first-conversation banner', (tester) async {
    await _open(tester, _brief(firstConversation: true));
    expect(find.text('First conversation — nothing on file yet.'), findsOneWidget);
  });
}
