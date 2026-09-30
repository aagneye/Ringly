import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/errors.dart';
import '../core/transcription/model_download_service.dart';
import '../core/transcription/transcription_engine.dart';
import '../core/transcription/transcription_policy.dart';
import '../data/memo/local_memo.dart';
import 'settings_providers.dart';

/// Runs on a memo just before it is sent, and may return a changed copy.
///
/// This is where on-device transcription plugs in: when it's enabled and a
/// model is present, the hook fills in `transcript`, so [MemoSender] sends
/// text and the audio never leaves the phone. When cloud transcription is the
/// decision, the memo is returned unchanged and its audio is uploaded.
typedef MemoPrepare = Future<LocalMemo> Function(LocalMemo memo);

/// Returns whether the device currently has a network connection.
///
/// Injectable so tests can force online/offline without a real radio. The
/// default asks connectivity_plus; a `none` result means offline.
final isOnlineProvider = Provider<Future<bool> Function()>((ref) => () async {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    });

/// The on-device transcription engine. Defaults to [UnavailableEngine] — no
/// native backend ships in this build (see OnDeviceEngine for why and how to
/// enable one). Override this provider to light up on-device transcription.
final onDeviceEngineProvider = Provider<OnDeviceEngine>(
  (ref) => const UnavailableEngine(),
);

/// Downloads and stores Whisper model files under `<appSupport>/models`.
final modelDownloadServiceProvider = FutureProvider<ModelDownloadService>(
  (ref) async {
    final base = await getApplicationSupportDirectory();
    return ModelDownloadService(
      dio: Dio(),
      dir: Directory('${base.path}/models'),
    );
  },
);

/// The pre-send hook. Reads the current settings, checks connectivity and
/// whether the chosen model is on disk, then applies [decideTranscription]:
///
///   * onDevice → transcribe here, return the memo with its transcript filled
///   * blocked  → throw (local-only on, but on-device can't run) so the memo
///                is marked failed rather than silently uploaded
///   * cloud    → return the memo unchanged; the audio uploads as before
///
/// If the engine throws mid-transcription we fall back to cloud — unless
/// local-only mode is on, in which case we must not upload and rethrow.
final memoPrepareProvider = Provider<MemoPrepare>((ref) {
  return (memo) async {
    // Only audio memos with no transcript yet need a decision; typed notes
    // and already-transcribed memos pass straight through.
    if (memo.audioPath == null ||
        (memo.transcript != null && memo.transcript!.trim().isNotEmpty)) {
      return memo;
    }

    final settings = ref.read(currentSettingsProvider);
    final engine = ref.read(onDeviceEngineProvider);
    final downloader = await ref.read(modelDownloadServiceProvider.future);
    final online = await ref.read(isOnlineProvider)();
    final modelPresent = await downloader.isDownloaded(settings.whisperModelId);

    final decision = decideTranscription(
      mode: settings.transcriptionMode,
      online: online,
      modelPresent: modelPresent,
      engineAvailable: engine.isAvailable,
      localOnly: settings.localOnlyMode,
    );

    switch (decision) {
      case TranscriptionDecision.cloud:
      case TranscriptionDecision.waitForDevice:
        return memo;

      case TranscriptionDecision.blocked:
        throw const RinglyApiException(
          message:
              'Local-only mode is on and on-device transcription isn\'t available on this phone yet.',
          code: 'local_only_blocked',
          statusCode: 409,
        );

      case TranscriptionDecision.onDevice:
        final modelPath = downloader.fileFor(settings.whisperModelId).path;
        try {
          final text = await engine.transcribe(memo.audioPath!, modelPath);
          return memo.copyWith(transcript: text);
        } catch (_) {
          // On-device failed. If the user demanded local-only we must not
          // upload the audio — surface the failure instead.
          if (settings.localOnlyMode) {
            throw const RinglyApiException(
              message:
                  'On-device transcription failed and local-only mode is on, so the audio can\'t be uploaded.',
              code: 'local_only_blocked',
              statusCode: 409,
            );
          }
          // Otherwise fall back to cloud: return unchanged, audio uploads.
          return memo;
        }
    }
  };
});
