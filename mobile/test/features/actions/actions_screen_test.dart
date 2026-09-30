import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/models/today.dart';
import 'package:ringly_mobile/features/actions/actions_controller.dart';
import 'package:ringly_mobile/features/actions/actions_screen.dart';
import 'package:ringly_mobile/providers/api_providers.dart';
import 'package:ringly_mobile/providers/data_providers.dart';

import '../../support/fake_adapter.dart';

TodaySnapshot _snapshot({int drafts = 0, int reminders = 0}) {
  final now = DateTime(2026, 9, 30, 10);
  return TodaySnapshot(
    now: now,
    events: const [],
    drafts: [
      for (var i = 0; i < drafts; i++)
        PendingDraft(
          id: 'draft$i',
          subject: 'Original subject $i',
          body: 'Original body $i',
          reasoning: 'the deal went quiet',
          createdAt: now,
          dealId: 'd1',
          dealTitle: 'Rollout',
          contactName: 'Priya Sharma',
          contactEmail: 'priya@example.com',
        ),
    ],
    reminders: [
      for (var i = 0; i < reminders; i++)
        TodayReminder(
          id: 'rem$i',
          message: 'Send the proposal $i',
          dueAt: now,
          createdBy: 'agent',
          dealId: 'd1',
          dealTitle: 'Rollout',
          contactName: 'Priya Sharma',
        ),
    ],
  );
}

/// A launcher that records every URI it was asked to open and returns [result].
class RecordingLauncher {
  RecordingLauncher(this.result);
  final bool result;
  final List<Uri> opened = [];

  Future<bool> call(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required List<Object> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides.cast()],
      retry: (_, _) => null,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ActionsScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ActionsScreen', () {
    testWidgets('renders drafts and reminders from todayProvider', (tester) async {
      await _pump(tester, overrides: [
        todayProvider.overrideWith((ref) async => _snapshot(drafts: 1, reminders: 1)),
      ]);

      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Emails to approve (1)'), findsOneWidget);
      expect(find.text('Original subject 0'), findsOneWidget);
      expect(find.text('Reminders due (1)'), findsOneWidget);
      expect(find.text('Send the proposal 0'), findsOneWidget);
    });

    testWidgets('shows the caught-up empty state when nothing waits', (tester) async {
      await _pump(tester, overrides: [
        todayProvider.overrideWith((ref) async => _snapshot()),
      ]);
      expect(find.textContaining('all caught up'), findsOneWidget);
    });

    testWidgets('approve launches mail with the draft subject then POSTs approve',
        (tester) async {
      final launcher = RecordingLauncher(true);
      final adapter = FakeAdapter({
        'POST /api/drafts/draft0': (o) => const FakeResponse.ok({'ok': true}),
        'GET /api/today': (o) => FakeResponse.ok({
              'reminders': [],
              'events': [],
              'drafts': [],
              'now': '2026-09-30T10:00:00.000Z',
            }),
      });

      await _pump(tester, overrides: [
        apiClientProvider.overrideWithValue(fakeClient(adapter)),
        mailLauncherProvider.overrideWithValue(launcher.call),
        todayProvider.overrideWith((ref) async => _snapshot(drafts: 1)),
      ]);

      await tester.tap(find.text('Approve & open mail'));
      await tester.pumpAndSettle();

      // Launched a mailto with the draft's subject.
      expect(launcher.opened, hasLength(1));
      final uri = launcher.opened.single;
      expect(uri.scheme, 'mailto');
      expect(uri.toString(), contains('subject=Original%20subject%200'));

      // Posted approve to the server.
      final approve = adapter.requests
          .where((r) => r.method == 'POST' && r.path == '/api/drafts/draft0')
          .toList();
      expect(approve, hasLength(1));
      expect((approve.single.data as Map)['action'], 'approve');
    });

    testWidgets('when the launcher fails, no approve request is sent', (tester) async {
      final launcher = RecordingLauncher(false);
      final adapter = FakeAdapter({
        'POST /api/drafts/draft0': (o) => const FakeResponse.ok({'ok': true}),
        'GET /api/today': (o) => FakeResponse.ok({
              'reminders': [],
              'events': [],
              'drafts': [],
              'now': '2026-09-30T10:00:00.000Z',
            }),
      });

      await _pump(tester, overrides: [
        apiClientProvider.overrideWithValue(fakeClient(adapter)),
        mailLauncherProvider.overrideWithValue(launcher.call),
        todayProvider.overrideWith((ref) async => _snapshot(drafts: 1)),
      ]);

      await tester.tap(find.text('Approve & open mail'));
      await tester.pump();
      await tester.pump();

      expect(launcher.opened, hasLength(1));
      final approve = adapter.requests
          .where((r) => r.method == 'POST' && r.path == '/api/drafts/draft0')
          .toList();
      expect(approve, isEmpty);
      // The draft stays on screen.
      expect(find.text('Original subject 0'), findsOneWidget);
    });

    testWidgets('discard POSTs discard after confirming the dialog', (tester) async {
      final adapter = FakeAdapter({
        'POST /api/drafts/draft0': (o) => const FakeResponse.ok({'ok': true}),
        'GET /api/today': (o) => FakeResponse.ok({
              'reminders': [],
              'events': [],
              'drafts': [],
              'now': '2026-09-30T10:00:00.000Z',
            }),
      });

      await _pump(tester, overrides: [
        apiClientProvider.overrideWithValue(fakeClient(adapter)),
        mailLauncherProvider.overrideWithValue((_) async => true),
        todayProvider.overrideWith((ref) async => _snapshot(drafts: 1)),
      ]);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      // Confirm in the dialog.
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      final discard = adapter.requests
          .where((r) => r.method == 'POST' && r.path == '/api/drafts/draft0')
          .toList();
      expect(discard, hasLength(1));
      expect((discard.single.data as Map)['action'], 'discard');
    });

    testWidgets('Done patches the reminder status to done', (tester) async {
      final adapter = FakeAdapter({
        'PATCH /api/reminders/rem0': (o) => const FakeResponse.ok({'ok': true}),
        'GET /api/today': (o) => FakeResponse.ok({
              'reminders': [],
              'events': [],
              'drafts': [],
              'now': '2026-09-30T10:00:00.000Z',
            }),
      });

      await _pump(tester, overrides: [
        apiClientProvider.overrideWithValue(fakeClient(adapter)),
        mailLauncherProvider.overrideWithValue((_) async => true),
        todayProvider.overrideWith((ref) async => _snapshot(reminders: 1)),
      ]);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      final patch = adapter.requests
          .where((r) => r.method == 'PATCH' && r.path == '/api/reminders/rem0')
          .toList();
      expect(patch, hasLength(1));
      expect((patch.single.data as Map)['status'], 'done');
    });
  });
}
