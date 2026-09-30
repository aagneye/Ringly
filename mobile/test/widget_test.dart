// Smoke test for the app shell: RinglyApp boots and the router's initial
// route (login) renders without a crash.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ringly_mobile/app.dart';

void main() {
  testWidgets('RinglyApp boots to the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: RinglyApp(router: createRouter())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
