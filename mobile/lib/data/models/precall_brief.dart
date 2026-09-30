import '../json.dart';

/// One thing the user committed to on a previous call, and whether the notes
/// suggest it was followed through. The "not done yet" case is the one the
/// brief exists to catch — walking into a call having forgotten a promise is
/// the worst outcome.
class Promise {
  const Promise({required this.promise, required this.appearsDone});

  final String promise;
  final bool appearsDone;

  factory Promise.fromJson(Json json) => Promise(
        promise: readString(json, 'promise'),
        appearsDone: readBool(json, 'appears_done'),
      );
}

/// The pre-call brief for one deal (GET /api/deals/[id]/brief).
///
/// The model output arrives in snake_case (where_we_are, they_care_about,
/// you_promised, ask_about); the contact/deal context fields the server
/// appends are camelCase. Never cached server-side — freshness is the point.
class PrecallBrief {
  const PrecallBrief({
    required this.whereWeAre,
    required this.theyCareAbout,
    required this.youPromised,
    required this.askAbout,
    required this.contactName,
    required this.company,
    required this.dealTitle,
    required this.stage,
    required this.firstConversation,
  });

  final String whereWeAre;
  final List<String> theyCareAbout;
  final List<Promise> youPromised;
  final List<String> askAbout;
  final String contactName;
  final String? company;
  final String dealTitle;
  final String stage;

  /// True when there was no history at all, so the UI can set expectations.
  final bool firstConversation;

  factory PrecallBrief.fromJson(Json json) => PrecallBrief(
        whereWeAre: readString(json, 'where_we_are'),
        theyCareAbout: readStringList(json, 'they_care_about'),
        youPromised: readList(json, 'you_promised', Promise.fromJson),
        askAbout: readStringList(json, 'ask_about'),
        contactName: readString(json, 'contactName'),
        company: readStringOrNull(json, 'company'),
        dealTitle: readString(json, 'dealTitle'),
        stage: readString(json, 'stage'),
        firstConversation: readBool(json, 'firstConversation'),
      );

  /// Promises worth surfacing first: the ones that don't look done yet.
  List<Promise> get openPromises {
    final sorted = [...youPromised]
      ..sort((a, b) {
        if (a.appearsDone == b.appearsDone) return 0;
        return a.appearsDone ? 1 : -1;
      });
    return sorted;
  }
}
