import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/settings/app_settings.dart';
import 'package:ringly_mobile/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('build loads defaults', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final settings = await container.read(settingsControllerProvider.future);
    expect(settings, const AppSettings());
  });

  test('apply persists so a new container reads the change back', () async {
    final container = ProviderContainer();
    await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .apply((s) => s.copyWith(localOnlyMode: true, whisperModelId: 'tiny.en'));
    expect(container.read(currentSettingsProvider).localOnlyMode, isTrue);
    container.dispose();

    // A brand-new container reads from the same mock prefs.
    final reopened = ProviderContainer();
    addTearDown(reopened.dispose);
    final loaded = await reopened.read(settingsControllerProvider.future);
    expect(loaded.localOnlyMode, isTrue);
    expect(loaded.whisperModelId, 'tiny.en');
  });

  test('currentSettingsProvider yields defaults before load resolves', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Read synchronously before awaiting the future.
    expect(container.read(currentSettingsProvider), const AppSettings());
  });
}
