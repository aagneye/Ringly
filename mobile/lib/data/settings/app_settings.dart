/// How a memo's audio gets turned into text.
enum TranscriptionMode {
  /// Always upload the audio; Nemotron Omni on Nebius transcribes it. Best
  /// accuracy, needs a connection.
  cloud,

  /// Transcribe on the phone with a downloaded Whisper model. Works offline;
  /// the audio never leaves the device.
  onDevice,

  /// On-device when offline, cloud otherwise.
  auto,
}

/// Everything the user can toggle on the settings screen, persisted on the
/// device. Immutable — every change produces a new instance via [copyWith],
/// which is what lets Riverpod tell "changed" from "unchanged".
class AppSettings {
  const AppSettings({
    this.transcriptionMode = TranscriptionMode.cloud,
    this.localOnlyMode = false,
    this.autoTrimSilence = true,
    this.nightlyReviewEnabled = true,
    this.whisperModelId = 'base.en',
  });

  final TranscriptionMode transcriptionMode;

  /// When true, audio must never be uploaded. On-device transcription is the
  /// only path; if it can't run, the memo is refused rather than sent.
  final bool localOnlyMode;

  /// Trim leading/trailing silence from recordings before saving.
  final bool autoTrimSilence;

  /// Whether the nightly pipeline review is expected to run.
  final bool nightlyReviewEnabled;

  /// Which Whisper model the on-device path should use.
  final String whisperModelId;

  AppSettings copyWith({
    TranscriptionMode? transcriptionMode,
    bool? localOnlyMode,
    bool? autoTrimSilence,
    bool? nightlyReviewEnabled,
    String? whisperModelId,
  }) =>
      AppSettings(
        transcriptionMode: transcriptionMode ?? this.transcriptionMode,
        localOnlyMode: localOnlyMode ?? this.localOnlyMode,
        autoTrimSilence: autoTrimSilence ?? this.autoTrimSilence,
        nightlyReviewEnabled: nightlyReviewEnabled ?? this.nightlyReviewEnabled,
        whisperModelId: whisperModelId ?? this.whisperModelId,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.transcriptionMode == transcriptionMode &&
      other.localOnlyMode == localOnlyMode &&
      other.autoTrimSilence == autoTrimSilence &&
      other.nightlyReviewEnabled == nightlyReviewEnabled &&
      other.whisperModelId == whisperModelId;

  @override
  int get hashCode => Object.hash(
        transcriptionMode,
        localOnlyMode,
        autoTrimSilence,
        nightlyReviewEnabled,
        whisperModelId,
      );
}
