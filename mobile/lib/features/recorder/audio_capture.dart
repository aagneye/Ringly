import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// The microphone, behind an interface so the recorder's state machine can be
/// tested without a device.
abstract interface class AudioCapture {
  Future<void> start(String path);

  /// Stops and returns the file path, or null if nothing was recorded.
  Future<String?> stop();

  /// Discards the in-progress recording.
  Future<void> cancel();

  /// Normalised input level, 0 (silence) to 1 (loud), roughly every 100 ms.
  Stream<double> levels();

  Future<void> dispose();
}

/// 16 kHz mono PCM16 WAV via the `record` plugin.
///
/// Why WAV and not a compressed codec: the silence trimmer needs raw PCM,
/// whisper.cpp wants 16 kHz WAV, and 120 s is only ~3.8 MB — well under the
/// server's 10 MB upload cap.
class RecordAudioCapture implements AudioCapture {
  RecordAudioCapture([AudioRecorder? recorder]) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  static const config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
    autoGain: true,
    noiseSuppress: true,
  );

  @override
  Future<void> start(String path) => _recorder.start(config, path: path);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((amp) => dbfsToLevel(amp.current));

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Map dBFS (−160…0) onto 0…1, treating −50 dB and below as silence.
double dbfsToLevel(double dbfs) {
  if (dbfs.isNaN) return 0;
  const floor = -50.0;
  if (dbfs <= floor) return 0;
  if (dbfs >= 0) return 1;
  return (dbfs - floor) / -floor;
}

enum MicPermissionResult { granted, denied, permanentlyDenied }

/// Runtime microphone permission, behind an interface for tests.
abstract interface class MicPermission {
  Future<MicPermissionResult> request();

  /// Opens the OS settings page, for after a permanent denial.
  Future<void> openSettings();
}

class PlatformMicPermission implements MicPermission {
  const PlatformMicPermission();

  @override
  Future<MicPermissionResult> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted || status.isLimited) return MicPermissionResult.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermissionResult.permanentlyDenied;
    }
    return MicPermissionResult.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}
