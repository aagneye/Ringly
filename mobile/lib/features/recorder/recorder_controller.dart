import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/memo/local_memo.dart';
import '../../data/memo/local_memo_store.dart';
import '../../providers/memo_providers.dart';
import 'audio_capture.dart';

enum RecorderPhase { idle, requestingPermission, recording, stopping, saved, error }

/// Everything the recorder screen renders.
class RecorderState {
  const RecorderState({
    this.phase = RecorderPhase.idle,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.error,
    this.permanentlyDenied = false,
    this.savedMemo,
  });

  final RecorderPhase phase;
  final Duration elapsed;

  /// Recent input levels (0–1), oldest first, for the live waveform.
  final List<double> levels;
  final String? error;

  /// The user said "don't ask again"; only the OS settings page can fix it.
  final bool permanentlyDenied;

  /// The memo just written to disk, once [phase] is [RecorderPhase.saved].
  final LocalMemo? savedMemo;

  bool get isRecording => phase == RecorderPhase.recording;

  /// Past the soft limit: show a "wrap it up" hint.
  bool get nearLimit => elapsed >= RecorderController.softLimit;

  RecorderState copyWith({
    RecorderPhase? phase,
    Duration? elapsed,
    List<double>? levels,
    String? error,
    bool? permanentlyDenied,
    LocalMemo? savedMemo,
  }) =>
      RecorderState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        levels: levels ?? this.levels,
        error: error,
        permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
        savedMemo: savedMemo ?? this.savedMemo,
      );
}

/// The recorder's state machine:
///
///   idle → requestingPermission → recording → stopping → saved
///                         ↘ error        ↘ error (too short / failed)
///
/// The audio file and its metadata are persisted *before* anything touches
/// the network, so killing the app right after "stop" still keeps the memo.
class RecorderController extends Notifier<RecorderState> {
  /// Show a gentle "wrap it up" hint from here.
  static const softLimit = Duration(seconds: 120);

  /// Stop automatically: long rambles cost more and help nobody.
  static const hardLimit = Duration(seconds: 150);

  /// Anything shorter is almost certainly an accidental tap.
  static const minDuration = Duration(seconds: 2);

  static const _maxLevels = 48;

  StreamSubscription<double>? _levels;
  String? _id;
  String? _path;
  DateTime? _startedAt;

  @override
  RecorderState build() {
    ref.onDispose(() => _levels?.cancel());
    return const RecorderState();
  }

  AudioCapture get _capture => ref.read(audioCaptureProvider);
  DateTime _now() => ref.read(clockProvider)();

  Future<void> start() async {
    if (state.phase == RecorderPhase.recording ||
        state.phase == RecorderPhase.requestingPermission ||
        state.phase == RecorderPhase.stopping) {
      return;
    }
    state = const RecorderState(phase: RecorderPhase.requestingPermission);

    final permission = await ref.read(micPermissionProvider).request();
    if (permission != MicPermissionResult.granted) {
      final permanent = permission == MicPermissionResult.permanentlyDenied;
      state = RecorderState(
        phase: RecorderPhase.error,
        permanentlyDenied: permanent,
        error: permanent
            ? 'Microphone access is turned off for Ringly. Enable it in Settings to record memos.'
            : 'Ringly needs the microphone to record your memo. You can also type a note instead.',
      );
      return;
    }

    try {
      final store = await ref.read(memoStoreProvider.future);
      final startedAt = _now();
      final id = LocalMemoStore.newId(startedAt);
      final path = await store.audioPathFor(id);
      await _capture.start(path);

      _id = id;
      _path = path;
      _startedAt = startedAt;
      state = const RecorderState(phase: RecorderPhase.recording);
      _levels = _capture.levels().listen(_onLevel);
    } catch (error) {
      state = RecorderState(
        phase: RecorderPhase.error,
        error: 'Couldn\'t start recording: $error',
      );
    }
  }

  void _onLevel(double level) {
    if (!state.isRecording || _startedAt == null) return;
    final elapsed = _now().difference(_startedAt!);
    final levels = [...state.levels, level];
    if (levels.length > _maxLevels) levels.removeRange(0, levels.length - _maxLevels);
    state = state.copyWith(elapsed: elapsed, levels: levels);
    if (elapsed >= hardLimit) unawaited(stop());
  }

  /// Stop, persist, and move to [RecorderPhase.saved].
  Future<LocalMemo?> stop() async {
    if (!state.isRecording) return null;
    state = state.copyWith(phase: RecorderPhase.stopping);
    await _levels?.cancel();
    _levels = null;

    final startedAt = _startedAt!;
    final id = _id!;
    final duration = _now().difference(startedAt);

    try {
      final path = await _capture.stop() ?? _path;
      if (duration < minDuration) {
        await _deleteQuietly(path);
        state = const RecorderState(
          phase: RecorderPhase.error,
          error: 'That was too short to be a memo. Hold on a little longer and talk.',
        );
        return null;
      }
      if (path == null || !await File(path).exists()) {
        state = const RecorderState(
          phase: RecorderPhase.error,
          error: 'The recording couldn\'t be saved. Try again.',
        );
        return null;
      }

      var savedDuration = duration;
      final trimmer = ref.read(silenceTrimmerProvider);
      if (trimmer != null) {
        final file = File(path);
        final result = trimmer.trimWav(await file.readAsBytes());
        if (result.silent) {
          await _deleteQuietly(path);
          state = const RecorderState(
            phase: RecorderPhase.error,
            error: 'Nothing was audible in that recording. Try again somewhere quieter.',
          );
          return null;
        }
        if (result.changed) {
          await file.writeAsBytes(result.bytes, flush: true);
          savedDuration = result.trimmed;
        }
      }

      final memo = LocalMemo(
        id: id,
        createdAt: startedAt,
        status: MemoStatus.pending,
        audioPath: path,
        durationMs: savedDuration.inMilliseconds,
      );
      final store = await ref.read(memoStoreProvider.future);
      await store.save(memo);
      ref.invalidate(memosProvider);

      state = RecorderState(phase: RecorderPhase.saved, elapsed: savedDuration, savedMemo: memo);
      return memo;
    } catch (error) {
      state = RecorderState(
        phase: RecorderPhase.error,
        error: 'The recording couldn\'t be saved: $error',
      );
      return null;
    } finally {
      _id = null;
      _path = null;
      _startedAt = null;
    }
  }

  /// Throw the current recording away.
  Future<void> cancel() async {
    if (!state.isRecording) return;
    await _levels?.cancel();
    _levels = null;
    await _capture.cancel();
    await _deleteQuietly(_path);
    _id = null;
    _path = null;
    _startedAt = null;
    state = const RecorderState();
  }

  /// Back to idle after a save or an error.
  void reset() => state = const RecorderState();

  Future<void> openSettings() => ref.read(micPermissionProvider).openSettings();

  Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing useful to tell the user; the file is orphaned at worst.
    }
  }
}

final recorderControllerProvider =
    NotifierProvider<RecorderController, RecorderState>(RecorderController.new);
