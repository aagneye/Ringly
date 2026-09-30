import 'dart:typed_data';

/// Decoded 16-bit PCM audio.
class PcmAudio {
  const PcmAudio({required this.sampleRate, required this.channels, required this.samples});

  final int sampleRate;
  final int channels;

  /// Interleaved samples (mono in practice: the recorder captures one channel).
  final Int16List samples;

  Duration get duration => Duration(
        microseconds: samples.isEmpty
            ? 0
            : (samples.length / channels / sampleRate * Duration.microsecondsPerSecond).round(),
      );
}

/// Parse a RIFF/WAVE file holding 16-bit PCM. Returns null for anything else
/// (compressed audio, 8/24/32-bit, truncated headers) so callers can skip
/// processing instead of corrupting a recording they don't understand.
///
/// Walks the chunk list rather than assuming a fixed 44-byte header, because
/// recorders are free to insert LIST/fact chunks before `data`.
PcmAudio? parseWav(Uint8List bytes) {
  if (bytes.length < 12) return null;
  final view = ByteData.sublistView(bytes);
  if (_tag(bytes, 0) != 'RIFF' || _tag(bytes, 8) != 'WAVE') return null;

  int? format;
  int? channels;
  int? sampleRate;
  int? bits;
  var offset = 12;

  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    var size = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;

    if (id == 'fmt ' && body + 16 <= bytes.length) {
      format = view.getUint16(body, Endian.little);
      channels = view.getUint16(body + 2, Endian.little);
      sampleRate = view.getUint32(body + 4, Endian.little);
      bits = view.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      if (format != 1 || bits != 16 || channels == null || channels == 0 || sampleRate == null) {
        return null;
      }
      // Streaming writers may leave the size as 0 or 0xFFFFFFFF until close;
      // trust the bytes actually present in that case.
      final available = bytes.length - body;
      if (size == 0 || size > available) size = available;
      final count = size ~/ 2;
      final samples = Int16List(count);
      for (var i = 0; i < count; i++) {
        samples[i] = view.getInt16(body + i * 2, Endian.little);
      }
      return PcmAudio(sampleRate: sampleRate, channels: channels, samples: samples);
    }

    // Chunks are word-aligned: odd sizes carry one pad byte.
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

/// Encode 16-bit PCM as a canonical 44-byte-header WAV file.
Uint8List encodeWav(PcmAudio audio) {
  final dataBytes = audio.samples.length * 2;
  final out = ByteData(44 + dataBytes);
  final blockAlign = audio.channels * 2;

  void tag(int at, String value) {
    for (var i = 0; i < 4; i++) {
      out.setUint8(at + i, value.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, audio.channels, Endian.little);
  out.setUint32(24, audio.sampleRate, Endian.little);
  out.setUint32(28, audio.sampleRate * blockAlign, Endian.little);
  out.setUint16(32, blockAlign, Endian.little);
  out.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < audio.samples.length; i++) {
    out.setInt16(44 + i * 2, audio.samples[i], Endian.little);
  }
  return out.buffer.asUint8List();
}

String _tag(Uint8List bytes, int at) =>
    at + 4 > bytes.length ? '' : String.fromCharCodes(bytes.sublist(at, at + 4));
