import '../json.dart';

/// What Nemotron Lightning pulled out of the memo.
class MemoExtraction {
  const MemoExtraction({
    required this.gist,
    this.contactName,
    this.company,
    this.stageGuess,
    this.nextAction,
    this.deadline,
    this.budget,
    this.concerns,
    this.sentiment,
  });

  final String gist;
  final String? contactName;
  final String? company;
  final String? stageGuess;
  final String? nextAction;
  final String? deadline;
  final String? budget;
  final String? concerns;
  final String? sentiment;

  factory MemoExtraction.fromJson(Json json) => MemoExtraction(
        gist: readString(json, 'gist'),
        contactName: readStringOrNull(json, 'contact_name'),
        company: readStringOrNull(json, 'company'),
        stageGuess: readStringOrNull(json, 'stage_guess'),
        nextAction: readStringOrNull(json, 'next_action'),
        deadline: readStringOrNull(json, 'deadline'),
        budget: readStringOrNull(json, 'budget'),
        concerns: readStringOrNull(json, 'concerns'),
        sentiment: readStringOrNull(json, 'sentiment'),
      );

  /// Labelled non-empty fields, in reading order, for the result screen.
  List<(String, String)> get fields => [
        if (contactName != null) ('Who', contactName!),
        if (company != null) ('Company', company!),
        if (stageGuess != null) ('Stage', stageGuess!),
        if (nextAction != null) ('Next step', nextAction!),
        if (deadline != null) ('Deadline', deadline!),
        if (budget != null) ('Budget', budget!),
        if (concerns != null) ('Concerns', concerns!),
        if (sentiment != null) ('Mood', sentiment!),
      ];
}

/// Which stored contact and deal the memo was filed against.
class MemoTarget {
  const MemoTarget({
    required this.contactId,
    required this.contactName,
    required this.company,
    required this.dealId,
    required this.dealTitle,
    required this.stage,
    required this.matchConfidence,
    required this.createdContact,
    required this.createdDeal,
  });

  final String contactId;
  final String contactName;
  final String? company;
  final String dealId;
  final String dealTitle;
  final String stage;

  /// exact, company, fuzzy or new.
  final String matchConfidence;
  final bool createdContact;
  final bool createdDeal;

  factory MemoTarget.fromJson(Json json) => MemoTarget(
        contactId: readString(json, 'contactId'),
        contactName: readString(json, 'contactName'),
        company: readStringOrNull(json, 'company'),
        dealId: readString(json, 'dealId'),
        dealTitle: readString(json, 'dealTitle'),
        stage: readString(json, 'stage'),
        matchConfidence: readString(json, 'matchConfidence', 'new'),
        createdContact: readBool(json, 'createdContact'),
        createdDeal: readBool(json, 'createdDeal'),
      );

  /// A fuzzy or brand-new match is worth a second look by the user.
  bool get isUncertain => matchConfidence == 'fuzzy' || matchConfidence == 'new';
}

/// One tool the planner chose to call, and what happened.
class ExecutedAction {
  const ExecutedAction({
    required this.tool,
    required this.status,
    required this.summary,
    this.created = const {},
    this.error,
  });

  /// update_deal, set_reminder, schedule_event, draft_email, lookup_company.
  final String tool;

  /// applied, awaiting_approval or failed.
  final String status;
  final String summary;
  final Json created;
  final String? error;

  factory ExecutedAction.fromJson(Json json) => ExecutedAction(
        tool: readString(json, 'tool'),
        status: readString(json, 'status'),
        summary: readString(json, 'summary'),
        created: readObject(json, 'created'),
        error: readStringOrNull(json, 'error'),
      );

  bool get isApplied => status == 'applied';
  bool get awaitsApproval => status == 'awaiting_approval';
  bool get failed => status == 'failed';

  String? get reminderId => readStringOrNull(created, 'reminderId');
  String? get draftId => readStringOrNull(created, 'draftId');
  String? get eventId => readStringOrNull(created, 'eventId');
}

/// One Nemotron call made while processing the memo.
class TraceLine {
  const TraceLine({required this.task, required this.tier, required this.latencyMs});

  final String task;
  final String tier;
  final int latencyMs;

  factory TraceLine.fromJson(Json json) => TraceLine(
        task: readString(json, 'task'),
        tier: readString(json, 'tier'),
        latencyMs: readInt(json, 'latencyMs'),
      );
}

/// POST /api/notes — the whole story of one memo: what was heard, what was
/// understood, who it was about, and every action the agent took.
class MemoResult {
  const MemoResult({
    required this.noteId,
    required this.transcript,
    required this.extraction,
    required this.target,
    required this.actions,
    required this.traces,
    required this.noActionReason,
    required this.transcriptionProvider,
    this.raw = const {},
  });

  final String noteId;
  final String transcript;
  final MemoExtraction extraction;
  final MemoTarget target;
  final List<ExecutedAction> actions;
  final List<TraceLine> traces;

  /// Set when the planner decided nothing needed doing.
  final String? noActionReason;

  /// nemotron-omni, audio-endpoint or client-text.
  final String transcriptionProvider;

  /// The response as received, kept so the device can store it verbatim.
  final Json raw;

  factory MemoResult.fromJson(Json json) {
    final report = readObject(json, 'report');
    final traces = readObject(json, 'traces');
    return MemoResult(
      noteId: readString(json, 'noteId'),
      transcript: readString(json, 'transcript'),
      extraction: MemoExtraction.fromJson(readObject(json, 'extraction')),
      target: MemoTarget.fromJson(readObject(json, 'target')),
      actions: readList(report, 'actions', ExecutedAction.fromJson),
      traces: readList(traces, 'traces', TraceLine.fromJson),
      noActionReason: readStringOrNull(json, 'noActionReason'),
      transcriptionProvider: readString(json, 'transcriptionProvider'),
      raw: json,
    );
  }

  bool get tookNoAction => actions.isEmpty;
  int get awaitingApprovalCount => actions.where((a) => a.awaitsApproval).length;
}
