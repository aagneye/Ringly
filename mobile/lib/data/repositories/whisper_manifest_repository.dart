import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../../core/transcription/whisper_manifest.dart';

/// GET /api/models/whisper — the catalogue of downloadable on-device models.
class WhisperManifestRepository {
  const WhisperManifestRepository(this._client);

  final ApiClient _client;

  Future<WhisperManifest> fetch() => apiCall(() async {
        final response = await _client.dio.get<Object?>('/api/models/whisper');
        return WhisperManifest.fromJson(asJsonObject(response.data));
      });
}
