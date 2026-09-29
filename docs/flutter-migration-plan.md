# Ringly → Flutter Migration Plan

Status: **approved, not yet implemented**. This file is the single source of
truth for the migration. It is written so a fresh Kiro CLI session (no prior
chat memory) can pick this up and execute it end to end without asking the
user to re-explain anything.

If you are a new session reading this: start at "How to resume" at the bottom.

---

## 1. Decision record

### 1.1 Why Flutter instead of the current Next.js web app

The user's product reasoning: a salesperson finishes a call and needs to open
Ringly and start talking in the fewest possible steps — ideally via a phone
home-screen shortcut, a Quick Settings tile, or (later, iOS-only) a Siri
Shortcut. A browser tab cannot register OS-level shortcuts or a lock-screen
quick action. A native app can. That gap is real and is the reason for this
migration, made with the user's explicit sign-off after a website-vs-native
tradeoff discussion.

### 1.2 What is being reused vs. rebuilt

**Reused as-is (do not rewrite):** everything under `src/lib/` except nothing
— the entire backend brain stays:
- `src/lib/agent/**` — the extract → resolve → plan → execute loop, all 5
  tools, all prompts.
- `src/lib/db/**` — Drizzle schema, 10 tables.
- `src/lib/domain/**` — drift detection, date parsing, contact matching.
- `src/lib/nebius/**` — Token Factory client, chat wrapper, model tiers,
  transcription.
- `src/app/api/**` — all 13 API routes (see section 3).
- `tests/**` — all 289 tests, untouched.

**Deleted:** everything under `src/app/**` that is a *page* (not `api/`), and
everything under `src/components/**`. These are Next.js/React UI and have no
Flutter equivalent to reuse — they are reference material for behavior, not
code to port.

Rationale for reuse: the thing the hackathon judges (Nemotron tool-selection,
the three-tier model routing, structured output) lives entirely in the
reused layer. Rewriting it in Dart would spend the remaining time before the
Oct 30 deadline re-testing logic that already has 289 passing tests, for zero
judging benefit — the rules judge the agent's behavior, not the language of
the client.

### 1.3 Backend deployment decision

The Next.js app becomes a **headless API server** — no pages, only
`/api/*` routes — deployed to a public URL. The Flutter app is a pure client;
it never holds `NEBIUS_API_KEY` or `DATABASE_URL`. This is a hard security
requirement: those secrets in an APK can be extracted by anyone with the file.

Deployment target: **Vercel** (the codebase already assumes a
Vercel-shaped environment — see `CRON_SECRET` comments referencing Vercel
Cron in `src/lib/api.ts`). Alternative considered and rejected for now:
containerizing on Nebius AI Cloud — more setup steps, no functional
difference for judging, can be revisited after the Flutter app works.

### 1.4 Platform decision

**Android only**, built and run against the existing `Pixel_9_Pro` AVD
(confirmed installed: `flutter emulators` lists it; Flutter 3.32.2 / Dart
3.8.1 confirmed installed). iOS/Siri requires a Mac and is explicitly out of
scope on this Windows machine — noted as a "what's next" line for the demo
video, not built.

Fast-launch mechanisms chosen to replace "open app → find contact → type
notes" friction, in order of effort:
1. Android **home screen App Shortcut** ("New memo") — long-press the app
   icon, jumps straight to the recorder screen skipping the Today screen.
2. Android **Quick Settings tile** — a toggle in the swipe-down panel that
   launches the recorder directly, closest thing to a one-tap capture on
   Android without OS-level voice trigger support.
3. Google Assistant App Actions — **stretch goal, not in the 100-commit
   plan**, flagged as future work only.

### 1.5 State management & networking (Flutter side)

- **Riverpod** for state management (well-established, testable, avoids
  boilerplate of Bloc for a solo hackathon build).
