import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ringly_mobile/data/memo/local_memo_store.dart';
import 'package:ringly_mobile/features/recorder/audio_capture.dart';
import 'package:ringly_mobile/providers/memo_providers.dart';

/// A microphone that writes a stub file and emits levels on demand.
class FakeCapture implements AudioCapture {
  final levelsController = StreamController<double>.broadcast();
  String? path;
  bool cancelled = false;

  /// Bytes written as the "recording". Defaults to a non-WAV stub, which the
  /// silence trimmer leaves untouched.
  List<int> content = List.filled(64, 0);

  @override
  Future<void> start(String path) async {
    this.path = path;
    await File(path).create(recursive: true);
    await File(path).writeAsBytes(content);
  }

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Stream<double> levels() => levelsController.stream;

  @override
  Future<void> dispose() => levelsController.close();

  void emit(double level) => levelsController.add(level);
}

class FakePermission implements MicPermission {
  FakePermission(this.result);

  MicPermissionResult result;
  bool openedSettings = false;

  @override
  Future<MicPermissionResult> request() async => result;

  @override
  Future<void> openSettings() async => openedSettings = true;
}

/// A clock the test moves by hand.
class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// Overrides that put the recorder on fakes and a temp-dir store.
List overridesFor({
  required FakeCapture capture,
  required FakePermission permission,
  required FakeClock clock,
  required Directory dir,
}) =>
    [
      audioCaptureProvider.overrideWithValue(capture),
      micPermissionProvider.overrideWithValue(permission),
      clockProvider.overrideWithValue(clock.call),
      memoStoreProvider.overrideWith((ref) async => LocalMemoStore(dir)),
    ];

ProviderContainer containerFor(List overrides) =>
    ProviderContainer(overrides: [...overrides], retry: (_, _) => null);
