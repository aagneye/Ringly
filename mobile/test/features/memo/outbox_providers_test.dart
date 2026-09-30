import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/providers/memo_providers.dart';
import 'package:ringly_mobile/providers/outbox_providers.dart';

LocalMemo _memo(String id, MemoStatus status) =>
    LocalMemo(id: id, createdAt: DateTime.utc(2026, 9, 30), status: status);

ProviderContainer _containerWith(List<LocalMemo> memos) {
  final container = ProviderContainer(
    overrides: [memosProvider.overrideWith((ref) async => memos)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('pendingOutboxCountProvider', () {
    test('is zero while the memo list is still loading', () {
      final container = _containerWith([]);
      // Read before the FutureProvider resolves: no data yet.
      expect(container.read(pendingOutboxCountProvider), 0);
    });

    test('counts pending and syncing memos, ignoring synced and failed', () async {
      final container = _containerWith([
        _memo('a', MemoStatus.pending),
        _memo('b', MemoStatus.syncing),
        _memo('c', MemoStatus.synced),
        _memo('d', MemoStatus.failed),
        _memo('e', MemoStatus.pending),
      ]);

      // Let the overridden memosProvider resolve.
      await container.read(memosProvider.future);

      expect(container.read(pendingOutboxCountProvider), 3);
    });

    test('is zero when every memo has landed', () async {
      final container = _containerWith([
        _memo('a', MemoStatus.synced),
        _memo('b', MemoStatus.failed),
      ]);
      await container.read(memosProvider.future);
      expect(container.read(pendingOutboxCountProvider), 0);
    });
  });
}
