import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/features/shared/widgets/nav_destinations.dart';
import 'package:ringly_mobile/features/shared/widgets/ringly_bottom_bar.dart';

Widget _host({int selected = 0, int badge = 0, ValueChanged<int>? onSelected}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: RinglyBottomBar(
        selectedIndex: selected,
        actionsBadgeCount: badge,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

void main() {
  test('there are exactly five destinations with Record in the centre', () {
    expect(kNavDestinations, hasLength(5));
    expect(kNavDestinations[2].isPrimary, isTrue);
    expect(kNavDestinations.where((d) => d.isPrimary), hasLength(1));
  });

  test('navIndexForPath maps routes to their tab', () {
    expect(navIndexForPath('/home'), 0);
    expect(navIndexForPath('/pipeline'), 1);
    expect(navIndexForPath('/recorder'), 2);
    expect(navIndexForPath('/actions'), 3);
    expect(navIndexForPath('/models'), 4);
    expect(navIndexForPath('/login'), -1);
  });

  testWidgets('renders the four flat tab labels and the record button',
      (tester) async {
    await tester.pumpWidget(_host());
    for (final label in ['Home', 'Pipeline', 'Actions', 'Models']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Record a memo'), findsOneWidget);
  });

  testWidgets('badge is hidden at zero', (tester) async {
    await tester.pumpWidget(_host(badge: 0));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('badge shows the pending count', (tester) async {
    await tester.pumpWidget(_host(badge: 3));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping record selects the centre destination', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(onSelected: (i) => tapped = i));
    await tester.tap(find.bySemanticsLabel('Record a memo'));
    expect(tapped, 2);
  });

  testWidgets('tapping a flat tab reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(onSelected: (i) => tapped = i));
    await tester.tap(find.text('Actions'));
    expect(tapped, 3);
  });
}
