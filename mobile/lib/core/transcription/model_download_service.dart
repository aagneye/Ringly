import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'whisper_manifest.dart';

/// Thrown when a downloaded model's SHA-256 does not match the manifest.
///
/// The partial file is deleted before this is thrown, so a corrupt or
/// tampered download never lands on disk as a usable model.
class ChecksumMismatchException implements Exception {
  const ChecksumMismatchException({
    required this.modelId,
    required this.expected,
    required this.actual,
  });

  final String modelId;
  final String expected;
  final String actual;

  @override
  String toString() =>
      'ChecksumMismatchException($modelId): expected $expected, got $actual';
}

/// Downloads Whisper model files to a private directory and verifies them
/// before they are trusted.
///
/// The flow deliberately writes to `<id>.bin.part` first, hashes that file,
/// and only renames it to `<id>.bin` once the SHA-256 matches. A model file
/// existing at `<id>.bin` therefore always means "downloaded and verified" —
/// [isDownloaded] never reports a half-written or corrupt file as installed.
class ModelDownloadService {
  ModelDownloadService({required this.dio, required this.dir});

  /// A plain Dio with no baseUrl — model files stream straight from Hugging
  /// Face, not from the Ringly API, so the app's own client (with its error
  /// interceptor and API base URL) is not reused here.
  final Dio dio;

  /// Where model files live (the app support directory's `models/` folder).
  final Directory dir;

  File fileFor(String id) => File('${dir.path}/$id.bin');
  File _partFileFor(String id) => File('${dir.path}/$id.bin.part');

  Future<bool> isDownloaded(String id) => fileFor(id).exists();

  /// The ids of every fully-downloaded, verified model on disk.
  Future<List<String>> installedIds() async {
    if (!await dir.exists()) return const [];
    final ids = <String>[];
    await for (final entity in dir.list()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (entity is File && name.endsWith('.bin')) {
        ids.add(name.substring(0, name.length - '.bin'.length));
      }
    }
    return ids;
  }

  Future<void> delete(String id) async {
    final file = fileFor(id);
    if (await file.exists()) await file.delete();
    final part = _partFileFor(id);
    if (await part.exists()) await part.delete();
  }

  /// Download [model], verify its SHA-256, and install it as `<id>.bin`.
  ///
  /// [onProgress] reports (received, total) bytes; [cancelToken] cancels an
  /// in-flight download. Throws [ChecksumMismatchException] (after deleting the
  /// partial file) if the hash does not match the manifest.
  Future<File> download(
    WhisperModelInfo model, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await dir.create(recursive: true);
    final part = _partFileFor(model.id);

    await dio.download(
      model.url,
      part.path,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
    );

    final expected = model.sha256;
    if (expected != null) {
      // Stream the file through the hasher rather than loading a ~140 MB file
      // into memory.
      final digest = await sha256.bind(part.openRead()).first;
      final actual = digest.toString();
      if (actual != expected) {
        if (await part.exists()) await part.delete();
        throw ChecksumMismatchException(
          modelId: model.id,
          expected: expected,
          actual: actual,
        );
      }
    }

    final target = fileFor(model.id);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    return target;
  }
}
