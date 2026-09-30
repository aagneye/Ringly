import '../../data/models/deal.dart';

/// One stage and the deals in it, ready to render as a section on the Pipeline
/// tab. A pure value type so the grouping logic can be unit tested without a
/// widget tree.
class StageGroup {
  const StageGroup({required this.stage, required this.deals});

  final String stage;
  final List<BoardDeal> deals;

  int get count => deals.length;
  String get label => stageLabel(stage);
}

/// Group a [board] into per-stage sections for the Pipeline tab.
///
/// Open stages (in [kDealStages] order) always appear; won and lost only when
/// [showClosed] is true. Within each stage, quiet deals come first — sorted by
/// how urgent their top drift signal is — then the rest by most recent contact.
/// Empty stages are dropped so the phone list stays tight.
List<StageGroup> groupForPipeline(Board board, {bool showClosed = false}) {
  final byStage = <String, List<BoardDeal>>{};
  for (final deal in board.allDeals) {
    byStage.putIfAbsent(deal.stage, () => []).add(deal);
  }

  final groups = <StageGroup>[];
  for (final stage in kDealStages) {
    if (!showClosed && kClosedStages.contains(stage)) continue;
    final deals = byStage[stage];
    if (deals == null || deals.isEmpty) continue;
    groups.add(StageGroup(stage: stage, deals: _sortDeals(deals)));
  }
  return groups;
}

/// Quiet first (by top signal urgency, most urgent first), then everything else
/// by last contact, most recent first. Nulls sort last.
List<BoardDeal> _sortDeals(List<BoardDeal> deals) {
  final sorted = [...deals]..sort((a, b) {
      if (a.isQuiet != b.isQuiet) return a.isQuiet ? -1 : 1;
      if (a.isQuiet && b.isQuiet) {
        final byUrgency =
            (b.topSignal?.urgency ?? 0).compareTo(a.topSignal?.urgency ?? 0);
        if (byUrgency != 0) return byUrgency;
      }
      final aTime = a.lastContactAt;
      final bTime = b.lastContactAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  return sorted;
}

/// Total open deals across the whole board (not counting won/lost).
int totalOpen(Board board) => board.allDeals.where((d) => d.isOpen).length;
