import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/data/memo/local_memo_store.dart';
import 'package:ringly_mobile/features/recorder/audio_capture.dart';
import 'package:ringly_mobile/features/recorder/recorder_controller.dart';

import '../../support/recorder_fakes.dart';

void main() {
  late Directory temp;
  late FakeCapture capture;
  late FakePermission permission;
  late FakeClock clock;
  late ProviderContainer container;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ringly_rec_');
    capture = FakeCapture();
    permission = FakePermission(MicPermissionResult.granted);
    clock = FakeClock(DateTime(2026, 9, 30, 10));
    container = containerFor(overridesFor(
      capture: capture,
      permission: permission,
      clock: clock,
      dir: temp,
    ));
  });

  tearDown(() async {
    container.dispose();
    await temp.delete(recursive: true);
  });

  RecorderController controller() => container.read(recorderControllerProvider.notifier);
  RecorderState state() => container.read(recorderControllerProvider);

  test('starts idle', () {
    expect(state().phase, RecorderPhase.idle);
  });

  test('idle → recording → saved persists the memo before any upload', () async {
    await controller().start();
    expect(state().phase, RecorderPhase.recording);

    clock.advance(const Duration(seconds: 30));
    capture.emit(0.6);
    await Future<void>.delayed(Duration.zero);
    expect(state().elapsed, const Duration(seconds: 30));
    expect(state().levels, [0.6]);

    final memo = await controller().stop();
    expect(state().phase, RecorderPhase.saved);
    expect(memo, isNotNull);
    expect(memo!.status, MemoStatus.pending);
    expect(memo.durationMs, 30000);

    // A new store over the same directory models "kill the app, reopen".
    final reopened = await LocalMemoStore(temp).list();
    expect(reopened.single.id, memo.id);
    expect(await File(reopened.single.audioPath!).exists(), isTrue);
  });

  test('denied permission lands in error without recording', () async {
    permission.result = MicPermissionResult.denied;
    await controller().start();
    expect(state().phase, RecorderPhase.error);
    expect(state().permanentlyDenied, isFalse);
    expect(capture.path, isNull);
  });

  test('permanent denial offers the settings deep link', () async {
    permission.result = MicPermissionResult.permanentlyDenied;
    await controller().start();
    expect(state().permanentlyDenied, isTrue);
    await controller().openSettings();
    expect(permission.openedSettings, isTrue);
  });

  test('a clip under two seconds is rejected and its file removed', () async {
    await controller().start();
    clock.advance(const Duration(milliseconds: 1200));
    final memo = await controller().stop();

    expect(memo, isNull);
    expect(state().phase, RecorderPhase.error);
    expect(state().error, contains('too short'));
    expect(await File(capture.path!).exists(), isFalse);
    expect(await LocalMemoStore(temp).list(), isEmpty);
  });

  test('flags the soft limit and auto-stops at the hard limit', () async {
    await controller().start();

    clock.advance(const Duration(seconds: 121));
    capture.emit(0.5);
    await Future<void>.delayed(Duration.zero);
    expect(state().nearLimit, isTrue);
    expect(state().isRecording, isTrue);

    clock.advance(const Duration(seconds: 30));
    capture.emit(0.5);
    // Let the unawaited stop() finish its file writes.
    for (var i = 0; i < 20 && state().phase != RecorderPhase.saved; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(state().phase, RecorderPhase.saved);
    expect(state().savedMemo!.durationMs, 151000);
  });

  test('cancel discards the recording', () async {
    await controller().start();
    clock.advance(const Duration(seconds: 5));
    await controller().cancel();
    expect(state().phase, RecorderPhase.idle);
    expect(capture.cancelled, isTrue);
    expect(await File(capture.path!).exists(), isFalse);
  });

  test('the waveform keeps only the most recent levels', () async {
    await controller().start();
    for (var i = 0; i < 60; i++) {
      capture.emit(i / 60);
    }
    await Future<void>.delayed(Duration.zero);
    expect(state().levels.length, 48);
    expect(state().levels.last, closeTo(59 / 60, 1e-9));
  });

  test('dbfsToLevel maps the decibel range onto 0..1', () {
    expect(dbfsToLevel(-160), 0);
    expect(dbfsToLevel(-50), 0);
    expect(dbfsToLevel(-25), closeTo(0.5, 1e-9));
    expect(dbfsToLevel(0), 1);
    expect(dbfsToLevel(double.nan), 0);
  });
}
