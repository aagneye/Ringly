import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/transcription/whisper_manifest.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/whisper_manifest_repository.dart';
import '../../providers/api_providers.dart';
import '../../providers/transcription_providers.dart';

/// Settings-screen-only providers, kept out of api_providers.dart (which
/// another agent owns) so both can evolve without stepping on each other.

/// Runs the nightly review on demand (the "Run nightly review now" button).
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(apiClientProvider)),
);

/// The catalogue of downloadable on-device models.
final whisperManifestRepositoryProvider = Provider<WhisperManifestRepository>(
  (ref) => WhisperManifestRepository(ref.watch(apiClientProvider)),
);

/// The model catalogue, fetched from the server.
final whisperManifestProvider = FutureProvider<WhisperManifest>(
  (ref) => ref.watch(whisperManifestRepositoryProvider).fetch(),
);

/// The ids of every model already downloaded and verified on this device.
/// Invalidate after a download or delete completes.
final installedModelIdsProvider = FutureProvider<List<String>>((ref) async {
  final downloader = await ref.watch(modelDownloadServiceProvider.future);
  return downloader.installedIds();
});
