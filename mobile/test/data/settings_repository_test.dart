import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/settings/app_settings.dart';
import 'package:ringly_mobile/data/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsRepository> repo([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SettingsRepository(await SharedPreferences.getInstance());
  }

  test('load returns defaults on an empty store', () async {
    final settings = (await repo()).load();
    expect(settings.transcriptionMode, TranscriptionMode.cloud);
    expect(settings.localOnlyMode, isFalse);
    expect(settings.autoTrimSilence, isTrue);
    expect(settings.nightlyReviewEnabled, isTrue);
    expect(settings.whisperModelId, 'base.en');
  });

  test('save then load round-trips every field', () async {
    final r = await repo();
    const original = AppSettings(
      transcriptionMode: TranscriptionMode.auto,
      localOnlyMode: true,
      autoTrimSilence: false,
      nightlyReviewEnabled: false,
      whisperModelId: 'tiny.en',
    );
    await r.save(original);

    // A fresh repo over the same (mock) prefs models an app restart.
    final reopened = SettingsRepository(await SharedPreferences.getInstance());
    final loaded = reopened.load();
    expect(loaded.transcriptionMode, TranscriptionMode.auto);
    expect(loaded.localOnlyMode, isTrue);
    expect(loaded.autoTrimSilence, isFalse);
    expect(loaded.nightlyReviewEnabled, isFalse);
    expect(loaded.whisperModelId, 'tiny.en');
    expect(loaded, original);
  });

  test('an unknown transcription mode string falls back to the default', () async {
    final r = await repo({'ringly.transcriptionMode': 'quantum'});
    expect(r.load().transcriptionMode, TranscriptionMode.cloud);
  });

  test('reads a valid persisted enum name', () async {
    final r = await repo({'ringly.transcriptionMode': 'onDevice'});
    expect(r.load().transcriptionMode, TranscriptionMode.onDevice);
  });
}
