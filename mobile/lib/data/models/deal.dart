import '../json.dart';

/// Pipeline stages, in board order. Mirrors DEAL_STAGES on the server.
const List<String> kDealStages = [
  'new',
  'contacted',
  'proposal',
  'negotiation',
  'won',
  'lost',
];

/// Stages where no further follow-up is expected.
const Set<String> kClosedStages = {'won', 'lost'};

String stageLabel(String stage) =>
    stage.isEmpty ? stage : '${stage[0].toUpperCase()}${stage.substring(1)}';

/// Why a deal was flagged as drifting, computed deterministically server-side.
class DriftSignal {
  const DriftSignal({
    required this.dealId,
    required this.reason,
    required this.urgency,
    required this.explanation,
    required this.daysSinceContact,
    required this.daysUntilDeadline,
  });

  final String dealId;
  final String reason;

  /// 0–100; higher is more urgent.
  final int urgency;
  final String explanation;
  final int? daysSinceContact;
  final int? daysUntilDeadline;

  factory DriftSignal.fromJson(Json json) => DriftSignal(
        dealId: readString(json, 'dealId'),
        reason: readString(json, 'reason'),
        urgency: readInt(json, 'urgency'),
        explanation: readString(json, 'explanation'),
        daysSinceContact:
            json['daysSinceContact'] == null ? null : readInt(json, 'daysSinceContact'),
        daysUntilDeadline:
            json['daysUntilDeadline'] == null ? null : readInt(json, 'daysUntilDeadline'),
      );
}

/// A deal as the board shows it (GET /api/deals).
class BoardDeal {
  const BoardDeal({
    required this.id,
    required this.title,
    required this.stage,
    required this.contactId,
    required this.contactName,
    required this.company,
    required this.nextAction,
    required this.deadline,
    required this.budget,
    required this.sentiment,
    required this.lastContactAt,
    required this.health,
    required this.signals,
    required this.noteCount,
    required this.pendingDraftCount,
  });

  final String id;
  final String title;
  final String stage;
  final String contactId;
  final String contactName;
  final String? company;
  final String? nextAction;
  final DateTime? deadline;
  final String? budget;
  final String? sentiment;
  final DateTime? lastContactAt;

  /// 0–100 health score.
  final int health;
  final List<DriftSignal> signals;
  final int noteCount;
  final int pendingDraftCount;

  factory BoardDeal.fromJson(Json json) => BoardDeal(
        id: readString(json, 'id'),
        title: readString(json, 'title'),
        stage: readString(json, 'stage', 'new'),
        contactId: readString(json, 'contactId'),
        contactName: readString(json, 'contactName'),
        company: readStringOrNull(json, 'company'),
        nextAction: readStringOrNull(json, 'nextAction'),
        deadline: readDate(json, 'deadline'),
        budget: readStringOrNull(json, 'budget'),
        sentiment: readStringOrNull(json, 'sentiment'),
        lastContactAt: readDate(json, 'lastContactAt'),
        health: readInt(json, 'health', 100),
        signals: readList(json, 'signals', DriftSignal.fromJson),
        noteCount: readInt(json, 'noteCount'),
        pendingDraftCount: readInt(json, 'pendingDraftCount'),
      );

  bool get isQuiet => signals.isNotEmpty;
  bool get isOpen => !kClosedStages.contains(stage);

  /// The most urgent drift signal, if any.
  DriftSignal? get topSignal => signals.isEmpty
      ? null
      : signals.reduce((a, b) => a.urgency >= b.urgency ? a : b);

  BoardDeal withStage(String newStage) => BoardDeal(
        id: id,
        title: title,
        stage: newStage,
        contactId: contactId,
        contactName: contactName,
        company: company,
        nextAction: nextAction,
        deadline: deadline,
        budget: budget,
        sentiment: sentiment,
        lastContactAt: lastContactAt,
        health: health,
        signals: signals,
        noteCount: noteCount,
        pendingDraftCount: pendingDraftCount,
      );
}

class BoardColumn {
  const BoardColumn({required this.stage, required this.deals});

  final String stage;
  final List<BoardDeal> deals;

  factory BoardColumn.fromJson(Json json) => BoardColumn(
        stage: readString(json, 'stage'),
        deals: readList(json, 'deals', BoardDeal.fromJson),
      );
}

class Board {
  const Board({required this.columns, required this.total});

  final List<BoardColumn> columns;
  final int total;

  factory Board.fromJson(Json json) => Board(
        columns: readList(json, 'columns', BoardColumn.fromJson),
        total: readInt(json, 'total'),
      );

  Iterable<BoardDeal> get allDeals => columns.expand((c) => c.deals);

  /// Open deals the drift detector flagged, most urgent first.
  List<BoardDeal> get quietDeals {
    final quiet = allDeals.where((d) => d.isOpen && d.isQuiet).toList()
      ..sort((a, b) => (b.topSignal?.urgency ?? 0).compareTo(a.topSignal?.urgency ?? 0));
    return quiet;
  }

  int countFor(String stage) =>
      columns.where((c) => c.stage == stage).fold(0, (n, c) => n + c.deals.length);

  int get openCount => allDeals.where((d) => d.isOpen).length;
}
