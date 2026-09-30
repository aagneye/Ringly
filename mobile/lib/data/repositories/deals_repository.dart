import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../models/deal.dart';

/// GET /api/deals (the board) and PATCH /api/deals/[id] (manual edits).
class DealsRepository {
  const DealsRepository(this._client);

  final ApiClient _client;

  Future<Board> fetchBoard() => apiCall(() async {
        final response = await _client.dio.get<Object?>('/api/deals');
        return Board.fromJson(asJsonObject(response.data));
      });

  /// Move a deal to another stage. Recorded server-side as a manual action, so
  /// the deal's timeline shows "you moved this" next to what Ringly did.
  Future<void> updateStage(String dealId, String stage) => apiCall(() async {
        await _client.dio.patch<Object?>(
          '/api/deals/${Uri.encodeComponent(dealId)}',
          data: {'stage': stage},
        );
      });
}
