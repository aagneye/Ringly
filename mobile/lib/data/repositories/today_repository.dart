import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../models/today.dart';

/// GET /api/today — reminders due, today's meetings, drafts awaiting approval.
class TodayRepository {
  const TodayRepository(this._client);

  final ApiClient _client;

  Future<TodaySnapshot> fetch() => apiCall(() async {
        final response = await _client.dio.get<Object?>('/api/today');
        return TodaySnapshot.fromJson(asJsonObject(response.data));
      });
}
