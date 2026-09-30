import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/memo/local_memo.dart';

/// Runs on a memo just before it is sent, and may return a changed copy.
///
/// This is where on-device transcription plugs in: when it's enabled and a
/// model is present, the hook fills in `transcript`, so [MemoSender] sends
/// text and the audio never leaves the phone. The default does nothing, which
/// means "upload the audio and let Nemotron Omni transcribe it on Nebius".
typedef MemoPrepare = Future<LocalMemo> Function(LocalMemo memo);

final memoPrepareProvider = Provider<MemoPrepare>((ref) => (memo) async => memo);
