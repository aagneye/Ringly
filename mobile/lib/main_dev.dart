import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/env.dart';

/// Entrypoint for local development against the Next.js dev server running
/// on the same machine as the Android emulator.
///
/// Run with: flutter run -t lib/main_dev.dart
///
/// Requires `npm run dev` running in the Ringly repo root first — this build
/// talks to http://10.0.2.2:3000, which only resolves from inside an Android
/// emulator (it is the emulator's alias for its host machine).
void main() {
  // TODO(Phase D+): pass Env.emulatorBaseUrl into the ApiClient providers
  // once the provider layer exists (Phase F). For now this just confirms the
  // entrypoint boots the shared app shell.
  assert(Env.emulatorBaseUrl.isNotEmpty);
  runApp(const ProviderScope(child: RinglyApp()));
}
