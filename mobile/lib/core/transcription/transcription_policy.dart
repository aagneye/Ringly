import '../../data/settings/app_settings.dart';

/// What the app should do with a memo's audio, given the current state.
enum TranscriptionDecision {
  /// Upload the audio and let the server (Nemotron Omni on Nebius) transcribe.
  cloud,

  /// Transcribe on the phone with the downloaded Whisper model.
  onDevice,

  /// Neither is possible right now, but nothing is wrong — the caller should
  /// hold the memo until conditions change. (Reserved for a future "queue
  /// until on-device is ready" flow; not produced by the current rules.)
  waitForDevice,

  /// Refused: local-only mode is on but on-device transcription can't run, so
  /// uploading the audio would violate the user's privacy choice.
  blocked,
}

/// Decides cloud vs on-device for one memo. Pure: no I/O, no globals, so the
/// whole truth table can be unit-tested.
///
/// The rules, in plain terms:
///   * **Local-only** is a hard privacy promise: audio never leaves the phone.
///     If on-device can run, use it; otherwise [blocked] (never fall back to
///     cloud, that would upload the audio the user asked to keep local).
///   * **On-device** mode is a preference, not a promise: use on-device when
///     it can run, otherwise quietly fall back to [cloud].
///   * **Auto** = on-device when offline and it can run, else cloud. When
///     online we prefer cloud for accuracy.
///   * **Cloud** mode always uploads.
TranscriptionDecision decideTranscription({
  required TranscriptionMode mode,
  required bool online,
  required bool modelPresent,
  required bool engineAvailable,
  required bool localOnly,
}) {
  final canRunOnDevice = modelPresent && engineAvailable;

  // Local-only overrides the mode: the audio must not be uploaded, full stop.
  if (localOnly) {
    return canRunOnDevice
        ? TranscriptionDecision.onDevice
        : TranscriptionDecision.blocked;
  }

  switch (mode) {
    case TranscriptionMode.cloud:
      return TranscriptionDecision.cloud;

    case TranscriptionMode.onDevice:
      // Preference with a silent safety net.
      return canRunOnDevice
          ? TranscriptionDecision.onDevice
          : TranscriptionDecision.cloud;

    case TranscriptionMode.auto:
      // On-device only buys us anything when we're offline; otherwise the
      // cloud model is more accurate, so use it.
      if (!online && canRunOnDevice) return TranscriptionDecision.onDevice;
      return TranscriptionDecision.cloud;
  }
}
