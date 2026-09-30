import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/memo/local_memo.dart';
import '../../data/memo/local_memo_store.dart';
import '../../providers/api_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/memo_providers.dart';
import 'memo_sender.dart';

/// Progress of the memo currently being sent from this screen session.
class SubmissionState {
  const SubmissionState({this.memoId, this.sending = false, this.progress = 0});

  final String? memoId;
  final bool sending;

  /// Upload fraction 0–1. Reaches 1 while the server is still thinking.
  final double progress;

  bool isSending(String id) => sending && memoId == id;
}

final memoSenderProvider = FutureProvider<MemoSender>((ref) async => MemoSender(
      store: await ref.watch(memoStoreProvider.future),
      notes: ref.watch(notesRepositoryProvider),
    ));

/// One stored memo by id, re-read whenever the memo list changes.
final memoByIdProvider = FutureProvider.family<LocalMemo?, String>((ref, id) async {
  ref.watch(memosProvider);
  final store = await ref.watch(memoStoreProvider.future);
  return store.get(id);
});

/// Sends memos and saves typed notes, refreshing everything a new memo can
/// change (the deal board, today's actions, usage counts) once it lands.
class SubmissionController extends Notifier<SubmissionState> {
  @override
  SubmissionState build() => const SubmissionState();

  Future<LocalMemo> submit(LocalMemo memo) async {
    state = SubmissionState(memoId: memo.id, sending: true);
    final sender = await ref.read(memoSenderProvider.future);
    final result = await sender.send(
      memo,
      onProgress: (fraction) {
        if (state.memoId == memo.id) {
          state = SubmissionState(memoId: memo.id, sending: true, progress: fraction);
        }
      },
    );
    ref.invalidate(memosProvider);
    if (result.status == MemoStatus.synced) {
      ref
        ..invalidate(todayProvider)
        ..invalidate(boardProvider)
        ..invalidate(usageProvider);
    }
    if (state.memoId == memo.id) state = SubmissionState(memoId: memo.id);
    return result;
  }

  /// Persist a typed note locally (same guarantees as a recording), then send.
  /// Returns the saved memo immediately; sending continues in the background.
  Future<LocalMemo> saveTextNote(String text) async {
    final store = await ref.read(memoStoreProvider.future);
    final now = ref.read(clockProvider)();
    final memo = LocalMemo(
      id: LocalMemoStore.newId(now),
      createdAt: now,
      status: MemoStatus.pending,
      transcript: text.trim(),
    );
    await store.save(memo);
    ref.invalidate(memosProvider);
    return memo;
  }
}

final submissionControllerProvider =
    NotifierProvider<SubmissionController, SubmissionState>(SubmissionController.new);