- **Dio** for HTTP (interceptor support for base URL switching between the
  Android emulator's host alias `10.0.2.2` and the deployed prod URL).
- **go_router** for navigation (named routes map 1:1 to the page list in
  section 4).
- **freezed + json_serializable** for typed API response models — the Zod
  schemas already define the wire shape server-side; Dart models mirror them
  by hand (no shared codegen across languages, so this is done once and
  pinned to the API contract in section 3).
- Audio recording: **record** package (mic capture to a file) +
  **just_audio** or native playback widget for the "review before sending"
  step if added later — MVP just uploads the recorded file.

### 1.6 What is explicitly NOT built in this pass

- iOS app / Siri Shortcuts (needs a Mac).
- Google Assistant App Actions integration.
- Offline queueing of memos recorded with no network.
- Push notifications for due reminders (README already cut this for the web
  app for the same reason — service worker/FCM lifecycle risk vs. hackathon
  timeline).

---

## 2. New repository structure

The Next.js app keeps its current root layout (pages deleted, `api/`
untouched). A new `mobile/` directory holds the Flutter project.

```
Ringly/
  src/
    app/
      api/                 <- UNCHANGED, all 13 routes kept
      layout.tsx           <- DELETED (was page shell)
      page.tsx             <- DELETED (was Today page)
      global-error.tsx     <- DELETED
      robots.ts            <- DELETED (no longer a crawlable site)
      models/page.tsx      <- DELETED
      pipeline/page.tsx    <- DELETED
      pipeline/loading.tsx <- DELETED
      deals/[id]/page.tsx  <- DELETED
      deals/[id]/not-found.tsx <- DELETED
    components/            <- DELETED (entire directory, all 14 files)
    lib/                   <- UNCHANGED
  tests/                   <- UNCHANGED
  docs/
    flutter-migration-plan.md   <- this file
  mobile/                  <- NEW Flutter project (flutter create mobile)
    lib/
      main.dart
      app.dart                       # MaterialApp + go_router setup
      core/
        api_client.dart              # Dio instance, base URL selection
        env.dart                     # base URL constants (emulator vs prod)
        errors.dart                  # ApiErrorBody mirror + typed exceptions
      models/
        note_result.dart             # mirrors MemoResult (process-memo.ts)
        deal.dart                    # mirrors loadBoard / loadDealDetail rows
        deal_detail.dart
        reminder.dart
        event.dart
        draft.dart
        briefing.dart
        precall_brief.dart
        ask_result.dart
        usage.dart
        health.dart
      repositories/
        notes_repository.dart        # POST /api/notes (multipart + json)
        today_repository.dart        # GET /api/today
        deals_repository.dart        # GET/PATCH /api/deals, /api/deals/:id
        precall_repository.dart      # GET /api/deals/:id/brief
        drafts_repository.dart       # POST /api/drafts/:id
        reminders_repository.dart    # PATCH /api/reminders/:id
        events_repository.dart       # GET /api/events/:id/ics
        ask_repository.dart          # POST /api/ask
        briefing_repository.dart     # GET /api/briefing
        review_repository.dart       # POST /api/review
        usage_repository.dart        # GET /api/usage
        health_repository.dart       # GET /api/health
      providers/
        (one Riverpod provider file per repository, same names + _provider)
      features/
        recorder/
          recorder_page.dart         # record memo screen
          recorder_controller.dart
          widgets/
            record_button.dart
            result_summary.dart      # shows extraction + actions taken
        today/
          today_page.dart
          widgets/
            due_reminders_panel.dart
            todays_events_panel.dart
            pending_drafts_panel.dart
            briefing_card.dart
            setup_notice_banner.dart # mirrors health-check "not configured" UX
        pipeline/
          pipeline_page.dart         # kanban board, drag-to-change-stage
          widgets/
            deal_card.dart
            stage_column.dart
        deal_detail/
          deal_detail_page.dart
          widgets/
            deal_timeline.dart
            precall_brief_panel.dart
            ask_box.dart
        drafts/
          draft_review_page.dart     # approve/discard email draft
        models/
          models_page.dart           # tier usage table, mirrors /models
        shared/
          widgets/
            error_banner.dart
            loading_view.dart
            app_shell.dart           # bottom nav: Today / Pipeline / Record / Models
      main_dev.dart                  # entrypoint pointed at 10.0.2.2 (emulator)
      main_prod.dart                 # entrypoint pointed at deployed URL
    android/
      app/
        src/main/
          AndroidManifest.xml        # shortcuts + tile service declarations
          res/xml/shortcuts.xml      # App Shortcuts definition
          kotlin/.../QuickTileService.kt  # Quick Settings tile
    test/
      (widget + repository tests, one file per repository/controller)
    pubspec.yaml
```

---

## 3. API contract (backend, unchanged — this is what Flutter consumes)

All 13 routes, confirmed by reading each file directly. Base path assumed
`{BASE_URL}` = `http://10.0.2.2:3000` on the emulator, or the deployed URL in
production.

| Method | Path | Purpose | Notes for the client |
|---|---|---|---|
| POST | `/api/notes` | Submit a memo. `multipart/form-data` with an `audio` file field (+ optional `durationSeconds`), OR `application/json` `{ transcript }`. | Returns `MemoResult`: `runId, noteId, transcript, extraction, target, report, traces, noActionReason`. Max audio 10MB, max transcript 20,000 chars. |
| GET | `/api/today` | Home screen data. | Returns `{ reminders, events, drafts, now }`. |
| GET | `/api/deals` | Kanban board. | Returns board with health/drift already computed server-side. |
| GET | `/api/deals/:id` | Deal detail. | 404 `deal_not_found` if missing. |
| PATCH | `/api/deals/:id` | Manual edit (stage/title/nextAction/budget). | Body: any subset of `{ stage, title, nextAction, budget }`. Stage change is audit-logged as `source: 'manual'`. |
| GET | `/api/deals/:id/brief` | Pre-call brief. | Never cached server-side; expect ~seconds latency (Balanced tier). |
| POST | `/api/drafts/:id` | Approve or discard a drafted email. | Body: `{ action: 'approve'|'discard', subject?, body? }`. "Approve" does NOT send email — client must open the user's mail app via a `mailto:` link/intent after approval. |
| PATCH | `/api/reminders/:id` | Update reminder status. | Body: `{ status: 'done'|'dismissed'|'pending' }`. |
| GET | `/api/events/:id/ics` | Download calendar file. | Returns `text/calendar`; client must hand this to Android's calendar intent / file share, since Ringly has no calendar integration. |
| POST | `/api/ask` | "What's happening with Priya?" | Body: `{ question }`, max 500 chars. |
| GET | `/api/briefing` | Morning briefing (Ultra tier). | `?force=1` bypasses daily cache. |
| POST | `/api/review` | Nightly pipeline review. | Guarded by `Authorization: Bearer $CRON_SECRET` in production; the "run now" button in the UI calls this directly. |
| GET | `/api/usage` | Model tier usage stats. | Powers the Models page: `{ tiers, recent, actionCounts, totals }`. |
| GET | `/api/health` | Config check. | `{ ok, nebius, database, tavily }` booleans — drives the setup-notice banner. |

Error shape (all routes, via `src/lib/api.ts`):
```json
{ "error": "message", "code": "machine_readable_code", "hint": "optional fix" }
```
Common codes to handle explicitly in the Dart error mapper: `nebius_not_configured`,
`database_not_configured`, `transcription_unavailable`, `deal_not_found`,
`bad_model_output`, `model_call_failed`, `invalid_body`, `missing_audio`,
`empty_audio`, `audio_too_large`, `empty_transcript`, `missing_transcript`,
`transcript_too_large`, `draft_not_found`, `reminder_not_found`,
`event_not_found`, `missing_question`, `question_too_large`, `unauthorised`,
`internal_error`.

The irreversible-action rule (from `src/lib/agent/tools/types.ts`): every tool
definition carries a flag distinguishing reversible actions (applied
immediately server-side: `update_deal`, `set_reminder`, `schedule_event`,
`lookup_company`) from the one irreversible action (`draft_email`, staged for
human approval). The Flutter UI must preserve this distinction visually —
reversible actions show as "done", the email draft shows as "needs your
approval" with Approve/Discard buttons.

---

## 4. Full page & feature inventory

One-to-one mapping from the current Next.js pages/components to Flutter
screens. Nothing is added; nothing is dropped, except Siri/App Actions
(explicitly deferred, section 1.6).

| # | Flutter page | Replaces (web) | Features on this screen |
|---|---|---|---|
| 1 | **Recorder** | `recorder.tsx`, `use-recorder.ts`, `action-result.tsx` | Mic record button with duration; "type instead" text fallback; submit to `/api/notes`; show `ResultSummary` — extraction fields, each tool call taken with reversible/needs-approval styling, `noActionReason` if the planner did nothing. Entry point from App Shortcut + Quick Settings tile. |
| 2 | **Today** | `page.tsx`, `today-view.tsx`, `today-panels.tsx`, `briefing-panel.tsx` | Due reminders list (mark done/dismiss), today's scheduled events (download .ics), pending drafts list (tap → Draft Review page), briefing card (fetch-on-mount, "regenerate" = `?force=1`), setup-notice banner when `/api/health` reports missing config. |
| 3 | **Pipeline** | `pipeline/page.tsx`, `kanban-board.tsx`, `deal-card.tsx` | Kanban columns per `DEAL_STAGES`; drag a card → `PATCH /api/deals/:id` stage change; each card shows drift/health signal computed server-side; "Run nightly review now" button → `POST /api/review`. |
| 4 | **Deal detail** | `deals/[id]/page.tsx`, `deal-timeline.tsx`, `precall-brief.tsx`, `ask-box.tsx` | Deal fields (editable via PATCH); timeline of agent + manual actions in order; pre-call brief panel (fetched fresh every visit, no cache); "Ask" box for free-text questions about this deal/pipeline. |
| 5 | **Draft review** | `draft-review.tsx` | Shows drafted email subject/body, editable before decision; Approve → opens mail app via `mailto:` intent + calls `POST /api/drafts/:id` `{action:'approve'}`; Discard → same endpoint with `{action:'discard'}`. |
| 6 | **Models** | `models/page.tsx`, `model-trace.tsx` | Tier table (Lightning/Super/Ultra/Omni) with live call counts, token totals, avg latency, failure counts from `/api/usage`; recent call list; static rationale text per tier (mirrors `TIER_RATIONALE`). |
| 7 | **App shell / nav** | `nav-bar.tsx`, `layout.tsx` | Bottom navigation bar: Today, Pipeline, Record (center, prominent), Models. Deal detail and Draft review are pushed, not tabs. |
| 8 | **Not-found** | `deals/[id]/not-found.tsx`, `global-error.tsx` | Generic error/empty states, reused as a shared widget rather than per-page. |

Android-specific additions (no web equivalent):
- App Shortcut "New memo" → deep-links straight to page 1.
- Quick Settings tile → launches the app on page 1.
- `mailto:` intent handling for page 5's Approve action.
- Android share sheet / calendar intent for page 2's `.ics` download.

---

## 5. Commit plan (100+ atomic commits)

Follows the repo's existing atomic-commit convention (`.kiro/steering/git-commits.md`,
`.cursor/rules/commits.mdc`): one logical change per commit, `type(scope): description`.
Grouped into phases; each bullet is one commit unless marked "(N commits)".

