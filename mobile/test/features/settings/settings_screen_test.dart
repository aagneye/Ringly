import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/theme/app_theme.dart';
import 'package:ringly_mobile/core/transcription/whisper_manifest.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/data/settings/app_settings.dart';
import 'package:ringly_mobile/features/settings/settings_providers_local.dart';
import 'package:ringly_mobile/features/settings/settings_screen.dart';
import 'package:ringly_mobile/providers/memo_providers.dart';
import 'package:ringly_mobile/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final manifest = WhisperManifest(models: [
    const WhisperModelInfo(
      id: 'base.en',
      label: 'Base (English)',
      url: 'https://huggingface.co/x/ggml-base.en.bin',
      sizeBytes: 147964211,
      sha256: 'a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002',
      ramMb: 500,
      minRamGb: 4,
    ),
  ]);

  Future<void> pump(WidgetTester tester, {List<String> installed = const []}) async {
    // A tall surface so the whole settings list lays out without needing to
    // scroll off-screen widgets into view (which makes taps flaky in tests).
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whisperManifestProvider.overrideWith((ref) async => manifest),
          installedModelIdsProvider.overrideWith((ref) async => installed),
          memosProvider.overrideWith((ref) async => const <LocalMemo>[]),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the grouped section headers', (tester) async {
    await pump(tester);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('VOICE & TRANSCRIPTION'), findsOneWidget);
    expect(find.text('DATA & PRIVACY'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
  });

  testWidgets('the auto-trim switch toggles and persists', (tester) async {
    await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(container.read(currentSettingsProvider).autoTrimSilence, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Auto-trim silence'));
    await tester.pumpAndSettle();

    expect(container.read(currentSettingsProvider).autoTrimSilence, isFalse);
    // Persisted to prefs.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ringly.autoTrimSilence'), isFalse);
  });

  testWidgets('On-device radio is disabled with no model + no engine', (tester) async {
    await pump(tester);
    final onDevice = tester.widget<RadioListTile<TranscriptionMode>>(
      find.widgetWithText(RadioListTile<TranscriptionMode>, 'On-device'),
    );
    expect(onDevice.onChanged, isNull); // disabled
    // The explanation subtitle is shown.
    expect(
      find.textContaining('on-device engine, which isn\'t in this build yet'),
      findsWidgets,
    );
  });

  testWidgets('Cloud radio is always selectable', (tester) async {
    await pump(tester);
    final cloud = tester.widget<RadioListTile<TranscriptionMode>>(
      find.widgetWithText(RadioListTile<TranscriptionMode>, 'Cloud'),
    );
    expect(cloud.onChanged, isNotNull);
  });
}
