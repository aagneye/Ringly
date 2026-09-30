import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/data/contacts/contacts_source.dart';
import 'package:ringly_mobile/data/models/health.dart';
import 'package:ringly_mobile/features/home/widgets/integrations_section.dart';
import 'package:ringly_mobile/providers/contacts_providers.dart';
import 'package:ringly_mobile/providers/data_providers.dart';

import '../../support/fake_contacts_source.dart';

Future<void> _pump(WidgetTester tester, ContactsSource source) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactsSourceProvider.overrideWithValue(source),
        healthProvider.overrideWith(
          (ref) async => const HealthStatus(ok: true, nebius: true, database: true, tavily: true),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: IntegrationsSection())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('integrationsFor reflects the contactsConnected flag', () {
    const health = HealthStatus(ok: true, nebius: true, database: true, tavily: true);
    expect(
      integrationsFor(health, contactsConnected: true).firstWhere((r) => r.name == 'Contacts').detail,
      'Used to match names',
    );
    expect(
      integrationsFor(health).firstWhere((r) => r.name == 'Contacts').detail,
      'Not connected',
    );
  });

  testWidgets('Contacts row shows Not connected when permission is denied', (tester) async {
    await _pump(tester, FakeContactsSource(status: ContactsPermission.denied));
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('Contacts row shows connected when permission is granted', (tester) async {
    await _pump(tester, FakeContactsSource(status: ContactsPermission.granted));
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Used to match names'), findsOneWidget);
  });
}
