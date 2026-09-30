import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/transcription/model_download_service.dart';
import 'package:ringly_mobile/core/transcription/whisper_manifest.dart';

/// A Dio adapter that returns a fixed byte payload for any request. Enough to
/// exercise the download-then-verify path without touching the network.
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);
  final List<int> bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable([Uint8List.fromList(bytes)]),
      200,
      headers: {
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  final payload = List<int>.generate(2048, (i) => i % 256);
  final realHash = sha256.convert(payload).toString();

  ModelDownloadService service() {
    final dio = Dio()..httpClientAdapter = _BytesAdapter(payload);
    return ModelDownloadService(dio: dio, dir: dir);
  }

  WhisperModelInfo model(String? hash) => WhisperModelInfo(
        id: 'tiny.en',
        label: 'Tiny',
        url: 'https://huggingface.co/x/ggml-tiny.en.bin',
        sizeBytes: payload.length,
        sha256: hash,
        ramMb: 273,
        minRamGb: 3,
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ringly_models_');
  });

  tearDown(() => dir.delete(recursive: true));

  test('a matching checksum renames the part file to <id>.bin', () async {
    final svc = service();
    final file = await svc.download(model(realHash));

    expect(file.path.endsWith('tiny.en.bin'), isTrue);
    expect(await file.exists(), isTrue);
    expect(await svc.isDownloaded('tiny.en'), isTrue);
    expect(await svc.installedIds(), ['tiny.en']);
    // The .part scratch file is gone.
    expect(await File('${dir.path}/tiny.en.bin.part').exists(), isFalse);
  });

  test('a mismatched checksum deletes the download and throws', () async {
    final svc = service();
    final badHash = 'f' * 64;
    await expectLater(
      svc.download(model(badHash)),
      throwsA(isA<ChecksumMismatchException>()),
    );
    // Nothing left on disk — not the .bin, not the .part.
    expect(await svc.isDownloaded('tiny.en'), isFalse);
    expect(await File('${dir.path}/tiny.en.bin.part').exists(), isFalse);
  });

  test('a null sha256 installs without verification', () async {
    final svc = service();
    await svc.download(model(null));
    expect(await svc.isDownloaded('tiny.en'), isTrue);
  });

  test('delete removes an installed model', () async {
    final svc = service();
    await svc.download(model(realHash));
    await svc.delete('tiny.en');
    expect(await svc.isDownloaded('tiny.en'), isFalse);
    expect(await svc.installedIds(), isEmpty);
  });
}
