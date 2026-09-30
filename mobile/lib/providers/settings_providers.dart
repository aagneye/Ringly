import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings/app_settings.dart';
import '../data/settings/settings_repository.dart';

/// The one SharedPreferences instance, resolved once. Overridden in tests with
/// `SharedPreferences.setMockInitialValues({})`.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// The repository, ready once SharedPreferences has loaded.
final settingsRepositoryProvider = FutureProvider<SettingsRepository>(
  (ref) async => SettingsRepository(
    await ref.watch(sharedPreferencesProvider.future),
  ),
);

/// Loads settings, then persists every change.
///
/// [update] takes the current settings and returns the new ones, so callers
/// write `controller.update((s) => s.copyWith(localOnlyMode: true))` without
/// having to read the current value first.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    return repo.load();
  }

  /// Applies [change] to the current settings and persists the result.
  ///
  /// Named [apply] rather than `update` because [AsyncNotifier] already has an
  /// `update` method with a different signature.
  Future<void> apply(AppSettings Function(AppSettings) change) async {
    final repo = await ref.read(settingsRepositoryProvider.future);
    final current = state.value ?? const AppSettings();
    final next = change(current);
    state = AsyncData(next);
    await repo.save(next);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// A synchronous view of the current settings, for widgets and providers that
/// only need the value and want defaults until it loads. Returns the loaded
/// settings, or [AppSettings] defaults while loading or on error.
final currentSettingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(settingsControllerProvider).value ?? const AppSettings(),
);
