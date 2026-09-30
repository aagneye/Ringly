import '../json.dart';
import 'deal.dart';

/// The core deal record plus the joined contact (GET /api/deals/[id]).
class DealInfo {
  const DealInfo({
    required this.id,
    required this.title,
    required this.stage,
    required this.nextAction,
    required this.deadline,
    required this.budget,
    required this.concerns,
    required this.sentiment,
    required this.lastContactAt,
    required this.createdAt,
    required this.contactId,
    required this.contactName,
    required this.company,
    required this.email,
    required this.role,
    required this.summary,
  });

  final String id;
  final String title;
  final String stage;
  final String? nextAction;
  final DateTime? deadline;
  final String? budget;
  final String? concerns;
  final String? sentiment;
  final DateTime? lastContactAt;
  final DateTime? createdAt;
  final String contactId;
  final String contactName;
  final String? company;
  final String? email;
  final String? role;
  final String? summary;

  factory DealInfo.fromJson(Json json) => DealInfo(
        id: readString(json, 'id'),
        title: readString(json, 'title'),
        stage: readString(json, 'stage', 'new'),
        nextAction: readStringOrNull(json, 'nextAction'),
        deadline: readDate(json, 'deadline'),
        budget: readStringOrNull(json, 'budget'),
        concerns: readStringOrNull(json, 'concerns'),
        sentiment: readStringOrNull(json, 'sentiment'),
        lastContactAt: readDate(json, 'lastContactAt'),
        createdAt: readDate(json, 'createdAt'),
        contactId: readString(json, 'contactId'),
        contactName: readString(json, 'contactName'),
        company: readStringOrNull(json, 'company'),
        email: readStringOrNull(json, 'email'),
        role: readStringOrNull(json, 'role'),
        summary: readStringOrNull(json, 'summary'),
      );
}

/// A recorded note (verbatim transcript + one-line gist).
class DealNote {
  const DealNote({
    required this.id,
    required this.rawTranscript,
    required this.gist,
    required this.createdAt,
    required this.durationSeconds,
    required this.source,
  });

  final String id;
  final String rawTranscript;
  final String? gist;
  final DateTime? createdAt;
  final int? durationSeconds;
  final String source;

  factory DealNote.fromJson(Json json) => DealNote(
        id: readString(json, 'id'),
        rawTranscript: readString(json, 'rawTranscript'),
        gist: readStringOrNull(json, 'gist'),
        createdAt: readDate(json, 'createdAt'),
        durationSeconds:
            json['durationSeconds'] == null ? null : readInt(json, 'durationSeconds'),
        source: readString(json, 'source', 'voice'),
      );

  /// What the timeline shows for this note: the gist if we have one, else the
  /// raw transcript.
  String get display => (gist != null && gist!.isNotEmpty) ? gist! : rawTranscript;
}

/// An email the agent drafted, still awaiting the human tap.
class DealDraft {
  const DealDraft({
    required this.id,
    required this.subject,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String body;
  final String status;
  final DateTime? createdAt;

  factory DealDraft.fromJson(Json json) => DealDraft(
        id: readString(json, 'id'),
        subject: readString(json, 'subject'),
        body: readString(json, 'body'),
        status: readString(json, 'status', 'draft'),
        createdAt: readDate(json, 'createdAt'),
      );

  bool get isPending => status == 'draft';
}

/// A reminder attached to the deal.
class DealReminder {
  const DealReminder({
    required this.id,
    required this.message,
    required this.dueAt,
    required this.status,
  });

  final String id;
  final String message;
  final DateTime? dueAt;
  final String status;

  factory DealReminder.fromJson(Json json) => DealReminder(
        id: readString(json, 'id'),
        message: readString(json, 'message'),
        dueAt: readDate(json, 'dueAt'),
        status: readString(json, 'status', 'pending'),
      );
}

/// A meeting on Ringly's own calendar.
class DealEvent {
  const DealEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.location,
  });

  final String id;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;

  factory DealEvent.fromJson(Json json) => DealEvent(
        id: readString(json, 'id'),
        title: readString(json, 'title'),
        startsAt: readDate(json, 'startsAt'),
        endsAt: readDate(json, 'endsAt'),
        location: readStringOrNull(json, 'location'),
      );
}

/// One tool call the agent (or the user) made, from the audit table.
class DealAction {
  const DealAction({
    required this.id,
    required this.tool,
    required this.status,
    required this.source,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String tool;
  final String status;

  /// 'manual' when the user did it, otherwise the agent.
  final String source;
  final String summary;
  final DateTime? createdAt;

  factory DealAction.fromJson(Json json) => DealAction(
        id: readString(json, 'id'),
        tool: readString(json, 'tool'),
        status: readString(json, 'status'),
        source: readString(json, 'source'),
        summary: readString(json, 'summary'),
        createdAt: readDate(json, 'createdAt'),
      );

  /// True when the user made this change, not the agent.
  bool get isManual => source == 'manual';
}

/// A fact pulled from the open web about the contact's company (Tavily).
class CompanyFact {
  const CompanyFact({required this.fact, required this.sourceUrl});

  final String fact;
  final String sourceUrl;

  factory CompanyFact.fromJson(Json json) => CompanyFact(
        fact: readString(json, 'fact'),
        sourceUrl: readString(json, 'sourceUrl'),
      );

  /// The host of the source URL, for a compact attribution label.
  String? get sourceHost {
    if (sourceUrl.isEmpty) return null;
    final uri = Uri.tryParse(sourceUrl);
    final host = uri?.host;
    if (host == null || host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

/// The full detail view for one deal (GET /api/deals/[id]).
class DealDetail {
  const DealDetail({
    required this.deal,
    required this.health,
    required this.signals,
    required this.notes,
    required this.drafts,
    required this.reminders,
    required this.events,
    required this.actions,
    required this.facts,
  });

  final DealInfo deal;

  /// 0–100 health score.
  final int health;
  final List<DriftSignal> signals;
  final List<DealNote> notes;
  final List<DealDraft> drafts;
  final List<DealReminder> reminders;
  final List<DealEvent> events;
  final List<DealAction> actions;
  final List<CompanyFact> facts;

  factory DealDetail.fromJson(Json json) => DealDetail(
        deal: DealInfo.fromJson(readObject(json, 'deal')),
        health: readInt(json, 'health', 100),
        signals: readList(json, 'signals', DriftSignal.fromJson),
        notes: readList(json, 'notes', DealNote.fromJson),
        drafts: readList(json, 'drafts', DealDraft.fromJson),
        reminders: readList(json, 'reminders', DealReminder.fromJson),
        events: readList(json, 'events', DealEvent.fromJson),
        actions: readList(json, 'actions', DealAction.fromJson),
        facts: readList(json, 'facts', CompanyFact.fromJson),
      );

  /// The most urgent drift signal, if any.
  DriftSignal? get topSignal => signals.isEmpty
      ? null
      : signals.reduce((a, b) => a.urgency >= b.urgency ? a : b);

  /// Drafts still waiting on the user.
  int get pendingDraftCount => drafts.where((d) => d.isPending).length;
}