**Phase A — Strip the web UI (≈10 commits)**
- `chore(app): remove page.tsx (Today web page)`
- `chore(app): remove layout.tsx (web shell)`
- `chore(app): remove global-error.tsx`
- `chore(app): remove robots.ts`
- `chore(app): remove models/page.tsx`
- `chore(app): remove pipeline/page.tsx and loading.tsx` (2 commits)
- `chore(app): remove deals/[id]/page.tsx and not-found.tsx` (2 commits)
- `chore(components): remove src/components directory` (1 commit, tracked as
  a deletion-only commit since it's one logical removal)
- `docs(readme): update README for headless-API architecture`

**Phase B — Backend adjustments for headless mode (≈3 commits, revised)**

Three items from the original plan were checked and found unnecessary —
documented here rather than silently dropped:
- `next.config.ts` config (body size limit, security headers) all applies to
  API routes too, not just pages. Nothing page-only to remove. **Skipped.**
- CORS: native Android HTTP calls (Dio) are not subject to CORS — that's a
  browser-enforced restriction, not a server one. Confirmed no existing CORS
  code in `src/` (`grep` for `Access-Control|cors|CORS` returned zero
  matches) — there is nothing to add for a native client. **Skipped.**
- API-route-level smoke tests: the existing suite deliberately tests only
  pure logic with no network/database (per README), not route handlers.
  Adding route-handler tests would need a different mocking setup than the
  rest of `tests/` uses. Left as a follow-up, not forced in to hit a count.
  **Skipped.**

Commits actually done:
- `chore(env): add mobile-facing env var documentation to .env.example`
- `docs(readme): update README for headless-API architecture`
- `chore(ci): update workflow if page-removal breaks a build step` (only if
  CI actually breaks — checked against `.github/workflows/ci.yml`)

**Phase C — Flutter project scaffold (≈12 commits, versions corrected during implementation)**

Exact dependency versions actually pinned (resolved against Flutter 3.32.2 /
Dart 3.8.1 via `flutter pub add --dry-run` and `flutter pub get`, not guessed):
`flutter_riverpod 3.3.2`, `riverpod_annotation 4.0.3`, `dio 5.11.1`,
`go_router 17.0.0`, `freezed_annotation 3.1.0`, `json_annotation 4.9.0`,
`record 6.2.1`, `permission_handler 13.0.2`. Dev: `flutter_lints ^5.0.0`
(unchanged from scaffold), `build_runner 2.7.1` (not 2.15.x — that range
requires `build >=4.0.8` which needs Dart SDK `>=3.11.0`, newer than this
project's `3.8.1`, and separately conflicts with `flutter_test`'s bundled
`test_api` version; resolved by following pub's own downgrade suggestion),
`freezed 3.2.3`, `json_serializable 6.11.2`.
- `chore(mobile): flutter create mobile project`
- `chore(mobile): add riverpod state management dependencies to pubspec.yaml`
- `chore(mobile): add dio HTTP client dependency to pubspec.yaml`
- `chore(mobile): add go_router navigation dependency to pubspec.yaml`
- `chore(mobile): add freezed and json_annotation dependencies to pubspec.yaml`
- `chore(mobile): add record and permission_handler dependencies to pubspec.yaml`
- `chore(mobile): add build_runner, freezed, json_serializable dev dependencies`
- `chore(mobile): configure build_runner for freezed/json_serializable`
  — **checked and skipped**: freezed and json_serializable ship their own
  default builder configuration; a custom `build.yaml` is only needed to
  override non-default behavior (e.g. custom part-file naming), which this
  project doesn't need. Each model file declares
  `part 'x.freezed.dart'; part 'x.g.dart';` directly — that's the entire
  setup required.
- `feat(mobile/core): add env.dart with emulator/prod base URL constants`
- `feat(mobile/core): add api_client.dart Dio instance with interceptors`
- `feat(mobile/core): add errors.dart typed exception hierarchy`
- `feat(mobile): add main_dev.dart entrypoint`
- `feat(mobile): add main_prod.dart entrypoint`
- `feat(mobile): add app.dart with MaterialApp + go_router skeleton`
- `feat(mobile): add app_shell.dart bottom navigation scaffold`

**Phase D — Data models, one commit per model (12 commits)**
- `feat(mobile/models): add note_result.dart`
- `feat(mobile/models): add deal.dart`
- `feat(mobile/models): add deal_detail.dart`
- `feat(mobile/models): add reminder.dart`
- `feat(mobile/models): add event.dart`
- `feat(mobile/models): add draft.dart`
- `feat(mobile/models): add briefing.dart`
- `feat(mobile/models): add precall_brief.dart`
- `feat(mobile/models): add ask_result.dart`
- `feat(mobile/models): add usage.dart`
- `feat(mobile/models): add health.dart`
- `feat(mobile/models): add api_error_body.dart`

**Phase E — Repositories, one commit per endpoint (13 commits)**
- `feat(mobile/repositories): add notes_repository.dart (POST /api/notes)`
- `feat(mobile/repositories): add today_repository.dart (GET /api/today)`
- `feat(mobile/repositories): add deals_repository.dart (GET /api/deals)`
- `feat(mobile/repositories): add deal detail fetch to deals_repository.dart (GET /api/deals/:id)`
- `feat(mobile/repositories): add deal patch to deals_repository.dart (PATCH /api/deals/:id)`
- `feat(mobile/repositories): add precall_repository.dart (GET /api/deals/:id/brief)`
- `feat(mobile/repositories): add drafts_repository.dart (POST /api/drafts/:id)`
- `feat(mobile/repositories): add reminders_repository.dart (PATCH /api/reminders/:id)`
- `feat(mobile/repositories): add events_repository.dart (GET /api/events/:id/ics)`
- `feat(mobile/repositories): add ask_repository.dart (POST /api/ask)`
- `feat(mobile/repositories): add briefing_repository.dart (GET /api/briefing)`
- `feat(mobile/repositories): add review_repository.dart (POST /api/review)`
- `feat(mobile/repositories): add usage_repository.dart (GET /api/usage)`
- `feat(mobile/repositories): add health_repository.dart (GET /api/health)`

**Phase F — Riverpod providers, one commit per repository (13 commits)**
Mirrors phase E, e.g. `feat(mobile/providers): add notes_provider.dart`, ...
through all 13.

**Phase G — Recorder feature (≈8 commits)**
- `feat(mobile/recorder): add recorder_page.dart skeleton`
- `feat(mobile/recorder): add record_button.dart with mic permission handling`
- `feat(mobile/recorder): wire audio capture via record package`
- `feat(mobile/recorder): add type-instead text fallback input`
- `feat(mobile/recorder): add recorder_controller.dart submit flow`
- `feat(mobile/recorder): add result_summary.dart rendering extraction + tool results`
- `feat(mobile/recorder): distinguish reversible vs approval-needed actions in result_summary.dart`
- `test(mobile/recorder): add recorder_controller_test.dart`

**Phase H — Today feature (≈8 commits)**
- `feat(mobile/today): add today_page.dart skeleton`
- `feat(mobile/today): add due_reminders_panel.dart with done/dismiss actions`
- `feat(mobile/today): add todays_events_panel.dart with .ics download`
- `feat(mobile/today): add pending_drafts_panel.dart`
- `feat(mobile/today): add briefing_card.dart with force-refresh`
- `feat(mobile/today): add setup_notice_banner.dart driven by health_provider`
- `feat(mobile/today): wire today_page.dart to today_provider`
- `test(mobile/today): add today_page_test.dart`

**Phase I — Pipeline feature (≈7 commits)**
- `feat(mobile/pipeline): add pipeline_page.dart skeleton`
- `feat(mobile/pipeline): add stage_column.dart`
- `feat(mobile/pipeline): add deal_card.dart with drift/health indicator`
- `feat(mobile/pipeline): add drag-to-change-stage gesture handling`
- `feat(mobile/pipeline): wire stage change to deals_provider PATCH call`
- `feat(mobile/pipeline): add run-nightly-review button calling review_provider`
- `test(mobile/pipeline): add pipeline_page_test.dart`

**Phase J — Deal detail feature (≈8 commits)**
- `feat(mobile/deal_detail): add deal_detail_page.dart skeleton`
- `feat(mobile/deal_detail): add editable deal fields (title, nextAction, budget)`
- `feat(mobile/deal_detail): add deal_timeline.dart`
- `feat(mobile/deal_detail): add precall_brief_panel.dart`
- `feat(mobile/deal_detail): add ask_box.dart`
- `feat(mobile/deal_detail): wire ask_box.dart to ask_provider`
- `feat(mobile/deal_detail): wire page to deals_provider detail fetch`
- `test(mobile/deal_detail): add deal_detail_page_test.dart`

**Phase K — Draft review feature (≈5 commits)**
- `feat(mobile/drafts): add draft_review_page.dart skeleton`
- `feat(mobile/drafts): add editable subject/body fields`
- `feat(mobile/drafts): add approve action with mailto intent launch`
- `feat(mobile/drafts): add discard action`
- `test(mobile/drafts): add draft_review_page_test.dart`

**Phase L — Models feature (≈5 commits)**
- `feat(mobile/models_page): add models_page.dart skeleton`
- `feat(mobile/models_page): add tier usage table widget`
- `feat(mobile/models_page): add recent calls list widget`
- `feat(mobile/models_page): add static tier rationale text`
- `test(mobile/models_page): add models_page_test.dart`

**Phase M — Shared widgets & error handling (≈6 commits)**
- `feat(mobile/shared): add error_banner.dart mapping API error codes to messages`
- `feat(mobile/shared): add loading_view.dart`
- `feat(mobile/shared): wire app_shell.dart bottom nav to all 4 top-level pages`
- `feat(mobile/shared): add not_found_view.dart`
- `feat(mobile/shared): add global error boundary via go_router errorBuilder`
- `test(mobile/shared): add error_banner_test.dart`

**Phase N — Android native integration (≈8 commits)**
- `feat(android): add App Shortcut "New memo" in shortcuts.xml`
- `feat(android): declare shortcuts in AndroidManifest.xml`
- `feat(android): add QuickTileService.kt for Quick Settings tile`
- `feat(android): register tile service in AndroidManifest.xml`
- `feat(android): request RECORD_AUDIO permission at runtime`
- `feat(android): add deep-link handling from shortcut/tile to recorder route`
- `feat(android): add mailto intent helper for draft approval`
- `feat(android): add calendar/.ics share intent helper`

**Phase O — Emulator run & verification (≈6 commits)**
- `chore(mobile): add flutter_lints and fix analyzer warnings`
- `chore(mobile): run flutter test and fix failures` (only if failures found)
- `docs(mobile): add mobile/README.md with run instructions (emulator + prod)`
- `chore(ci): add flutter workflow (analyze + test) to .github/workflows`
- `docs(readme): update root README with mobile app section`
- `chore(mobile): pin all pubspec.yaml dependency versions exactly`

**Phase P — Deployment (≈4 commits)**
- `chore(deploy): add vercel.json / deployment config for headless API`
- `docs(deploy): document CRON_SECRET and env var setup for production`
- `chore(mobile): point main_prod.dart at deployed URL`
- `docs(readme): add deployed API URL and demo instructions`

Running total: **≈121 commits** across phases A–P. Each phase's exact count
may shift by ±1–2 as work proceeds (e.g. if a model needs a follow-up fix
commit) — the rule from `.kiro/steering/git-commits.md` still applies:
crashes/fixes get their own commit, never folded into the original.

---

## 6. Verification plan

- `npm run test` / `npm run typecheck` / `npm run lint` still pass after
  Phase A/B (backend untouched aside from page deletion — should be a no-op
  for these commands since pages aren't covered by the test suite per the
  README: "289+ tests, no network or database required").
- `flutter analyze` clean and `flutter test` passing after each feature phase
  (G through M) before moving to the next phase.
- Manual run on `Pixel_9_Pro` emulator after Phase G (recorder) as the first
  real end-to-end check: `flutter emulators --launch Pixel_9_Pro`, then
  `flutter run -t lib/main_dev.dart`, with the Next.js dev server running
  locally so the emulator (`10.0.2.2:3000`) reaches it.
- Full manual pass through all 8 pages (section 4) after Phase N.
- Deployment smoke test after Phase P: hit `/api/health` on the deployed URL
  from `main_prod.dart` build.

---

## How to resume in a new session

1. Read this file in full before touching code.
2. Check current repo state: `git log --oneline -20` and `git status` to see
   which phase was reached (commit messages follow the `type(scope):` plan
   above, so the last commit tells you the last completed step).
3. Check `mobile/` existence and `flutter --version` / `flutter emulators` to
   confirm environment is still as described in section 1.4.
4. Continue from the next uncompleted commit in section 5, in order. Do not
   skip phases — each depends on the previous (models before repositories,
   repositories before providers, providers before pages).
5. Every commit must be atomic per `.kiro/steering/git-commits.md` — one file
   or one tightly-scoped logical change, never batched.
6. Re-run the verification commands in section 6 relevant to the phase just
   finished before starting the next phase.
