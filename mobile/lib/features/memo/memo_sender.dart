import '../../core/error_message.dart';
import '../../core/errors.dart';
import '../../data/memo/local_memo.dart';
import '../../data/memo/local_memo_store.dart';
import '../../data/models/memo_result.dart';
import '../../data/repositories/notes_repository.dart';

/// Sends one stored memo to `/api/notes` and records the outcome on disk.
///
/// The store is the source of truth: the memo is marked `syncing` before the
/// request and `synced` / `pending` / `failed` after it, so the UI and the
/// outbox always agree on where each memo stands.
class MemoSender {
  const MemoSender({required this.store, required this.notes, this.prepare});

  final LocalMemoStore store;
  final NotesRepository notes;

  /// Optional pre-send step (on-device transcription). See [MemoPrepare].
  final Future<LocalMemo> Function(LocalMemo memo)? prepare;

  /// One attempt. Returns the memo as saved afterwards; never throws for a
  /// network or server failure (the failure is written to the memo instead).
  Future<LocalMemo> send(LocalMemo memo, {UploadProgress? onProgress}) async {
    await store.save(memo.copyWith(status: MemoStatus.syncing, clearError: true));

    try {
      if (prepare != null) {
        memo = await prepare!(memo);
        await store.save(memo.copyWith(status: MemoStatus.syncing, clearError: true));
      }
      final MemoResult result;
      final transcript = memo.transcript?.trim();
      if (transcript != null && transcript.isNotEmpty) {
        // Typed notes and on-device transcripts: only text leaves the phone.
        result = await notes.submitTranscript(transcript);
      } else if (memo.audioPath != null) {
        result = await notes.submitAudio(
          memo.audioPath!,
          duration: memo.duration,
          onProgress: onProgress,
        );
      } else {
        throw const RinglyApiException(message: 'This memo has nothing to send.', code: 'empty_memo');
      }

      final synced = memo.copyWith(
        status: MemoStatus.synced,
        resultJson: result.raw,
        attempts: memo.attempts + 1,
        clearError: true,
        clearNextAttempt: true,
      );
      await store.save(synced);
      return synced;
    } catch (error) {
      final next = memo.copyWith(
        status: isPermanentFailure(error) ? MemoStatus.failed : MemoStatus.pending,
        attempts: memo.attempts + 1,
        lastError: friendlyError(error),
      );
      await store.save(next);
      return next;
    }
  }
}

/// The server looked at this memo and refused it for a reason retrying won't
/// fix (empty, too long, malformed). Everything else — offline, timeouts,
/// missing server configuration — is worth another go later.
bool isPermanentFailure(Object error) {
  if (error is! RinglyApiException) return false;
  if (error.code == 'empty_memo') return true;
  final status = error.statusCode;
  return status != null && status >= 400 && status < 500 && status != 408 && status != 429;
}
