import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/features/memo/memo_result_screen.dart';
import 'package:ringly_mobile/features/memo/submission_controller.dart';

/// A synced memo whose resultJson has [applied] applied actions, an awaiting
/// draft, and a failed lookup — so the "did N things" copy and the Undo
/// buttons can be checked.
LocalMemo _syncedMemo() => LocalMemo(
      id: 'm1',
      createdAt: DateTime.utc(2026, 9, 30),
      status: MemoStatus.synced,
      transcript: 'Spoke to Priya',
      resultJson: {
        'noteId': 'n1',
        'transcript': 'Spoke to Priya',
        'transcriptionProvider': 'nemotron-omni',
        'extraction': {'gist': 'Priya wants pricing'},
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
              'summary': 'Reminder to send pricing',
              'created': {'reminderId': 'r1'},
            },
            {
              'tool': 'update_deal',
              'status': 'applied',
              'summary': 'Moved to proposal',
              'created': {'dealId': 'd1'},
            },
            {
              'tool': 'draft_email',
              'status': 'awaiting_approval',
              'summary': 'Drafted a follow-up',
              'created': {'draftId': 'x1'},
            },
          ],
        },
        'traces': {'traces': []},
      },
    );

LocalMemo _noActionMemo() => LocalMemo(
      id: 'm1',
      createdAt: DateTime.utc(2026, 9, 30),
      status: MemoStatus.synced,
      transcript: 'Just a musing',
      resultJson: {
        'noteId': 'n2',
        'transcript': 'Just a musing',
        'transcriptionProvider': 'client-text',
        'extraction': {'gist': 'nothing here'},
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
      },
    );

Future<void> _pump(WidgetTester tester, LocalMemo? memo) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        memoByIdProvider('m1').overrideWith((ref) async => memo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const MemoResultScreen(memoId: 'm1'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a synced memo shows what Ringly did and undoable actions only', (tester) async {
    await _pump(tester, _syncedMemo());

    // Two applied actions → "Ringly did 2 things".
    expect(find.text('Ringly did 2 things'), findsOneWidget);

    // Each action summary is shown.
    expect(find.text('Reminder to send pricing'), findsOneWidget);
    expect(find.text('Moved to proposal'), findsOneWidget);
    expect(find.text('Drafted a follow-up'), findsOneWidget);

    // Undo is offered for the reminder and the draft, but not the deal update.
    expect(find.widgetWithText(TextButton, 'Undo'), findsNWidgets(2));
  });

  testWidgets('a no-action memo shows "Nothing needed doing" and the reason', (tester) async {
    await _pump(tester, _noActionMemo());
    expect(find.text('Nothing needed doing'), findsOneWidget);
    expect(find.textContaining('Nothing actionable'), findsOneWidget);
  });

  testWidgets('a pending memo shows it is saved and offers a retry', (tester) async {
    final pending = LocalMemo(
      id: 'm1',
      createdAt: DateTime.utc(2026, 9, 30),
      status: MemoStatus.pending,
      transcript: 'Spoke to Priya',
    );
    await _pump(tester, pending);

    expect(find.text('Saved on your phone'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again now'), findsOneWidget);
  });

  testWidgets('a failed memo says Ringly could not process it', (tester) async {
    final failed = LocalMemo(
      id: 'm1',
      createdAt: DateTime.utc(2026, 9, 30),
      status: MemoStatus.failed,
      transcript: 'Spoke to Priya',
      lastError: 'That recording was too long.',
    );
    await _pump(tester, failed);

    expect(find.textContaining('couldn\'t process'), findsOneWidget);
    expect(find.text('That recording was too long.'), findsOneWidget);
  });
}
