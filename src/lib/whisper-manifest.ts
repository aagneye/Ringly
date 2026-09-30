/**
 * The catalogue of on-device Whisper models the app may download.
 *
 * The mobile client cannot ship the models inside the APK — a base model is
 * ~140 MB, larger than the whole app. Instead the app asks this endpoint what
 * models exist, then streams the chosen one straight from Hugging Face and
 * verifies it against the `sha256` here before trusting it. That check is the
 * whole point of routing the manifest through our own server: the phone learns
 * the expected hash from a source we control, not from the same CDN it is
 * about to download the bytes from.
 *
 * `sizeBytes` and `sha256` are the real values published by the whisper.cpp
 * repository (the `lfs.oid` / `lfs.size` fields from
 * https://huggingface.co/api/models/ggerganov/whisper.cpp/tree/main). They are
 * NOT invented — if a value here ever cannot be confirmed against Hugging Face
 * it must be set to `null` rather than guessed, so the client can decide
 * whether to trust an unverifiable download.
 */

export interface WhisperModelManifestEntry {
  /** Stable id the client stores as `<id>.bin` on disk. */
  id: string;
  /** Human label for the settings row. */
  label: string;
  /** Direct download URL (Hugging Face LFS resolve link). */
  url: string;
  /** Exact byte length of the file, from Hugging Face LFS metadata. */
  sizeBytes: number;
  /** SHA-256 of the file (the LFS `oid`), or null if it could not be confirmed. */
  sha256: string | null;
  /** Approximate peak RAM the model needs while transcribing, in MB. */
  ramMb: number;
  /** Minimum device RAM we recommend before offering this model, in GB. */
  minRamGb: number;
}

export interface WhisperManifest {
  models: WhisperModelManifestEntry[];
}

/**
 * The two English-only models small enough to run on a phone. Tiny is the
 * safe default for low-RAM devices; base trades size for noticeably better
 * accuracy and is the app's default `whisperModelId`.
 */
export function whisperManifest(): WhisperManifest {
  return {
    models: [
      {
        id: 'tiny.en',
        label: 'Tiny (English)',
        url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
        sizeBytes: 77704715,
        sha256: '921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f',
        ramMb: 273,
        minRamGb: 3,
      },
      {
        id: 'base.en',
        label: 'Base (English)',
        url: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
        sizeBytes: 147964211,
        sha256: 'a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002',
        ramMb: 500,
        minRamGb: 4,
      },
    ],
  };
}
