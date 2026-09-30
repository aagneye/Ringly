import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/data/memo/local_memo_store.dart';

void main() {
  late Directory temp;
  late LocalMemoStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ringly_store_');
    store = LocalMemoStore(Directory('${temp.path}/memos'));
  });

  tearDown(() => temp.delete(recursive: true));

  LocalMemo memo(String id, DateTime at) =>
      LocalMemo(id: id, createdAt: at, status: MemoStatus.pending, durationMs: 4000);

  test('save then get round-trips every field', () async {
    final original = memo('a', DateTime.utc(2026, 9, 30, 10)).copyWith(
      transcript: 'Spoke to Priya',
      attempts: 2,
      lastError: 'offline',
      nextAttemptAt: DateTime.utc(2026, 9, 30, 11),
      resultJson: {'noteId': 'n1'},
    );
    await store.save(original);

    final loaded = await store.get('a');
    expect(loaded, isNotNull);
    expect(loaded!.transcript, 'Spoke to Priya');
    expect(loaded.attempts, 2);
    expect(loaded.lastError, 'offline');
    expect(loaded.nextAttemptAt!.toUtc(), DateTime.utc(2026, 9, 30, 11));
    expect(loaded.resultJson, {'noteId': 'n1'});
    expect(loaded.createdAt.toUtc(), DateTime.utc(2026, 9, 30, 10));
  });

  test('list returns newest first and survives a new store instance', () async {
    await store.save(memo('old', DateTime.utc(2026, 9, 29)));
    await store.save(memo('new', DateTime.utc(2026, 9, 30)));

    // A fresh instance over the same directory models an app restart.
    final reopened = LocalMemoStore(store.root);
    final ids = (await reopened.list()).map((m) => m.id).toList();
    expect(ids, ['new', 'old']);
  });

  test('update rewrites one memo and ignores missing ids', () async {
    await store.save(memo('a', DateTime.utc(2026, 9, 30)));
    final updated = await store.update('a', (m) => m.copyWith(status: MemoStatus.synced));
    expect(updated!.status, MemoStatus.synced);
    expect((await store.get('a'))!.status, MemoStatus.synced);
    expect(await store.update('missing', (m) => m), isNull);
  });

  test('delete removes the metadata and the audio file', () async {
    final audio = File(await store.audioPathFor('a'));
    await audio.writeAsBytes([1, 2, 3]);
    await store.save(memo('a', DateTime.utc(2026, 9, 30)).copyWith(audioPath: audio.path));

    await store.delete('a');
    expect(await store.get('a'), isNull);
    expect(await audio.exists(), isFalse);
  });

  test('a corrupt metadata file is skipped, not fatal', () async {
    await store.save(memo('good', DateTime.utc(2026, 9, 30)));
    await File('${store.root.path}/bad.json').writeAsString('{not json');
    expect((await store.list()).map((m) => m.id), ['good']);
  });

  test('newId is unique and sorts by time', () {
    final a = LocalMemoStore.newId(DateTime.utc(2026, 1, 1));
    final b = LocalMemoStore.newId(DateTime.utc(2026, 1, 2));
    expect(a, isNot(b));
    expect(a.compareTo(b), lessThan(0));
  });

  test('clearError and clearNextAttempt drop those fields', () {
    final m = memo('a', DateTime.utc(2026)).copyWith(
      lastError: 'x',
      nextAttemptAt: DateTime.utc(2026, 2),
    );
    final cleared = m.copyWith(clearError: true, clearNextAttempt: true);
    expect(cleared.lastError, isNull);
    expect(cleared.nextAttemptAt, isNull);
  });
}
