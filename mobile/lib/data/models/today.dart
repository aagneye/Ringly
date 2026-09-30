import '../json.dart';

/// A reminder due today or overdue, from GET /api/today.
class TodayReminder {
  const TodayReminder({
    required this.id,
    required this.message,
    required this.dueAt,
    required this.createdBy,
    required this.dealId,
    required this.dealTitle,
    required this.contactName,
  });

  final String id;
  final String message;
  final DateTime? dueAt;
  final String createdBy;
  final String dealId;
  final String dealTitle;
  final String contactName;

  factory TodayReminder.fromJson(Json json) => TodayReminder(
        id: readString(json, 'id'),
        message: readString(json, 'message'),
        dueAt: readDate(json, 'dueAt'),
        createdBy: readString(json, 'createdBy'),
        dealId: readString(json, 'dealId'),
        dealTitle: readString(json, 'dealTitle'),
        contactName: readString(json, 'contactName'),
      );

  bool isOverdue(DateTime now) => dueAt != null && dueAt!.isBefore(now);
}

/// A meeting on today's calendar — the calls "Brief me" is built for.
class TodayEvent {
  const TodayEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.dealId,
    required this.contactName,
    required this.company,
  });

  final String id;
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;
  final String dealId;
  final String contactName;
  final String? company;

  factory TodayEvent.fromJson(Json json) => TodayEvent(
        id: readString(json, 'id'),
        title: readString(json, 'title'),
        startsAt: readDate(json, 'startsAt'),
        endsAt: readDate(json, 'endsAt'),
        location: readStringOrNull(json, 'location'),
        dealId: readString(json, 'dealId'),
        contactName: readString(json, 'contactName'),
        company: readStringOrNull(json, 'company'),
      );
}

/// An email draft waiting for the human tap — the one irreversible action.
class PendingDraft {
  const PendingDraft({
    required this.id,
    required this.subject,
    required this.body,
    required this.reasoning,
    required this.createdAt,
    required this.dealId,
    required this.dealTitle,
    required this.contactName,
    required this.contactEmail,
  });

  final String id;
  final String subject;
  final String body;
  final String? reasoning;
  final DateTime? createdAt;
  final String dealId;
  final String dealTitle;
  final String contactName;
  final String? contactEmail;

  factory PendingDraft.fromJson(Json json) => PendingDraft(
        id: readString(json, 'id'),
        subject: readString(json, 'subject'),
        body: readString(json, 'body'),
        reasoning: readStringOrNull(json, 'reasoning'),
        createdAt: readDate(json, 'createdAt'),
        dealId: readString(json, 'dealId'),
        dealTitle: readString(json, 'dealTitle'),
        contactName: readString(json, 'contactName'),
        contactEmail: readStringOrNull(json, 'contactEmail'),
      );

  PendingDraft copyWith({String? subject, String? body}) => PendingDraft(
        id: id,
        subject: subject ?? this.subject,
        body: body ?? this.body,
        reasoning: reasoning,
        createdAt: createdAt,
        dealId: dealId,
        dealTitle: dealTitle,
        contactName: contactName,
        contactEmail: contactEmail,
      );
}

/// Everything due today, as returned by GET /api/today.
class TodaySnapshot {
  const TodaySnapshot({
    required this.reminders,
    required this.events,
    required this.drafts,
    required this.now,
  });

  final List<TodayReminder> reminders;
  final List<TodayEvent> events;
  final List<PendingDraft> drafts;
  final DateTime now;

  factory TodaySnapshot.fromJson(Json json) => TodaySnapshot(
        reminders: readList(json, 'reminders', TodayReminder.fromJson),
        events: readList(json, 'events', TodayEvent.fromJson),
        drafts: readList(json, 'drafts', PendingDraft.fromJson),
        now: readDate(json, 'now') ?? DateTime.now(),
      );

  /// Things waiting on the user: drafts to approve plus reminders due.
  int get pendingActionCount => drafts.length + reminders.length;
}
