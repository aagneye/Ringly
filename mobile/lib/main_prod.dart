import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/env.dart';
import 'providers/api_providers.dart';

/// Entrypoint for the deployed build (release APK / Play Store).
///
/// Run/build with: flutter run -t lib/main_prod.dart
///                 flutter build apk -t lib/main_prod.dart
///
/// Points at [Env.productionBaseUrl], the Next.js API deployed on Render.
void main() {
  runApp(
    ProviderScope(
      overrides: [baseUrlProvider.overrideWithValue(Env.productionBaseUrl)],
      // No silent auto-retry: a "not configured" or offline error should show
      // straight away, and pull-to-refresh is the user's retry.
      retry: (retryCount, error) => null,
      child: const RinglyApp(),
    ),
  );
}
