import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/data/memo/local_memo_store.dart';
import 'package:ringly_mobile/data/repositories/notes_repository.dart';
import 'package:ringly_mobile/features/memo/memo_sender.dart';
import 'package:ringly_mobile/providers/transcription_providers.dart';

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

FakeResponse _fail(int status, String code) =>
    FakeResponse(status, {'error': 'nope', 'code': code});

void main() {
  late Directory temp;
  late LocalMemoStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ringly_sender_');
    store = LocalMemoStore(Directory('${temp.path}/memos'));
  });

  tearDown(() async {
    try {
      await temp.delete(recursive: true);
    } on FileSystemException {
      // A file handle from an aborted upload can linger on Windows.
    }
  });

  MemoSender senderFor(FakeAdapter adapter, {MemoPrepare? prepare}) => MemoSender(
        store: store,
        notes: NotesRepository(fakeClient(adapter)),
        prepare: prepare,
      );

  LocalMemo textMemo() => LocalMemo(
        id: 'm1',
        createdAt: DateTime.utc(2026, 9, 30),
        status: MemoStatus.pending,
        transcript: 'Spoke to Priya',
      );

  test('a successful send marks the memo synced with the result and clears errors', () async {
    final adapter = FakeAdapter({'POST /api/notes': (_) => FakeResponse.ok(_notesOk())});
    await store.save(textMemo().copyWith(attempts: 1, lastError: 'earlier failure'));

    final sent = await senderFor(adapter).send(textMemo().copyWith(attempts: 1, lastError: 'earlier failure'));

    expect(sent.status, MemoStatus.synced);
    expect(sent.resultJson!['noteId'], 'n1');
    expect(sent.attempts, 2);
    expect(sent.lastError, isNull);
    expect(sent.nextAttemptAt, isNull);
    // The store agrees with the returned memo.
    expect((await store.get('m1'))!.status, MemoStatus.synced);
  });

  test('a text memo uses submitTranscript, not the audio endpoint', () async {
    final adapter = FakeAdapter({'POST /api/notes': (_) => FakeResponse.ok(_notesOk())});
    await senderFor(adapter).send(textMemo());
    expect(adapter.requests.single.data, {'transcript': 'Spoke to Priya'});
  });

  test('a network failure leaves the memo pending with a friendly error', () async {
    final adapter = FakeAdapter({'POST /api/notes': offline});
    final sent = await senderFor(adapter).send(textMemo());

    expect(sent.status, MemoStatus.pending);
    expect(sent.attempts, 1);
    expect(sent.lastError, isNotNull);
  });

  test('a 422 is a permanent failure and marks the memo failed', () async {
    final adapter = FakeAdapter({'POST /api/notes': (_) => _fail(422, 'empty_transcript')});
    final sent = await senderFor(adapter).send(textMemo());

    expect(sent.status, MemoStatus.failed);
    expect(sent.attempts, 1);
  });

  test('the prepare hook output is what actually gets sent', () async {
    final adapter = FakeAdapter({'POST /api/notes': (_) => FakeResponse.ok(_notesOk())});
    // Memo starts audio-only; prepare transcribes it on-device into text.
    final audio = LocalMemo(
      id: 'm1',
      createdAt: DateTime.utc(2026, 9, 30),
      status: MemoStatus.pending,
      audioPath: '${temp.path}/m1.wav',
    );

    await senderFor(
      adapter,
      prepare: (memo) async => memo.copyWith(transcript: 'transcribed on device'),
    ).send(audio);

    expect(adapter.requests.single.data, {'transcript': 'transcribed on device'});
  });

  group('isPermanentFailure', () {
    test('client 4xx codes that retrying cannot fix are permanent', () {
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'invalid_body', statusCode: 400)), isTrue);
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'audio_too_large', statusCode: 413)), isTrue);
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'empty_transcript', statusCode: 422)), isTrue);
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'empty_memo')), isTrue);
    });

    test('timeouts, rate limits and server errors are worth another go', () {
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'timeout', statusCode: 408)), isFalse);
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'rate_limited', statusCode: 429)), isFalse);
      expect(isPermanentFailure(const RinglyApiException(message: 'x', code: 'nebius_not_configured', statusCode: 503)), isFalse);
    });

    test('a pure network failure is never permanent', () {
      expect(isPermanentFailure(const NetworkException('offline')), isFalse);
    });
  });
}
