import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/contacts/contacts_source.dart';
import 'package:ringly_mobile/data/contacts/device_contact.dart';
import 'package:ringly_mobile/data/models/memo_result.dart';
import 'package:ringly_mobile/features/contacts/contact_suggestion.dart';
import 'package:ringly_mobile/providers/contacts_providers.dart';

import '../../support/fake_contacts_source.dart';

MemoTarget _target({required String matchConfidence, bool createdContact = false}) => MemoTarget(
      contactId: 'c1',
      contactName: 'Priya',
      company: 'Northwind',
      dealId: 'd1',
      dealTitle: 'Rollout',
      stage: 'proposal',
      matchConfidence: matchConfidence,
      createdContact: createdContact,
      createdDeal: false,
    );

const _extraction = MemoExtraction(gist: 'Talked to Priya', contactName: 'Priya', company: 'Northwind');

Future<void> _pump(WidgetTester tester, ContactsSource source, MemoTarget target) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [contactsSourceProvider.overrideWithValue(source)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContactSuggestion(target: target, extraction: _extraction),
          ),
        ),
      ),
    ),
  );
  // Let the FutureProviders (permission, contacts) resolve.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing when the match is certain', (tester) async {
    await _pump(
      tester,
      FakeContactsSource(status: ContactsPermission.granted),
      _target(matchConfidence: 'exact'),
    );
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('Did you mean'), findsNothing);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('shows the Connect card when uncertain and not connected', (tester) async {
    await _pump(
      tester,
      FakeContactsSource(status: ContactsPermission.denied),
      _target(matchConfidence: 'fuzzy'),
    );
    expect(find.textContaining('Connect your contacts'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);
  });

  testWidgets('shows "Did you mean" when uncertain, connected, and a contact matches',
      (tester) async {
    final source = FakeContactsSource(
      status: ContactsPermission.granted,
      contacts: const [
        DeviceContact(
          id: 'p1',
          displayName: 'Priya Sharma',
          company: 'Northwind',
          phones: ['+1 555 0100'],
        ),
      ],
    );
    await _pump(tester, source, _target(matchConfidence: 'fuzzy'));
    expect(find.textContaining('Did you mean Priya Sharma'), findsOneWidget);
    expect(find.text('+1 555 0100'), findsOneWidget);
    expect(find.textContaining('From your phone\'s contacts'), findsOneWidget);
    expect(find.textContaining('filed this under Priya'), findsOneWidget);
  });

  testWidgets('renders nothing when connected but no contact matches', (tester) async {
    final source = FakeContactsSource(
      status: ContactsPermission.granted,
      contacts: const [DeviceContact(id: 'x1', displayName: 'Someone Else', company: 'Globex')],
    );
    await _pump(tester, source, _target(matchConfidence: 'fuzzy'));
    expect(find.byType(Card), findsNothing);
  });
}
