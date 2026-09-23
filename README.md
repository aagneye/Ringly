# Ringly

**Talk for a minute after a client call. Ringly decides what to do and does it.**

Built for the [Nebius x NVIDIA Global AI Hackathon](https://nebiusglobalaihackathon.devpost.com/) — Best Apps and Agents track.

MIT licensed — see [LICENSE](./LICENSE).

---

## What it does

Freelancers, consultants and solo salespeople know they should log every client
call into a CRM. They never do, because the friction (open app → find contact →
type notes → set a reminder) is bigger than the payoff in the moment. Ringly
removes every step except talking:

1. You finish a call. You open Ringly and talk for 30–90 seconds in your own words.
2. Ringly transcribes it, decides what the memo actually requires, and acts:
   updates the deal, sets a reminder, books a meeting, drafts a follow-up email,
   looks up the client's company — or does nothing, if nothing was warranted.
3. You see exactly what happened, approve the one thing that can't be undone
   (sending an email), and get on with your day.

It also works the other way round: **before** a call, it briefs you on what this
person cares about and what you promised them last time. And overnight, while
you sleep, it reviews your whole pipeline for deals going quiet and queues
drafts for your approval by morning.

## Why this is an agent, not a pipeline

The code never says "always extract, always draft an email." Nemotron is handed
a toolbox — `update_deal`, `set_reminder`, `schedule_event`, `draft_email`,
`lookup_company` — and **the model decides** which of them a given memo needs.
One memo might trigger four actions; another, none at all. See
[`src/lib/agent/prompts/planner.ts`](./src/lib/agent/prompts/planner.ts).

The one irreversible action — sending an email — is never taken automatically.
Ringly drafts it and stages it for a human tap. Everything reversible (a
reminder, a deal update, a calendar entry) is applied immediately. See
[`src/lib/agent/tools/types.ts`](./src/lib/agent/tools/types.ts) for how that
rule is encoded as a flag on every tool.

## How Nemotron and Token Factory were used

Every model call in this project runs on **NVIDIA Nemotron, served by Nebius
Token Factory**, through the OpenAI-compatible API. Three tiers are used
deliberately, matched to what each task actually needs — this is the "let
Nano/Super do fast calls, Ultra do real reasoning" pattern the hackathon brief
itself recommends:

| Tier | Model | Used for | Why |
|---|---|---|---|
| Fast | `nvidia/Nemotron-3_5-Lightning` | Extracting structured fields from every memo | Runs on every single memo; schema-constrained output, latency matters far more than model depth |
| Balanced | `nvidia/nemotron-3-super-120b-a12b` | Deciding which tools to call; drafting emails; the pre-call brief; answering questions | Tone and judgement matter; single-turn generation, not worth Ultra's cost |
| Reasoning | `nvidia/Nemotron-3-Ultra-550b-a55b` | The morning briefing; the nightly pipeline review | The only genuinely hard multi-step judgement in the product — picking 2–3 things that matter out of a whole pipeline |
| Omni | `nvidia/nemotron-3-nano-omni` | Transcribing the voice memo | Native audio understanding (built on NVIDIA Parakeet), tried before falling back to a conventional STT endpoint |

The full mapping, with the reasoning for each choice written next to the code,
lives in [`src/lib/nebius/models.ts`](./src/lib/nebius/models.ts). The **/models**
page in the running app shows this same table plus a live count of how many
times each tier has actually been called, with token and latency totals pulled
from the database — not just a claim in this README.

Structured output uses Token Factory's `json_schema` response format
throughout, with a loose-parsing fallback
([`src/lib/nebius/json.ts`](./src/lib/nebius/json.ts)) for the cases where a
model wraps JSON in markdown or a `<think>` block anyway.

**Other Nebius services**: the nightly review (`POST /api/review`) is designed
to be triggered by **Nebius Serverless Jobs** on a schedule — it's a single
guarded HTTP endpoint, so wiring it to a Nebius scheduled job is a config
change, not a code change. It runs the same code path as the "Run the nightly
review now" button on the Pipeline page.

## Architecture

```
Browser (record UI, kanban, briefing)
        │
        ▼
Next.js 16 App Router — API routes orchestrate everything server-side
so the Nebius key never reaches the browser
        │
        ├──▶ Nebius Token Factory (Nemotron, OpenAI-compatible API)
        ├──▶ Postgres via Neon (Drizzle ORM)
        └──▶ Tavily (optional — company enrichment)
```

Single Next.js app, TypeScript throughout, no separate backend. See
[`src/lib/db/schema/`](./src/lib/db/schema/) for the ten-table schema and
[`src/lib/agent/`](./src/lib/agent/) for the agent loop, tools, and prompts.

## Running it locally

Requires Node 20.9+.

```bash
npm install
cp .env.example .env.local
# edit .env.local — see below
npm run db:push     # creates the schema in your Postgres database
npm run db:seed     # optional — adds one demo deal so the app isn't blank
npm run dev
```

Open http://localhost:3000.

### Environment variables

| Variable | Required | Where to get it |
|---|---|---|
| `NEBIUS_API_KEY` | Yes, for anything that thinks | https://tokenfactory.nebius.com |
| `DATABASE_URL` | Yes | Free Postgres at https://neon.tech |
| `TAVILY_API_KEY` | No — enrichment degrades quietly without it | https://tavily.com |
| `RINGLY_USER_NAME`, `RINGLY_USER_EMAIL`, `RINGLY_TIMEZONE` | No, sensible defaults | — |
| `CRON_SECRET` | No locally; required to call `/api/review` in production | any random string |

The app is deliberately runnable with an empty `.env.local`: the UI, the board
and the test suite all work without credentials, and each subsystem explains
what's missing rather than crashing (see
[`src/lib/api.ts`](./src/lib/api.ts)).

### Tests

```bash
npm run test        # 289+ tests, no network or database required
npm run typecheck
npm run lint
```

Every pure decision in the product — drift detection, date parsing, contact
matching, tool validation, prompt assembly — is unit tested without a live
model or database. See [`tests/`](./tests/).

## Project structure

```
src/
  app/                  Next.js routes (pages + API)
  components/           UI, client-side
  lib/
    agent/
      tools/            The toolbox: update_deal, set_reminder, schedule_event,
                         draft_email, lookup_company
      prompts/           Every system prompt, as pure testable functions
      process-memo.ts    The core loop: extract → resolve → plan → execute
      briefing.ts        The morning briefing (cached per day)
      precall.ts         The pre-call brief (never cached)
      ask.ts             "What's happening with Priya?"
      review.ts          The nightly pipeline review
      runner.ts          Executes tool calls, isolated and audited
    db/schema/           Drizzle schema, one table per file
    domain/              Pure logic: drift detection, date resolution, name matching
    nebius/              Token Factory client, chat wrapper, model tier registry
```

## What was cut, and why

- **Google Calendar integration** — Ringly owns its own calendar and exports
  any event as a `.ics` file instead. OAuth is real complexity that can fail
  live on a demo; a downloadable calendar file reaches any calendar app with
  zero consent screens.
- **Sending email directly** — Ringly drafts, the user approves via their own
  mail client (`mailto:`). This is a deliberate trust boundary, not a missing
  feature — see "Why this is an agent, not a pipeline" above.
- **Automated push notifications** — the "due today" panel on the home screen
  covers the demo; real push requires a service worker lifecycle that adds
  risk without adding to the story being judged.

## Feedback on Nebius Token Factory / NVIDIA tools

Documented in [`FEEDBACK.md`](./FEEDBACK.md).
