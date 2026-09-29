import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/env.dart';

/// Entrypoint for the deployed build (release APK / Play Store).
///
/// Run/build with: flutter run -t lib/main_prod.dart
///                 flutter build apk -t lib/main_prod.dart
///
/// Points at Env.productionBaseUrl — filled in for real once the Next.js API
/// is deployed (Phase P of docs/flutter-migration-plan.md). Until then this
/// entrypoint exists so CI/build tooling has a stable target, even though
/// the URL itself is still a placeholder.
void main() {
  // TODO(Phase D+): pass Env.productionBaseUrl into the ApiClient providers
  // once the provider layer exists (Phase F).
  assert(Env.productionBaseUrl.isNotEmpty);
  runApp(const ProviderScope(child: RinglyApp()));
}
