import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../json.dart';

/// POST /api/review — runs the nightly pipeline review on demand.
///
/// The endpoint is cron-guarded: it works locally without a secret, but a
/// deployed server requires its CRON_SECRET. When that's the case the call
/// comes back as a 401 `unauthorised`, which the UI turns into a "run it from
/// the scheduler" note — the app never holds or sends the secret itself.
class ReviewRepository {
  const ReviewRepository(this._client);

  final ApiClient _client;

  Future<Json> runNow() => apiCall(() async {
        final response = await _client.dio.post<Object?>('/api/review');
        return asJsonObject(response.data);
      });
}
