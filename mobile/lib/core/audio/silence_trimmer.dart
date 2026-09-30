import 'dart:math';
import 'dart:typed_data';

import 'wav.dart';

/// What trimming did to a recording.
class TrimResult {
  const TrimResult({
    required this.bytes,
    required this.original,
    required this.trimmed,
    required this.silent,
  });

  /// The (possibly) shortened WAV file.
  final Uint8List bytes;
  final Duration original;
  final Duration trimmed;

  /// No speech was detected anywhere — the memo is empty.
  final bool silent;

  bool get changed => trimmed < original;
}

/// Energy-based voice-activity trimming, done on the phone before upload.
///
/// Cuts leading and trailing silence and collapses long pauses, so fewer
/// bytes leave the device and the transcriber hears less dead air. No model:
/// RMS energy per 20 ms frame against an adaptive threshold is plenty for a
/// single speaker talking into a phone.
class SilenceTrimmer {
  const SilenceTrimmer({
    this.frame = const Duration(milliseconds: 20),
    this.pad = const Duration(milliseconds: 200),
    this.maxGap = const Duration(milliseconds: 1500),
    this.keptGap = const Duration(milliseconds: 500),
    this.minThreshold = 300,
  });

  final Duration frame;

  /// Audio kept either side of speech so words aren't clipped.
  final Duration pad;

  /// Pauses longer than this are collapsed…
  final Duration maxGap;

  /// …down to this.
  final Duration keptGap;

  /// Absolute RMS floor (≈ −40 dBFS) below which a frame is never speech.
  final double minThreshold;

  /// Trim a WAV file. Anything that isn't 16-bit PCM is returned unchanged
  /// and reported as not silent — better to upload as-is than to guess.
  TrimResult trimWav(Uint8List bytes) {
    final audio = parseWav(bytes);
    if (audio == null || audio.samples.isEmpty) {
      return TrimResult(bytes: bytes, original: Duration.zero, trimmed: Duration.zero, silent: false);
    }
    return trim(audio, originalBytes: bytes);
  }

  TrimResult trim(PcmAudio audio, {Uint8List? originalBytes}) {
    final original = audio.duration;
    final frameLen = max(1, (audio.sampleRate * audio.channels * frame.inMicroseconds) ~/ 1000000);
    final frameCount = (audio.samples.length / frameLen).ceil();

    final energy = List<double>.generate(frameCount, (f) {
      final start = f * frameLen;
      final end = min(start + frameLen, audio.samples.length);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        final s = audio.samples[i].toDouble();
        sum += s * s;
      }
      return sqrt(sum / (end - start));
    });

    final threshold = _threshold(energy);
    final voiced = [for (final e in energy) e >= threshold];
    final first = voiced.indexOf(true);

    if (first < 0) {
      return TrimResult(
        bytes: originalBytes ?? encodeWav(audio),
        original: original,
        trimmed: original,
        silent: true,
      );
    }
    final last = voiced.lastIndexOf(true);

    final padFrames = _frames(pad);
    final maxGapFrames = _frames(maxGap);
    final keptGapFrames = _frames(keptGap);

    final from = max(0, first - padFrames);
    final to = min(frameCount - 1, last + padFrames);

    // Walk the kept range, copying speech and short pauses whole and keeping
    // only the edges of long pauses.
    final keep = <int>[];
    var f = from;
    while (f <= to) {
      if (voiced[f]) {
        keep.add(f++);
        continue;
      }
      var gapEnd = f;
      while (gapEnd <= to && !voiced[gapEnd]) {
        gapEnd++;
      }
      final gapLength = gapEnd - f;
      if (gapLength > maxGapFrames) {
        final head = (keptGapFrames + 1) ~/ 2;
        final tail = keptGapFrames - head;
        for (var i = 0; i < head; i++) {
          keep.add(f + i);
        }
        for (var i = gapEnd - tail; i < gapEnd; i++) {
          keep.add(i);
        }
      } else {
        for (var i = f; i < gapEnd; i++) {
          keep.add(i);
        }
      }
      f = gapEnd;
    }

    final out = <int>[];
    for (final k in keep) {
      final start = k * frameLen;
      final end = min(start + frameLen, audio.samples.length);
      out.addAll(audio.samples.sublist(start, end));
    }

    if (out.length == audio.samples.length) {
      return TrimResult(
        bytes: originalBytes ?? encodeWav(audio),
        original: original,
        trimmed: original,
        silent: false,
      );
    }

    final trimmedAudio = PcmAudio(
      sampleRate: audio.sampleRate,
      channels: audio.channels,
      samples: Int16List.fromList(out),
    );
    return TrimResult(
      bytes: encodeWav(trimmedAudio),
      original: original,
      trimmed: trimmedAudio.duration,
      silent: false,
    );
  }

  /// Adaptive threshold: a multiple of the noise floor, capped relative to the
  /// loudest frame (so constant speech isn't mistaken for noise), never below
  /// [minThreshold] (so a quiet room isn't mistaken for speech).
  double _threshold(List<double> energy) {
    final sorted = [...energy]..sort();
    final floor = sorted[(sorted.length * 0.2).floor().clamp(0, sorted.length - 1)];
    final peak = sorted.last;
    return max(minThreshold, min(floor * 2.5, peak * 0.25));
  }

  int _frames(Duration d) => max(1, (d.inMicroseconds / frame.inMicroseconds).round());
}
