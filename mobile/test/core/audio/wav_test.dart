import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/audio/wav.dart';

import '../../support/audio_fixtures.dart';

void main() {
  test('encode then parse round-trips samples and format', () {
    final audio = synthAudio([(0.5, 8000)]);
    final parsed = parseWav(encodeWav(audio))!;
    expect(parsed.sampleRate, 16000);
    expect(parsed.channels, 1);
    expect(parsed.samples, audio.samples);
    expect(parsed.duration, const Duration(milliseconds: 500));
  });

  test('writes a valid 44-byte canonical header', () {
    final bytes = encodeWav(synthAudio([(0.1, 1000)]));
    final view = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(view.getUint32(4, Endian.little), bytes.length - 8);
    expect(String.fromCharCodes(bytes.sublist(8, 16)), 'WAVEfmt ');
    expect(view.getUint16(20, Endian.little), 1);
    expect(view.getUint32(28, Endian.little), 32000); // byte rate
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    expect(view.getUint32(40, Endian.little), bytes.length - 44);
  });

  test('skips unknown chunks before data', () {
    final canonical = encodeWav(synthAudio([(0.05, 500)]));
    // Insert a 6-byte LIST chunk between fmt and data.
    final list = [...'LIST'.codeUnits, 6, 0, 0, 0, 1, 2, 3, 4, 5, 6];
    final withList = Uint8List.fromList([
      ...canonical.sublist(0, 36),
      ...list,
      ...canonical.sublist(36),
    ]);
    expect(parseWav(withList)!.samples.length, 800);
  });

  test('tolerates a streaming data size of zero', () {
    final bytes = encodeWav(synthAudio([(0.05, 500)]));
    ByteData.sublistView(bytes).setUint32(40, 0, Endian.little);
    expect(parseWav(bytes)!.samples.length, 800);
  });

  test('rejects non-WAV and non-PCM16 input', () {
    expect(parseWav(Uint8List(64)), isNull);
    expect(parseWav(Uint8List(4)), isNull);

    final eightBit = encodeWav(synthAudio([(0.05, 500)]));
    ByteData.sublistView(eightBit).setUint16(34, 8, Endian.little);
    expect(parseWav(eightBit), isNull);
  });
}
