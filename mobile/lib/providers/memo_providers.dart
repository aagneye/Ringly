import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/memo/local_memo.dart';
import '../data/memo/local_memo_store.dart';
import '../features/recorder/audio_capture.dart';

/// "Now", injectable so timers and backoff can be tested deterministically.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The on-device memo store, rooted in the app support directory (private to
/// the app and excluded from media scanners).
final memoStoreProvider = FutureProvider<LocalMemoStore>((ref) async {
  final base = await getApplicationSupportDirectory();
  return LocalMemoStore(Directory('${base.path}/memos'));
});

final audioCaptureProvider = Provider<AudioCapture>((ref) {
  final capture = RecordAudioCapture();
  ref.onDispose(capture.dispose);
  return capture;
});

final micPermissionProvider = Provider<MicPermission>(
  (ref) => const PlatformMicPermission(),
);

/// Every memo on the device, newest first. Invalidate after any write.
final memosProvider = FutureProvider<List<LocalMemo>>((ref) async {
  final store = await ref.watch(memoStoreProvider.future);
  return store.list();
});
