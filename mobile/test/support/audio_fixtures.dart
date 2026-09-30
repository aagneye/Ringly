import 'dart:math';
import 'dart:typed_data';

import 'package:ringly_mobile/core/audio/wav.dart';

const int kRate = 16000;

/// Build synthetic 16 kHz mono audio from segments of (seconds, amplitude).
/// Amplitude 0 is digital silence; speech is a 220 Hz sine, which has a
/// steady RMS of amplitude / √2.
PcmAudio synthAudio(List<(double, int)> segments) {
  final samples = <int>[];
  for (final (seconds, amplitude) in segments) {
    final count = (seconds * kRate).round();
    for (var i = 0; i < count; i++) {
      samples.add((amplitude * sin(2 * pi * 220 * i / kRate)).round());
    }
  }
  return PcmAudio(sampleRate: kRate, channels: 1, samples: Int16List.fromList(samples));
}

Uint8List synthWav(List<(double, int)> segments) => encodeWav(synthAudio(segments));
