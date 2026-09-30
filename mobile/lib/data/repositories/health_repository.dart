import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../models/health.dart';

/// GET /api/health.
class HealthRepository {
  const HealthRepository(this._client);

  final ApiClient _client;

  Future<HealthStatus> fetch() => apiCall(() async {
        final response = await _client.dio.get<Object?>('/api/health');
        return HealthStatus.fromJson(asJsonObject(response.data));
      });
}
