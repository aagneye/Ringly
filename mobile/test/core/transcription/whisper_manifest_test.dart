import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/transcription/whisper_manifest.dart';

void main() {
  test('WhisperManifest.fromJson parses models and computes size in MB', () {
    final manifest = WhisperManifest.fromJson({
      'models': [
        {
          'id': 'tiny.en',
          'label': 'Tiny (English)',
          'url': 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
          'sizeBytes': 77704715,
          'sha256': '921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f',
          'ramMb': 273,
          'minRamGb': 3,
        },
      ],
    });

    expect(manifest.models, hasLength(1));
    final tiny = manifest.models.single;
    expect(tiny.id, 'tiny.en');
    expect(tiny.label, 'Tiny (English)');
    expect(tiny.sizeBytes, 77704715);
    expect(tiny.sha256, hasLength(64));
    expect(tiny.ramMb, 273);
    expect(tiny.minRamGb, 3);
    expect(tiny.sizeMb, 74); // 77704715 / 1024^2, rounded
  });

  test('a null sha256 survives parsing (unverifiable download)', () {
    final model = WhisperModelInfo.fromJson({
      'id': 'x',
      'label': 'X',
      'url': 'https://huggingface.co/x',
      'sizeBytes': 1,
      'sha256': null,
      'ramMb': 1,
      'minRamGb': 1,
    });
    expect(model.sha256, isNull);
  });

  test('missing models key yields an empty list', () {
    expect(WhisperManifest.fromJson(const {}).models, isEmpty);
  });
}
