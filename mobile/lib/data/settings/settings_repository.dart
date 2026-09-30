import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Reads and writes [AppSettings] to SharedPreferences.
///
/// Keys are namespaced with `ringly.` so they never collide with anything a
/// plugin might store. Unknown or corrupt values (e.g. an enum name from a
/// newer build) fall back to the [AppSettings] defaults rather than throwing —
/// settings should always load, even after a downgrade.
class SettingsRepository {
  const SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kMode = 'ringly.transcriptionMode';
  static const _kLocalOnly = 'ringly.localOnlyMode';
  static const _kAutoTrim = 'ringly.autoTrimSilence';
  static const _kNightly = 'ringly.nightlyReviewEnabled';
  static const _kModelId = 'ringly.whisperModelId';

  AppSettings load() {
    const defaults = AppSettings();
    return AppSettings(
      transcriptionMode: _readMode(defaults.transcriptionMode),
      localOnlyMode: _prefs.getBool(_kLocalOnly) ?? defaults.localOnlyMode,
      autoTrimSilence: _prefs.getBool(_kAutoTrim) ?? defaults.autoTrimSilence,
      nightlyReviewEnabled:
          _prefs.getBool(_kNightly) ?? defaults.nightlyReviewEnabled,
      whisperModelId: _prefs.getString(_kModelId) ?? defaults.whisperModelId,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_kMode, settings.transcriptionMode.name);
    await _prefs.setBool(_kLocalOnly, settings.localOnlyMode);
    await _prefs.setBool(_kAutoTrim, settings.autoTrimSilence);
    await _prefs.setBool(_kNightly, settings.nightlyReviewEnabled);
    await _prefs.setString(_kModelId, settings.whisperModelId);
  }

  TranscriptionMode _readMode(TranscriptionMode fallback) {
    final name = _prefs.getString(_kMode);
    if (name == null) return fallback;
    for (final mode in TranscriptionMode.values) {
      if (mode.name == name) return mode;
    }
    // Unknown enum string (older/newer build): fall back to the default.
    return fallback;
  }
}
