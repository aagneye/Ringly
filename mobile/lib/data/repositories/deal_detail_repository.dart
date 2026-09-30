import '../../core/api_call.dart';
import '../../core/api_client.dart';
import '../models/deal_detail.dart';
import '../models/precall_brief.dart';

/// GET /api/deals/[id] (the full detail view) and
/// GET /api/deals/[id]/brief (the pre-call brief).
///
/// Kept separate from [DealsRepository] (which owns the board) so the two
/// concerns don't share a file — reads here are per-deal, the board is a list.
class DealDetailRepository {
  const DealDetailRepository(this._client);

  final ApiClient _client;

  /// The full detail for one deal: record, timeline, drafts, facts.
  Future<DealDetail> fetch(String dealId) => apiCall(() async {
        final response = await _client.dio.get<Object?>(
          '/api/deals/${Uri.encodeComponent(dealId)}',
        );
        return DealDetail.fromJson(asJsonObject(response.data));
      });

  /// The pre-call brief. Slow — this hits a Balanced-tier model server-side —
  /// so the client timeout is deliberately generous (see ApiClient).
  Future<PrecallBrief> fetchBrief(String dealId) => apiCall(() async {
        final response = await _client.dio.get<Object?>(
          '/api/deals/${Uri.encodeComponent(dealId)}/brief',
        );
        return PrecallBrief.fromJson(asJsonObject(response.data));
      });
}
