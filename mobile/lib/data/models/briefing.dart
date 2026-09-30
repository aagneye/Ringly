import '../json.dart';

/// One item the morning briefing chose to surface.
class BriefingItem {
  const BriefingItem({
    required this.title,
    required this.detail,
    required this.dealId,
    required this.kind,
  });

  final String title;
  final String detail;
  final String? dealId;

  /// meeting, reminder, draft or drift.
  final String kind;

  factory BriefingItem.fromJson(Json json) => BriefingItem(
        title: readString(json, 'title'),
        detail: readString(json, 'detail'),
        dealId: readStringOrNull(json, 'deal_id'),
        kind: readString(json, 'kind', 'drift'),
      );
}

/// GET /api/briefing — Nemotron Ultra's pick of what matters today.
class Briefing {
  const Briefing({
    required this.headline,
    required this.spokenText,
    required this.items,
    required this.cached,
    required this.empty,
  });

  final String headline;
  final String spokenText;
  final List<BriefingItem> items;

  /// Served from today's cache rather than a fresh Ultra call.
  final bool cached;

  /// Nothing to reason about, so no model was called.
  final bool empty;

  factory Briefing.fromJson(Json json) => Briefing(
        headline: readString(json, 'headline'),
        spokenText: readString(json, 'spokenText'),
        items: readList(json, 'items', BriefingItem.fromJson),
        cached: readBool(json, 'cached'),
        empty: readBool(json, 'empty'),
      );
}
