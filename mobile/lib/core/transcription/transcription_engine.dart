/// The seam where a native Whisper engine plugs in.
///
/// Everything around on-device transcription — the manifest, the download and
/// integrity check, the policy that decides cloud-vs-device, the settings UI —
/// is built and tested against this interface. The one missing piece is the
/// native engine that actually runs the model.
///
/// ## Why there is no real engine in this build
///
/// The obvious choice, the `whisper_ggml` plugin, cannot be added here:
///
///   * it requires Android **NDK 29**, whose license the build environment has
///     not accepted, and
///   * it requires **Android Gradle Plugin 8.9+**, newer than the AGP the
///     `flutter create` scaffold in `mobile/android/` ships with.
///
/// Rather than block the whole feature on a native toolchain upgrade, the
/// engine is left behind this interface and defaults to [UnavailableEngine].
/// Downloaded models sit ready on disk; the moment a real engine is dropped in,
/// on-device transcription lights up with no other code change.
///
/// ## How to enable it later
///
///   1. Bump AGP to 8.9+ in `mobile/android/settings.gradle.kts` and accept the
///      NDK 29 license (`sdkmanager --licenses`).
///   2. Add `whisper_ggml` to `pubspec.yaml`.
///   3. Implement [OnDeviceEngine] over it and override `onDeviceEngineProvider`
///      in `lib/providers/transcription_providers.dart` to return it.
abstract interface class OnDeviceEngine {
  /// Whether this engine can actually transcribe on this device/build.
  bool get isAvailable;

  /// Transcribe the WAV at [wavPath] using the model file at [modelPath],
  /// returning the recognised text. Throws if [isAvailable] is false.
  Future<String> transcribe(String wavPath, String modelPath);
}

/// The default engine: no native backend is wired in, so it is never
/// available and throws if anything tries to use it anyway.
///
/// The policy layer treats "engine unavailable" as a reason to fall back to
/// cloud transcription, so in normal use this class's [transcribe] is never
/// reached — the guard in the policy stops first.
class UnavailableEngine implements OnDeviceEngine {
  const UnavailableEngine();

  @override
  bool get isAvailable => false;

  @override
  Future<String> transcribe(String wavPath, String modelPath) {
    throw StateError(
      'On-device transcription is not available in this build. '
      'See OnDeviceEngine for how to enable it.',
    );
  }
}
