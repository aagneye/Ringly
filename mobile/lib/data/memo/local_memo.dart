import '../json.dart';

/// Where a locally stored memo is in its journey to the server.
enum MemoStatus {
  /// Saved on the device, not yet sent.
  pending,

  /// An upload is in flight.
  syncing,

  /// The server processed it; [LocalMemo.resultJson] holds what happened.
  synced,

  /// Gave up after repeated failures; needs a manual retry.
  failed,
}

/// A voice (or typed) memo as persisted on the device.
///
/// The memo is written to disk *before* any network call, so an app crash or
/// a dead zone mid-upload never loses what the user said. The outbox reads
/// these back and drains them to `/api/notes`.
class LocalMemo {
  const LocalMemo({
    required this.id,
    required this.createdAt,
    required this.status,
    this.audioPath,
    this.durationMs = 0,
    this.transcript,
    this.resultJson,
    this.attempts = 0,
    this.lastError,
    this.nextAttemptAt,
  });

  final String id;
  final DateTime createdAt;
  final MemoStatus status;

  /// Absolute path of the WAV file, or null for a typed note.
  final String? audioPath;
  final int durationMs;

  /// Typed text, or the on-device transcription of [audioPath].
  final String? transcript;

  /// The raw `/api/notes` response once synced.
  final Json? resultJson;

  /// Upload attempts so far, for backoff.
  final int attempts;
  final String? lastError;

  /// Earliest time the outbox may retry this memo.
  final DateTime? nextAttemptAt;

  bool get isTextOnly => audioPath == null;
  Duration get duration => Duration(milliseconds: durationMs);

  LocalMemo copyWith({
    MemoStatus? status,
    String? audioPath,
    int? durationMs,
    String? transcript,
    Json? resultJson,
    int? attempts,
    String? lastError,
    DateTime? nextAttemptAt,
    bool clearError = false,
    bool clearNextAttempt = false,
  }) =>
      LocalMemo(
        id: id,
        createdAt: createdAt,
        status: status ?? this.status,
        audioPath: audioPath ?? this.audioPath,
        durationMs: durationMs ?? this.durationMs,
        transcript: transcript ?? this.transcript,
        resultJson: resultJson ?? this.resultJson,
        attempts: attempts ?? this.attempts,
        lastError: clearError ? null : (lastError ?? this.lastError),
        nextAttemptAt: clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
      );

  Json toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status.name,
        'audioPath': audioPath,
        'durationMs': durationMs,
        'transcript': transcript,
        'resultJson': resultJson,
        'attempts': attempts,
        'lastError': lastError,
        'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
      };

  factory LocalMemo.fromJson(Json json) => LocalMemo(
        id: readString(json, 'id'),
        createdAt: readDate(json, 'createdAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: MemoStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => MemoStatus.pending,
        ),
        audioPath: readStringOrNull(json, 'audioPath'),
        durationMs: readInt(json, 'durationMs'),
        transcript: readStringOrNull(json, 'transcript'),
        resultJson: json['resultJson'] is Map<String, dynamic>
            ? json['resultJson'] as Json
            : null,
        attempts: readInt(json, 'attempts'),
        lastError: readStringOrNull(json, 'lastError'),
        nextAttemptAt: readDate(json, 'nextAttemptAt'),
      );
}
