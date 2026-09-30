import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/deal_detail.dart';
import '../data/models/precall_brief.dart';
import '../data/repositories/deal_detail_repository.dart';
import 'api_providers.dart';

/// Reads for a single deal — the detail view and the pre-call brief. Kept out
/// of api_providers.dart (which owns the shared repositories) so this feature
/// owns its own wiring.
final dealDetailRepositoryProvider = Provider<DealDetailRepository>(
  (ref) => DealDetailRepository(ref.watch(apiClientProvider)),
);

/// The full detail for one deal, keyed by id. Invalidate after a stage change
/// so the timeline and header pick up the "you moved this" action.
final dealDetailProvider = FutureProvider.family<DealDetail, String>(
  (ref, dealId) => ref.watch(dealDetailRepositoryProvider).fetch(dealId),
);

/// The pre-call brief for one deal, keyed by id.
///
/// autoDispose so it is never cached: the whole point of the brief is that it
/// reflects the memo recorded ten minutes ago, so reopening the sheet must
/// refetch rather than show a stale answer.
final precallBriefProvider =
    FutureProvider.autoDispose.family<PrecallBrief, String>(
  (ref, dealId) => ref.watch(dealDetailRepositoryProvider).fetchBrief(dealId),
);
