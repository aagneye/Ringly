import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/data/memo/local_memo_store.dart';
import 'package:ringly_mobile/data/repositories/notes_repository.dart';
import 'package:ringly_mobile/features/memo/memo_sender.dart';
import 'package:ringly_mobile/features/memo/outbox_service.dart';

import '../../support/fake_adapter.dart';

Map<String, dynamic> _notesOk() => {
      'noteId': 'n1',
      'transcript': 'hi',
      'transcriptionProvider': 'client-text',
      'extraction': {'gist': 'g'},
      'target': {
        'contactId': 'c1',
        'contactName': 'Priya',
        'dealId': 'd1',
        'dealTitle': 'Deal',
        'stage': 'lead',
        'createdContact': false,
        'createdDeal': false,
      },
      'report': {'actions': []},
      'traces': {'traces': []},
    };

/// A hand-advanced clock, so backoff windows are deterministic.
class FakeClock {
  FakeClock(this._t);
  DateTime _t;
  DateTime call() => _t;
  void advance(Duration d) => _t = _t.add(d);
}

/// A /api/notes handler that can be flipped between offline and success.
class SwitchableNotes {
  bool online = false;
  FakeResponse handle(RequestOptions options) {
    if (!online) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return FakeResponse.ok(_notesOk());
  }
}

void main() {
  late Directory temp;
  late LocalMemoStore store;
  late FakeClock clock;
  late SwitchableNotes backend;
  late FakeAdapter adapter;
  late OutboxService outbox;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ringly_outbox_');
    store = LocalMemoStore(Directory('${temp.path}/memos'));
    clock = FakeClock(DateTime.utc(2026, 9, 30, 10));
    backend = SwitchableNotes();
    adapter = FakeAdapter({'POST /api/notes': backend.handle});
    final sender = MemoSender(store: store, notes: NotesRepository(fakeClient(adapter)));
    outbox = OutboxService(store: store, sender: sender, now: clock.call);
  });

  tearDown(() async {
    try {
      await temp.delete(recursive: true);
    } on FileSystemException {
      // A file handle from an aborted upload can linger on Windows.
    }
  });

  Future<void> queue(String id, {DateTime? at}) => store.save(LocalMemo(
        id: id,
        createdAt: at ?? clock(),
        status: MemoStatus.pending,
        transcript: 'memo $id',
      ));

  test('offline: nothing syncs, attempts increment, a retry is scheduled', () async {
    await queue('a');

    final synced = await outbox.drain();
    expect(synced, 0);

    final memo = (await store.get('a'))!;
    expect(memo.status, MemoStatus.pending);
    expect(memo.attempts, 1);
    expect(memo.nextAttemptAt!.toUtc(), clock().add(const Duration(seconds: 30)));
  });

  test('a memo whose backoff window has not elapsed is skipped', () async {
    await queue('a');
    await outbox.drain(); // first failure → next attempt in 30s

    // Only 10s later: not due yet.
    clock.advance(const Duration(seconds: 10));
    await outbox.drain();
    expect((await store.get('a'))!.attempts, 1); // untouched
  });

  test('once the backoff window passes the memo is retried', () async {
    await queue('a');
    await outbox.drain();

    clock.advance(const Duration(seconds: 31));
    await outbox.drain();
    expect((await store.get('a'))!.attempts, 2);
  });

  test('when the connection returns the queue flushes oldest first', () async {
    await queue('old', at: DateTime.utc(2026, 9, 30, 9));
    await queue('new', at: DateTime.utc(2026, 9, 30, 10));

    backend.online = true;
    final synced = await outbox.drain();

    expect(synced, 2);
    expect((await store.get('old'))!.status, MemoStatus.synced);
    expect((await store.get('new'))!.status, MemoStatus.synced);

    // Oldest memo was sent first.
    final posted = adapter.requests.map((r) => (r.data as Map)['transcript']).toList();
    expect(posted, ['memo old', 'memo new']);
  });

  test('after maxAttempts failures the memo is marked failed', () async {
    await queue('a');
    // Five drains, each stepping past the growing backoff window.
    for (var i = 0; i < 5; i++) {
      await outbox.drain();
      clock.advance(const Duration(minutes: 31)); // always clears the cap
    }
    final memo = (await store.get('a'))!;
    expect(memo.attempts, 5);
    expect(memo.status, MemoStatus.failed);
  });

  test('manual retry resets attempts and sends immediately', () async {
    await queue('a');
    await outbox.drain(); // one failure, attempts = 1, backoff scheduled

    backend.online = true;
    final result = await outbox.retry('a');

    expect(result!.status, MemoStatus.synced);
    // Reset to 0 then one successful send → 1.
    expect(result.attempts, 1);
    expect(result.nextAttemptAt, isNull);
  });

  test('a stale syncing memo (killed app) is reclaimed', () async {
    // Left mid-upload three minutes ago.
    await store.save(LocalMemo(
      id: 'stuck',
      createdAt: clock().subtract(const Duration(minutes: 3)),
      status: MemoStatus.syncing,
      transcript: 'memo stuck',
    ));

    backend.online = true;
    final synced = await outbox.drain();
    expect(synced, 1);
    expect((await store.get('stuck'))!.status, MemoStatus.synced);
  });

  test('a freshly syncing memo is left alone', () async {
    await store.save(LocalMemo(
      id: 'inflight',
      createdAt: clock().subtract(const Duration(seconds: 30)),
      status: MemoStatus.syncing,
      transcript: 'memo inflight',
    ));

    backend.online = true;
    final synced = await outbox.drain();
    expect(synced, 0);
    expect((await store.get('inflight'))!.status, MemoStatus.syncing);
  });

  test('concurrent drain calls share one run', () async {
    await queue('a', at: DateTime.utc(2026, 9, 30, 9));
    await queue('b', at: DateTime.utc(2026, 9, 30, 10));
    backend.online = true;

    final first = outbox.drain();
    final second = outbox.drain();
    expect(identical(first, second), isTrue);

    await Future.wait([first, second]);
    // Two memos, each posted exactly once — no double-send from the overlap.
    expect(adapter.requests.length, 2);
  });

  test('pendingCount counts pending and syncing; failedCount counts failed', () async {
    await queue('p');
    await store.save(LocalMemo(
      id: 's',
      createdAt: clock(),
      status: MemoStatus.syncing,
      transcript: 'x',
    ));
    await store.save(LocalMemo(
      id: 'f',
      createdAt: clock(),
      status: MemoStatus.failed,
      transcript: 'x',
    ));
    await store.save(LocalMemo(
      id: 'done',
      createdAt: clock(),
      status: MemoStatus.synced,
      transcript: 'x',
    ));

    expect(await outbox.pendingCount(), 2);
    expect(await outbox.failedCount(), 1);
  });

  test('backoff is exponential and capped at maxDelay', () {
    expect(outbox.backoff(1), const Duration(seconds: 30));
    expect(outbox.backoff(2), const Duration(minutes: 1));
    expect(outbox.backoff(3), const Duration(minutes: 2));
    expect(outbox.backoff(4), const Duration(minutes: 4));
    // 30s * 2^6 = 32m → capped at 30m.
    expect(outbox.backoff(7), const Duration(minutes: 30));
  });
}
