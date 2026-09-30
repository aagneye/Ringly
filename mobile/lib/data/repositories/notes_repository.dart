import 'dart:io';

import 'package:dio/dio.dart';
import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../models/memo_result.dart';

/// Reports upload progress as a fraction from 0 to 1.
typedef UploadProgress = void Function(double fraction);

/// POST /api/notes — the endpoint behind the record button.
///
/// Two ways in, same agent loop out: raw audio (transcribed server-side by
/// Nemotron Omni) or text (typed, or transcribed on the phone). The text path
/// is what makes on-device transcription possible with no backend change.
class NotesRepository {
  const NotesRepository(this._client);

  final ApiClient _client;

  /// Upload a WAV recording as multipart form data.
  Future<MemoResult> submitAudio(
    String path, {
    required Duration duration,
    UploadProgress? onProgress,
  }) =>
      apiCall(() async {
        final form = FormData.fromMap({
          'audio': await MultipartFile.fromFile(
            path,
            filename: File(path).uri.pathSegments.last,
            contentType: DioMediaType('audio', 'wav'),
          ),
          'durationSeconds': (duration.inMilliseconds / 1000).toStringAsFixed(1),
        });
        final response = await _client.dio.post<Object?>(
          '/api/notes',
          data: form,
          onSendProgress: onProgress == null
              ? null
              : (sent, total) {
                  if (total > 0) onProgress(sent / total);
                },
        );
        return MemoResult.fromJson(asJsonObject(response.data));
      });

  /// Send text instead of audio: a typed note or an on-device transcript.
  Future<MemoResult> submitTranscript(String transcript) => apiCall(() async {
        final response = await _client.dio.post<Object?>(
          '/api/notes',
          data: {'transcript': transcript},
        );
        return MemoResult.fromJson(asJsonObject(response.data));
      });
}
