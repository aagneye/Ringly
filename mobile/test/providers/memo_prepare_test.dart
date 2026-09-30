import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringly_mobile/core/errors.dart';
import 'package:ringly_mobile/core/transcription/model_download_service.dart';
import 'package:ringly_mobile/core/transcription/transcription_engine.dart';
import 'package:ringly_mobile/data/memo/local_memo.dart';
import 'package:ringly_mobile/data/settings/app_settings.dart';
import 'package:ringly_mobile/providers/settings_providers.dart';
import 'package:ringly_mobile/providers/transcription_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in engine: available, returns a fixed transcript, or throws.
class _FakeEngine implements OnDeviceEngine {
  _FakeEngine({this.available = true, this.result = 'on-device text', this.fail = false});
  final bool available;
  final String result;
  final bool fail;

  @override
  bool get isAvailable => available;

  @override
  Future<String> transcribe(String wavPath, String modelPath) async {
    if (fail) throw StateError('engine boom');
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('ringly_prepare_');
  });

  tearDown(() => dir.delete(recursive: true));

  /// Places a fake model file on disk so isDownloaded() is true.
  Future<void> installModel(String id) async {
    await dir.create(recursive: true);
    await File('${dir.path}/$id.bin').writeAsBytes([1, 2, 3]);
  }

  LocalMemo audioMemo() => LocalMemo(
        id: 'm1',
        createdAt: DateTime.utc(2026, 9, 30),
        status: MemoStatus.pending,
        audioPath: '${dir.path}/m1.wav',
      );

  ProviderContainer container({
    required OnDeviceEngine engine,
    required bool online,
    AppSettings settings = const AppSettings(),
  }) {
    final c = ProviderContainer(
      overrides: [
        onDeviceEngineProvider.overrideWithValue(engine),
        isOnlineProvider.overrideWithValue(() async => online),
        modelDownloadServiceProvider.overrideWith(
          (ref) async => ModelDownloadService(dio: Dio(), dir: dir),
        ),
        // Force the settings value directly.
        currentSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('cloud mode passes the memo through unchanged', () async {
    final c = container(
      engine: _FakeEngine(),
      online: true,
      settings: const AppSettings(transcriptionMode: TranscriptionMode.cloud),
    );
    final prepare = c.read(memoPrepareProvider);
    final out = await prepare(audioMemo());
    expect(out.transcript, isNull);
  });

  test('on-device mode fills the transcript via the engine', () async {
    await installModel('base.en');
    final c = container(
      engine: _FakeEngine(result: 'spoke to Priya'),
      online: false,
      settings: const AppSettings(transcriptionMode: TranscriptionMode.onDevice),
    );
    final out = await c.read(memoPrepareProvider)(audioMemo());
    expect(out.transcript, 'spoke to Priya');
  });

  test('local-only with no on-device path throws 409 (never uploads)', () async {
    final c = container(
      engine: _FakeEngine(available: false),
      online: true,
      settings: const AppSettings(localOnlyMode: true),
    );
    await expectLater(
      c.read(memoPrepareProvider)(audioMemo()),
      throwsA(isA<RinglyApiException>().having((e) => e.statusCode, 'statusCode', 409)),
    );
  });

  test('engine failure falls back to cloud (memo unchanged) when not local-only', () async {
    await installModel('base.en');
    final c = container(
      engine: _FakeEngine(fail: true),
      online: false,
      settings: const AppSettings(transcriptionMode: TranscriptionMode.onDevice),
    );
    final out = await c.read(memoPrepareProvider)(audioMemo());
    expect(out.transcript, isNull);
  });

  test('engine failure under local-only throws rather than uploading', () async {
    await installModel('base.en');
    final c = container(
      engine: _FakeEngine(fail: true),
      online: false,
      settings: const AppSettings(localOnlyMode: true),
    );
    await expectLater(
      c.read(memoPrepareProvider)(audioMemo()),
      throwsA(isA<RinglyApiException>().having((e) => e.code, 'code', 'local_only_blocked')),
    );
  });

  test('an already-transcribed memo is not touched', () async {
    final c = container(engine: _FakeEngine(), online: false, settings: const AppSettings(localOnlyMode: true));
    final memo = audioMemo().copyWith(transcript: 'typed');
    final out = await c.read(memoPrepareProvider)(memo);
    expect(out.transcript, 'typed');
  });
}
