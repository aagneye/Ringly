import 'dart:async';

import '../../data/memo/local_memo.dart';
import '../../data/memo/local_memo_store.dart';
import 'memo_sender.dart';

/// Drains stored memos to `/api/notes`, one at a time, with exponential
/// backoff between failed attempts.
///
/// The store is the queue: every memo written to disk before a send is a job
/// waiting here. [drain] is safe to call from anywhere (connectivity change,
/// a timer, app start) — it only ever runs once at a time and skips memos
/// that aren't due yet, so callers don't have to coordinate.
class OutboxService {
  OutboxService({
    required this.store,
    required this.sender,
    required this.now,
    this.maxAttempts = 5,
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 30),
  });

  final LocalMemoStore store;
  final MemoSender sender;

  /// Injectable clock, so backoff and "is it due yet" are testable.
  final DateTime Function() now;

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// A memo left `syncing` longer than this was almost certainly abandoned by
  /// a killed app mid-upload; the outbox reclaims it.
  static const Duration _staleAfter = Duration(minutes: 2);

  /// The in-flight drain, so a second call joins the first rather than running
  /// a concurrent, interleaved pass over the same files.
  Future<int>? _running;

  /// Send every memo that is due, oldest first, one at a time. Returns how
  /// many synced this pass. Concurrent callers share the same run.
  Future<int> drain() => _running ??= _drain().whenComplete(() => _running = null);

  Future<int> _drain() async {
    var synced = 0;
    // Snapshot up front; each send re-reads the memo it's about to touch, so a
    // stale snapshot entry is harmless (a since-synced memo is simply skipped).
    final memos = await store.list();
    // Oldest first: the queue is fair, the earliest memo leaves first.
    final ordered = memos.reversed.toList();

    for (final snapshot in ordered) {
      final memo = await store.get(snapshot.id);
      if (memo == null || !_isDue(memo)) continue;

      final result = await sender.send(memo);
      if (result.status == MemoStatus.synced) {
        synced++;
      } else if (result.status == MemoStatus.pending) {
        await _scheduleRetry(result);
      }
      // A `failed` result is terminal — MemoSender already recorded why.
    }
    return synced;
  }

  /// A memo is ready to send when it is pending (or a stale `syncing` leftover)
  /// and its backoff window has elapsed.
  bool _isDue(LocalMemo memo) {
    final isPending = memo.status == MemoStatus.pending;
    final isStaleSyncing = memo.status == MemoStatus.syncing &&
        now().difference(memo.createdAt) >= _staleAfter;
    if (!isPending && !isStaleSyncing) return false;

    final next = memo.nextAttemptAt;
    if (next != null && now().isBefore(next)) return false;
    return true;
  }

  /// After a failed send that left the memo pending: either give up (too many
  /// attempts) or set the next-attempt time from the backoff schedule.
  Future<void> _scheduleRetry(LocalMemo memo) async {
    if (memo.attempts >= maxAttempts) {
      await store.save(memo.copyWith(
        status: MemoStatus.failed,
        lastError: memo.lastError ?? 'Gave up after $maxAttempts attempts.',
      ));
      return;
    }
    await store.save(memo.copyWith(nextAttemptAt: now().add(backoff(memo.attempts))));
  }

  /// Exponential backoff: 30s, 1m, 2m, 4m … capped at [maxDelay].
  Duration backoff(int attempts) {
    final exponent = attempts <= 1 ? 0 : attempts - 1;
    final scaled = baseDelay * (1 << exponent);
    return scaled > maxDelay ? maxDelay : scaled;
  }

  /// Manual "try again now": clear the backoff and attempt count, then send
  /// immediately regardless of the schedule.
  Future<LocalMemo?> retry(String id) async {
    final memo = await store.get(id);
    if (memo == null) return null;
    final reset = memo.copyWith(
      status: MemoStatus.pending,
      attempts: 0,
      clearError: true,
      clearNextAttempt: true,
    );
    await store.save(reset);
    return sender.send(reset);
  }

  /// Memos still on their way to the server: pending plus in-flight, but not
  /// the ones that permanently failed.
  Future<int> pendingCount() async {
    final memos = await store.list();
    return memos
        .where((m) => m.status == MemoStatus.pending || m.status == MemoStatus.syncing)
        .length;
  }

  /// Memos that gave up and need a manual retry.
  Future<int> failedCount() async {
    final memos = await store.list();
    return memos.where((m) => m.status == MemoStatus.failed).length;
  }
}
