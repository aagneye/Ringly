# Ringly mobile (Flutter)

The native client for [Ringly](../README.md). The Next.js app under
[`src/`](../src) is a headless API; this Flutter app is the only user-facing
surface. It talks to the API over HTTP and holds no secrets.

The one rule behind the design: **the phone does the ears, Nebius does the
thinking.** Every reasoning step (extracting fields, deciding which tools to
call, drafting email, the pre-call brief, the morning briefing) runs on NVIDIA
Nemotron via Nebius Token Factory. The phone only records, trims silence,
stores memos locally, and optionally transcribes.

Further reading:
- [`docs/mobile-architecture.md`](../docs/mobile-architecture.md): layers, routes, memo pipeline, API contract
- [`docs/on-device-transcription.md`](../docs/on-device-transcription.md): transcription modes, model delivery, RAM budget
- [`docs/session-2026-09-30.md`](../docs/session-2026-09-30.md): the decisions behind this build and the research that drove them

## What's in the app

Built for a salesperson doing 6–9 calls a day: capture has to take under ten
seconds, and every screen answers "what needs me right now?"

| Tab | What it does |
|---|---|
| **Home** | Nemotron Ultra morning briefing, "needs you now" counts, today's calls with **Brief me**, quick record, pipeline pulse (deals going quiet), integrations status, AI activity per tier, recent memos |
| **Pipeline** | Deals grouped by stage, quiet deals first, "going quiet" filter. Tap a deal to open it; long-press to move its stage |
| **Record** (raised centre button) | 16 kHz mono WAV capture with live waveform. Soft warning at 2:00, auto-stop at 2:30, clips under 2 s rejected. Type-a-note fallback |
| **Actions** (badge = pending count) | The approval queue. Email drafts open pre-filled in *your* mail app via `mailto:` and are only marked approved once it launches. Reminders: Done or Dismiss |
| **Models** | The four Nemotron tiers, what each is used for and why, with live call counts, tokens and latency from `/api/usage` |

Also:
- **What happened** (`/memo/:id`): after each memo, shows the transcript, what was understood, which contact and deal it was filed against, and every action taken. Reminders and drafts can be undone. "Nothing needed doing" is shown as a result, not an error.
- **Deal detail** (`/deal/:id`): contact, stage changer, health, Tavily company facts, a merged timeline, and the pre-call brief (Nemotron Super, never cached).
- **Drawer and Settings**: grouped Account / Connections / Voice & Transcription / Data & Privacy / AI / App. Includes a "run nightly review now" button; in production the server requires its cron secret, which the app never holds.

### Reliability: memos are never lost
1. **Persist first.** The WAV file and its metadata are written to the app support directory before any network call.
2. **Trim on device.** An energy-based voice-activity detector cuts leading and trailing silence and collapses pauses longer than 1.5 s, so fewer bytes leave the phone. Silent clips are rejected.
3. **Offline outbox.** Unsent memos drain automatically on app start, when connectivity returns, and every 60 s. Backoff is exponential (30 s doubling, capped at 30 min). After 5 failures a memo is marked failed and can be retried by hand. Memos the server rejects outright (empty, too long) fail immediately.

### Transcription modes
The default is **Cloud**: the audio is uploaded and Nemotron Omni transcribes it on Nebius. The app also has **On-device**, **Auto** and a **Local-only** switch, plus a model download manager (`GET /api/models/whisper` → Hugging Face ggml files, SHA-256 verified, never bundled because of Play's 150 MB install cap).

**On-device is not active in this build.** The engine sits behind an interface (`OnDeviceEngine`), and the default `UnavailableEngine` falls back to cloud. The `whisper_ggml` plugin needs Android NDK 29 and AGP ≥ 8.9.1 / compileSdk 36, but this project is on AGP 8.7.3. [`docs/on-device-transcription.md`](../docs/on-device-transcription.md) lists the exact steps to enable it.

### Contacts
With permission, spoken names are matched against the phone's contacts using a Dart port of the server's matcher (`src/lib/domain/contact-matching.ts`, tested with the same cases). When the server's match is uncertain, the result screen suggests the likely contact. The suggestion is informational only, because the API has no merge endpoint.

### Mock authentication
There is no real auth yet: the backend has no login endpoint. Login accepts one demo credential:

| Field | Value |
|---|---|
| Email | `test123@gmail.com` |
| Password | `test123` |

## Theme
Off-white background (`#F4F4F2`), pure-white cards / nav bar / menu button with
soft gray borders, indigo accent (`#4F46E5`). Tokens live in
`lib/core/theme/app_colors.dart`. No screen hardcodes a hex value.

## Project structure

```
lib/
  app.dart          go_router routes + RinglyApp
  main_dev.dart     emulator build → http://10.0.2.2:3000
  main_prod.dart    release build  → Env.productionBaseUrl
  core/             API client + typed errors, formatting, mailto builder,
                    audio (WAV codec, silence trimmer), contact matching,
                    transcription (manifest, download + SHA-256, policy, engine)
  data/             JSON models, repositories (one per endpoint), local memo
                    store, settings, device contacts
  providers/        Riverpod providers (API, data, memos, outbox, settings,
                    transcription, contacts, deals)
  features/         home, pipeline, recorder, memo (result, sender, outbox),
                    actions, models, deal_detail, settings, transcription,
                    contacts, auth, shared (shell, bottom bar, drawer)
```

## Dependencies added for these features
All are pinned to exact versions:
- `path_provider` 2.1.5
- `shared_preferences` 2.5.3
- `url_launcher` 6.3.2
- `connectivity_plus` 6.1.4
- `crypto` 3.0.7
- `flutter_contacts` 1.1.9+2

`connectivity_plus` and `flutter_contacts` are held at older majors because
their newest versions pull `androidx.core` 1.18, which needs AGP 8.9.1 and
compileSdk 36.

## Running it

```bash
flutter pub get
flutter run -t lib/main_dev.dart
```

Run `npm run dev` in the repo root alongside it. The login screens work
without the backend; everything else explains what's missing ("add
NEBIUS_API_KEY on the server") rather than crashing. For a release build use
`main_prod.dart`. Its `Env.productionBaseUrl` is still a placeholder until the
backend is deployed.

## Verifying

```bash
flutter analyze
flutter test                               # 239 tests, no device or network needed
flutter build apk --debug -t lib/main_dev.dart
```
