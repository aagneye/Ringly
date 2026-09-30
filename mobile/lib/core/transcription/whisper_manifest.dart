import '../../data/json.dart';

/// One downloadable on-device Whisper model, mirroring an entry from
/// GET /api/models/whisper (see src/lib/whisper-manifest.ts on the server).
class WhisperModelInfo {
  const WhisperModelInfo({
    required this.id,
    required this.label,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.ramMb,
    required this.minRamGb,
  });

  final String id;
  final String label;
  final String url;
  final int sizeBytes;

  /// Expected SHA-256, or null when the server could not confirm one. A null
  /// hash means the download cannot be integrity-checked.
  final String? sha256;
  final int ramMb;
  final int minRamGb;

  /// Rounded size in whole megabytes, for display ("140 MB").
  int get sizeMb => (sizeBytes / (1024 * 1024)).round();

  factory WhisperModelInfo.fromJson(Json json) => WhisperModelInfo(
        id: readString(json, 'id'),
        label: readString(json, 'label'),
        url: readString(json, 'url'),
        sizeBytes: readInt(json, 'sizeBytes'),
        sha256: readStringOrNull(json, 'sha256'),
        ramMb: readInt(json, 'ramMb'),
        minRamGb: readInt(json, 'minRamGb'),
      );
}

/// The full catalogue returned by the manifest endpoint.
class WhisperManifest {
  const WhisperManifest({required this.models});

  final List<WhisperModelInfo> models;

  factory WhisperManifest.fromJson(Json json) => WhisperManifest(
        models: readList(json, 'models', WhisperModelInfo.fromJson),
      );
}
