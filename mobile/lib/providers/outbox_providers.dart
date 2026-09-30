import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/memo/local_memo.dart';
import '../features/memo/outbox_service.dart';
import '../features/memo/submission_controller.dart';
import 'data_providers.dart';
import 'memo_providers.dart';

/// The outbox, built from the same store, sender and clock the rest of the
/// app uses. A FutureProvider because the memo store resolves asynchronously.
final outboxServiceProvider = FutureProvider<OutboxService>((ref) async => OutboxService(
      store: await ref.watch(memoStoreProvider.future),
      sender: await ref.watch(memoSenderProvider.future),
      now: ref.watch(clockProvider),
    ));

/// Connectivity changes, behind an injectable provider so a test can feed a
/// controlled stream instead of the real device radio.
final connectivityStreamProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// Starts the outbox and keeps it draining: once on creation, whenever the
/// network comes back, and on a 60-second heartbeat. Watch this from a
/// long-lived widget (AppShell) to keep it alive for the app's lifetime.
///
/// After any pass that synced at least one memo, the screens a new memo can
/// change are invalidated so they refetch.
final outboxStarterProvider = Provider<void>((ref) {
  Future<void> drainAndRefresh() async {
    final outbox = await ref.read(outboxServiceProvider.future);
    final synced = await outbox.drain();
    if (synced > 0) {
      ref.invalidate(memosProvider);
      ref.invalidate(todayProvider);
      ref.invalidate(boardProvider);
      ref.invalidate(usageProvider);
    }
  }

  // Drain once at startup.
  unawaited(drainAndRefresh());

  // Drain when connectivity returns (any non-"none" result).
  final sub = ref.watch(connectivityStreamProvider).listen((results) {
    if (results.any((r) => r != ConnectivityResult.none)) {
      unawaited(drainAndRefresh());
    }
  });

  // A slow heartbeat catches memos whose backoff window elapsed without any
  // connectivity event to wake the outbox.
  final timer = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(drainAndRefresh()));

  ref.onDispose(() {
    sub.cancel();
    timer.cancel();
  });
});

/// How many memos are still on their way to the server, derived from the memo
/// list so the home screen updates the moment a memo is queued or lands.
final pendingOutboxCountProvider = Provider<int>((ref) {
  final memos = ref.watch(memosProvider).value ?? const <LocalMemo>[];
  return memos
      .where((m) => m.status == MemoStatus.pending || m.status == MemoStatus.syncing)
      .length;
});
