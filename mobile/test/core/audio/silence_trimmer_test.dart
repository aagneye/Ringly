import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/audio/silence_trimmer.dart';
import 'package:ringly_mobile/core/audio/wav.dart';

import '../../support/audio_fixtures.dart';

void main() {
  const trimmer = SilenceTrimmer();
  const speech = 6000;
  const hiss = 40; // quiet room noise, well under the -40 dBFS floor

  Duration ms(int n) => Duration(milliseconds: n);

  test('silence-only is flagged empty', () {
    final result = trimmer.trimWav(synthWav([(3, 0)]));
    expect(result.silent, isTrue);
  });

  test('low room noise alone is still flagged empty', () {
    final result = trimmer.trimWav(synthWav([(3, hiss)]));
    expect(result.silent, isTrue);
  });

  test('continuous speech is left unchanged', () {
    final input = synthWav([(2, speech)]);
    final result = trimmer.trimWav(input);
    expect(result.silent, isFalse);
    expect(result.changed, isFalse);
    expect(result.bytes, same(input));
  });

  test('leading and trailing silence are cut to the 200 ms pad', () {
    final result = trimmer.trimWav(synthWav([(2, 0), (1, speech), (2, 0)]));
    expect(result.silent, isFalse);
    expect(result.original, ms(5000));
    // 1 s speech + 200 ms pad each side.
    expect(result.trimmed, ms(1400));
  });

  test('a long pause collapses to half a second', () {
    final result = trimmer.trimWav(synthWav([(1, speech), (4, 0), (1, speech)]));
    expect(result.trimmed, ms(2500));
  });

  test('a short pause is kept intact', () {
    final result = trimmer.trimWav(synthWav([(1, speech), (1, 0), (1, speech)]));
    expect(result.changed, isFalse);
  });

  test('ten seconds of dead air makes the file measurably smaller', () {
    final input = synthWav([(5, 0), (3, speech), (5, 0)]);
    final result = trimmer.trimWav(input);
    expect(result.bytes.length, lessThan(input.length ~/ 3));
  });

  test('the trimmed output is itself a valid WAV of the reported length', () {
    final result = trimmer.trimWav(synthWav([(1, 0), (1, speech), (3, 0), (1, speech)]));
    final parsed = parseWav(result.bytes)!;
    expect(parsed.sampleRate, 16000);
    expect(parsed.duration, result.trimmed);
  });

  test('audio it cannot parse passes through untouched and not silent', () {
    final junk = Uint8List.fromList(List.filled(64, 0));
    final result = trimmer.trimWav(junk);
    expect(result.silent, isFalse);
    expect(result.bytes, same(junk));
  });
}
