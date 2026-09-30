import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../models/usage.dart';

/// GET /api/usage — live Nemotron tier counts, tokens and latency.
class UsageRepository {
  const UsageRepository(this._client);

  final ApiClient _client;

  Future<UsageSummary> fetch() => apiCall(() async {
        final response = await _client.dio.get<Object?>('/api/usage');
        return UsageSummary.fromJson(asJsonObject(response.data));
      });
}
