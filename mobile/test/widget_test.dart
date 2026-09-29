// Smoke test for the app shell — replaces the default flutter_create counter
// test, which imported the now-removed lib/main.dart. This confirms RinglyApp
// boots and the router's initial route (Today) renders without a crash;
// feature-specific widget tests live under their own phase (see
// docs/flutter-migration-plan.md section 6, "flutter test passing after each
// feature phase").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ringly_mobile/app.dart';

void main() {
  testWidgets('RinglyApp boots to the Today placeholder route', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RinglyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
  });
}
