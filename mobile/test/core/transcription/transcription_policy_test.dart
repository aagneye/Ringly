import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/transcription/transcription_policy.dart';
import 'package:ringly_mobile/data/settings/app_settings.dart';

void main() {
  TranscriptionDecision decide({
    required TranscriptionMode mode,
    required bool online,
    required bool model,
    required bool engine,
    required bool localOnly,
  }) =>
      decideTranscription(
        mode: mode,
        online: online,
        modelPresent: model,
        engineAvailable: engine,
        localOnly: localOnly,
      );

  group('local-only mode (audio must never upload)', () {
    test('on-device when model and engine are both present', () {
      expect(
        decide(mode: TranscriptionMode.cloud, online: true, model: true, engine: true, localOnly: true),
        TranscriptionDecision.onDevice,
      );
    });

    test('blocked when the model is missing', () {
      expect(
        decide(mode: TranscriptionMode.cloud, online: true, model: false, engine: true, localOnly: true),
        TranscriptionDecision.blocked,
      );
    });

    test('blocked when the engine is unavailable', () {
      expect(
        decide(mode: TranscriptionMode.onDevice, online: false, model: true, engine: false, localOnly: true),
        TranscriptionDecision.blocked,
      );
    });

    test('never falls through to cloud, whatever the mode', () {
      for (final mode in TranscriptionMode.values) {
        expect(
          decide(mode: mode, online: true, model: false, engine: false, localOnly: true),
          TranscriptionDecision.blocked,
        );
      }
    });
  });

  group('cloud mode', () {
    test('always cloud', () {
      for (final online in [true, false]) {
        for (final model in [true, false]) {
          for (final engine in [true, false]) {
            expect(
              decide(mode: TranscriptionMode.cloud, online: online, model: model, engine: engine, localOnly: false),
              TranscriptionDecision.cloud,
            );
          }
        }
      }
    });
  });

  group('on-device mode (preference, silent fallback)', () {
    test('on-device when it can run', () {
      expect(
        decide(mode: TranscriptionMode.onDevice, online: true, model: true, engine: true, localOnly: false),
        TranscriptionDecision.onDevice,
      );
    });

    test('falls back to cloud when the model is missing', () {
      expect(
        decide(mode: TranscriptionMode.onDevice, online: true, model: false, engine: true, localOnly: false),
        TranscriptionDecision.cloud,
      );
    });

    test('falls back to cloud when the engine is unavailable', () {
      expect(
        decide(mode: TranscriptionMode.onDevice, online: false, model: true, engine: false, localOnly: false),
        TranscriptionDecision.cloud,
      );
    });
  });

  group('auto mode (on-device only when offline)', () {
    test('offline + ready → on-device', () {
      expect(
        decide(mode: TranscriptionMode.auto, online: false, model: true, engine: true, localOnly: false),
        TranscriptionDecision.onDevice,
      );
    });

    test('online + ready → cloud (accuracy)', () {
      expect(
        decide(mode: TranscriptionMode.auto, online: true, model: true, engine: true, localOnly: false),
        TranscriptionDecision.cloud,
      );
    });

    test('offline but not ready → cloud', () {
      expect(
        decide(mode: TranscriptionMode.auto, online: false, model: false, engine: true, localOnly: false),
        TranscriptionDecision.cloud,
      );
      expect(
        decide(mode: TranscriptionMode.auto, online: false, model: true, engine: false, localOnly: false),
        TranscriptionDecision.cloud,
      );
    });
  });
}
