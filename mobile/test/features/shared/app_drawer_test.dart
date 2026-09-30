import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/features/shared/widgets/app_drawer.dart';
import 'package:ringly_mobile/providers/memo_providers.dart';

void main() {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> pump(WidgetTester tester, {List<LocalMemo> memos = const []}) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) =>
              Scaffold(key: scaffoldKey, drawer: const AppDrawer(), body: const SizedBox()),
        ),
        GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/login', name: 'login', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/pipeline', name: 'pipeline', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/recorder', name: 'recorder', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/actions', name: 'actions', builder: (_, __) => const Scaffold()),
        GoRoute(path: '/models', name: 'models', builder: (_, __) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memosProvider.overrideWith((ref) async => memos),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('renders the account header and the first groups', (tester) async {
    await pump(tester);
    expect(find.text('Ringly'), findsOneWidget);
    expect(find.text('test123@gmail.com'), findsOneWidget);
    expect(find.text('NAVIGATE'), findsOneWidget);
    expect(find.text('CONNECTIONS'), findsOneWidget);
    expect(find.text('VOICE & TRANSCRIPTION'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('the lower groups appear after scrolling', (tester) async {
    await pump(tester);
    final list = find.byType(Scrollable).first;
    await tester.dragUntilVisible(find.text('DATA & PRIVACY'), list, const Offset(0, -200));
    expect(find.text('DATA & PRIVACY'), findsOneWidget);
    await tester.dragUntilVisible(find.text('AI'), list, const Offset(0, -200));
    expect(find.text('AI'), findsOneWidget);
  });

  testWidgets('has a Settings item that navigates and closes the drawer', (tester) async {
    await pump(tester);
    final list = find.byType(Scrollable).first;
    await tester.dragUntilVisible(find.text('Settings'), list, const Offset(0, -200));
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('NAVIGATE'), findsNothing);
  });

  testWidgets('shows a badge for pending memos', (tester) async {
    await pump(tester, memos: [
      LocalMemo(id: 'a', createdAt: DateTime.utc(2026), status: MemoStatus.pending),
      LocalMemo(id: 'b', createdAt: DateTime.utc(2026), status: MemoStatus.syncing),
      LocalMemo(id: 'c', createdAt: DateTime.utc(2026), status: MemoStatus.synced),
    ]);
    final list = find.byType(Scrollable).first;
    await tester.dragUntilVisible(find.text('DATA & PRIVACY'), list, const Offset(0, -200));
    // Two pending/syncing → badge "2" on the Data & privacy row.
    expect(find.text('2'), findsOneWidget);
  });
}
