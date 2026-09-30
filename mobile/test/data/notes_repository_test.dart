import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/data/repositories/drafts_repository.dart';
import 'package:ringly_mobile/data/repositories/notes_repository.dart';
import 'package:ringly_mobile/data/repositories/reminders_repository.dart';

import '../support/fake_adapter.dart';

/// A minimal /api/notes success body — enough for MemoResult.fromJson.
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

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ringly_notes_');
  });

  tearDown(() async {
    // A multipart upload that errors mid-flight can leave the WAV file handle
    // briefly open on Windows; best-effort cleanup keeps the OS lock from
    // failing the test that already made its assertion.
    try {
      await temp.delete(recursive: true);
    } on FileSystemException {
      // Left for the OS temp sweep.
    }
  });

  group('NotesRepository.submitTranscript', () {
    test('POSTs JSON {transcript} to /api/notes', () async {
      final adapter = FakeAdapter({
        'POST /api/notes': (_) => FakeResponse.ok(_notesOk()),
      });
      final result = await NotesRepository(fakeClient(adapter)).submitTranscript('Spoke to Priya');

      expect(result.noteId, 'n1');
      expect(adapter.requests.single.data, {'transcript': 'Spoke to Priya'});
    });
  });

  group('NotesRepository.submitAudio', () {
    test('POSTs multipart with an audio wav file and durationSeconds', () async {
      final wav = File('${temp.path}/memo.wav');
      await wav.writeAsBytes(List<int>.filled(64, 0));

      final adapter = FakeAdapter({
        'POST /api/notes': (_) => FakeResponse.ok(_notesOk()),
      });
      await NotesRepository(fakeClient(adapter)).submitAudio(
        wav.path,
        duration: const Duration(milliseconds: 4200),
      );

      final data = adapter.requests.single.data as FormData;

      // The duration field is sent in whole tenths of a second.
      final durationField = data.fields.singleWhere((f) => f.key == 'durationSeconds');
      expect(durationField.value, '4.2');

      // The audio part carries the filename and audio/wav content type.
      final audioFile = data.files.singleWhere((f) => f.key == 'audio').value;
      expect(audioFile.filename, 'memo.wav');
      expect(audioFile.contentType.toString(), 'audio/wav');
    });

    test('turns a 413 audio_too_large into a RinglyApiException with status 413', () async {
      final wav = File('${temp.path}/big.wav');
      await wav.writeAsBytes(List<int>.filled(64, 0));

      final adapter = FakeAdapter({
        'POST /api/notes': (_) => const FakeResponse(413, {
              'error': 'That recording is too long.',
              'code': 'audio_too_large',
            }),
      });

      await expectLater(
        NotesRepository(fakeClient(adapter)).submitAudio(wav.path, duration: const Duration(seconds: 1)),
        throwsA(
          isA<RinglyApiException>()
              .having((e) => e.statusCode, 'statusCode', 413)
              .having((e) => e.code, 'code', 'audio_too_large'),
        ),
      );
    });

    test('turns a dropped connection into NetworkException', () async {
      final wav = File('${temp.path}/off.wav');
      await wav.writeAsBytes(List<int>.filled(64, 0));

      final adapter = FakeAdapter({'POST /api/notes': offline});
      await expectLater(
        NotesRepository(fakeClient(adapter)).submitAudio(wav.path, duration: const Duration(seconds: 1)),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('DraftsRepository', () {
    test('approve POSTs the action plus any edited subject/body', () async {
      final adapter = FakeAdapter({
        'POST /api/drafts/x1': (_) => const FakeResponse.ok({'ok': true}),
      });
      await DraftsRepository(fakeClient(adapter)).approve('x1', subject: 'Hi', body: 'There');
      expect(adapter.requests.single.data, {'action': 'approve', 'subject': 'Hi', 'body': 'There'});
    });

    test('approve omits empty subject/body', () async {
      final adapter = FakeAdapter({
        'POST /api/drafts/x1': (_) => const FakeResponse.ok({'ok': true}),
      });
      await DraftsRepository(fakeClient(adapter)).approve('x1');
      expect(adapter.requests.single.data, {'action': 'approve'});
    });

    test('discard POSTs the discard action', () async {
      final adapter = FakeAdapter({
        'POST /api/drafts/x1': (_) => const FakeResponse.ok({'ok': true}),
      });
      await DraftsRepository(fakeClient(adapter)).discard('x1');
      expect(adapter.requests.single.data, {'action': 'discard'});
    });
  });

  group('RemindersRepository', () {
    test('dismiss PATCHes the dismissed status', () async {
      final adapter = FakeAdapter({
        'PATCH /api/reminders/r1': (_) => const FakeResponse.ok({'ok': true}),
      });
      await RemindersRepository(fakeClient(adapter)).dismiss('r1');
      expect(adapter.requests.single.data, {'status': 'dismissed'});
    });

    test('complete PATCHes the done status', () async {
      final adapter = FakeAdapter({
        'PATCH /api/reminders/r1': (_) => const FakeResponse.ok({'ok': true}),
      });
      await RemindersRepository(fakeClient(adapter)).complete('r1');
      expect(adapter.requests.single.data, {'status': 'done'});
    });
  });
}
