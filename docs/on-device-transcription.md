# On-device transcription

## The split: ears on the phone, reasoning on Nebius

Ringly's whole value is the agent — Nemotron deciding which tools a memo needs
and acting. That reasoning **always** runs on Nebius Token Factory, because the
hackathon requires it and no Nemotron tier fits on a phone (Nano 4B alone is
~2.2–2.5 GB at Q4 before KV cache; Nano Omni GGUF needs ~28 GB). See
`docs/session-2026-09-30.md` for the full sizing.

The one piece that *could* run on-device is transcription — turning the WAV
into text. Doing it on the phone is a privacy and offline win: when it's on,
the audio never leaves the device; only the transcript is sent. So:

> **The phone does the ears (optionally). Nebius always does the thinking.**

This is why the split is cheap to build: `POST /api/notes` already accepts a
JSON transcript as a first-class input (not a fallback). On-device
transcription just fills in that transcript before send — no backend change.

## Modes

Set in Settings, persisted with `shared_preferences`:

| Mode | Behaviour |
|---|---|
| `cloud` | Always upload the WAV; Nemotron Omni transcribes on Nebius. Default. |
| `onDevice` | Transcribe on the phone; send text only. Requires a model installed. |
| `auto` | On-device if a model is present and the device can run it; otherwise cloud. |
| `local-only` | On-device only; never upload audio. If no model is present, prompt to download or type the note. |

## Decision matrix

| Mode | Model installed? | Online? | What happens |
|---|---|---|---|
| cloud | — | yes | Upload WAV → Omni transcribes on Nebius |
| cloud | — | no | Memo queued in the outbox, drained when back online |
| onDevice | yes | either | Transcribe on phone → send transcript when online |
| onDevice | no | either | Prompt to download the model, or type the note instead |
| auto | yes | either | Transcribe on phone → send transcript |
| auto | no | yes | Upload WAV → Omni |
| auto | no | no | Queue in outbox |
| local-only | yes | either | Transcribe on phone; only text ever leaves |
| local-only | no | either | Never upload audio; prompt to download or type |

## Model delivery

Models are **never bundled** in the APK — Google Play caps the initial install
at 150 MB and Whisper `base` alone is ~142 MB.

1. App fetches `GET /api/models/whisper` — a manifest of available ggml files
   with their sizes, URLs (Hugging Face ggml releases) and **SHA-256** hashes.
2. The download manager downloads the chosen file to the app support
   directory.
3. It verifies the SHA-256 against the manifest before the model is ever used;
   a mismatch fails the download.
4. The file is stored in the app-support dir (private to the app) and
   **excluded from device backup**, so a 150 MB blob is never uploaded to the
   user's cloud backup.

## RAM budget

| Component | Peak RAM |
|---|---|
| Flutter runtime + app | ~200 MB |
| Whisper `base` | ~500 MB |
| **Total** | **≈ 700 MB peak** |

`base` is the default target. On devices with under 4 GB RAM, fall back to
`tiny` (~273 MB), keeping the total comfortably below the pressure point where
Android starts killing the app.

## The engine interface, and how to enable a real one

Transcription sits behind an interface so the rest of the app doesn't care
whether a real model exists. Today the concrete implementation is
`UnavailableEngine` (it reports "no on-device transcription"), and
`memoPrepareProvider` defaults to a no-op — so every memo goes to the cloud.

`whisper_ggml` 2.6.0 was evaluated but shelved: it requires Android NDK
`29.0.13113456` (license not accepted on the build machine) and pulls
`androidx.core` 1.18, which needs AGP 8.9.1 / compileSdk 36 — the project is on
AGP 8.7.3.

To turn on a real engine:

1. **Accept the NDK 29 license:**
   ```
   sdkmanager --licenses
   ```
   (and install `ndk;29.0.13113456`).
2. **Upgrade the Android toolchain** — set AGP to ≥ `8.9.1` in
   `android/settings.gradle.kts` (the `com.android.application` plugin version)
   and raise `compileSdk` to `36` in `android/app/build.gradle.kts`.
3. **Add the dependency** — `whisper_ggml` in `pubspec.yaml`.
4. **Implement `OnDeviceEngine`** against `whisper_ggml`, satisfying the same
   engine interface `UnavailableEngine` implements today.
5. **Override the provider** — point `onDeviceEngineProvider` at the new
   implementation (and wire `memoPrepareProvider` to use it when the mode and
   an installed model allow), so `MemoSender` sends a transcript instead of
   audio.

Nothing above the interface changes: the recorder, the memo store, the outbox
and the result screen all work identically whether the transcript came from the
phone or from Nemotron Omni.
