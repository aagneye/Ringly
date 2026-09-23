# Feedback on Nebius Token Factory and NVIDIA tools

Written honestly, during the build, rather than reverse-engineered for the
submission checklist.

## What worked well

- **The OpenAI-compatible API meant zero migration cost.** Pointing the
  official `openai` SDK's `baseURL` at Token Factory and using an existing key
  was the entire integration step for text generation. Anyone who has built
  against the OpenAI API already knows this API.
- **`json_schema` structured output is genuinely reliable** on the models we
  used it against. We kept a loose-parsing fallback (`src/lib/nebius/json.ts`)
  as a defensive habit, but in practice strict mode did the job.
- **Three clearly differentiated Nemotron tiers made the "match the model to
  the task" story easy to build for real**, not just claim. Lightning for
  extraction, Super for tone, Ultra for the pipeline review is a genuine
  latency/cost/quality ladder, not an arbitrary spread across three model
  names.

## Friction points

- **No documented audio transcription endpoint.** The hackathon brief pushes
  builders toward Nemotron 3 Nano Omni for native audio understanding, and the
  model card describes exactly that capability (built on NVIDIA Parakeet), but
  the public API reference at the time of building
  (`docs.tokenfactory.nebius.com/api-reference`) lists chat completions,
  embeddings, reranking and image generation — no `/audio/transcriptions`
  path, and no documented example of sending audio through the chat endpoint's
  content parts either. We built `src/lib/nebius/transcribe.ts` to try Omni via
  a chat-completions audio content part first, fall back to a conventional
  audio-transcriptions call second, and degrade to a typed-note path third —
  but we could not confirm the first two actually work against a live key
  during the writing of this document, because we did not yet have credentials.
  A short "how to send audio to Omni" cookbook example would have removed real
  uncertainty from a project the brief explicitly encourages.
- **Model IDs are inconsistently cased across surfaces.** The cookbook lists
  `nvidia/Nemotron-3_5-Lightning`; the pricing/model pages sometimes render
  tier names with different capitalisation and hyphenation
  (`Nemotron-3-Ultra-550b-a55b` vs `Nemotron-3-Ultra-550B-a55b`). Not fatal —
  the API presumably normalises it — but it made it harder to be sure we had
  typed the exact right string versus a close cousin, especially without a
  live key to test against.
- **The nightly review / Serverless Jobs story is single-endpoint by design in
  our app**, but we never got confirmation of the exact contract Nebius
  Serverless Jobs expects (auth header shape, retry semantics, timeout
  ceiling) for triggering an HTTP endpoint on a schedule. We guarded
  `/api/review` with a bearer-token check general enough to fit "some
  scheduler calls this," but a documented example of "point a Serverless Job
  at this URL on this cadence" would have removed a guess.

## What we'd want to know next

- Whether `input_audio` content parts on `chat.completions.create` are in fact
  the supported path for Omni, or whether there is a dedicated multimodal
  endpoint we should be calling instead.
- Confirmed pricing for Omni specifically, since it wasn't listed alongside
  Nano/Super/Ultra on the pricing page we could find.

None of this stopped the build — every subsystem in Ringly degrades cleanly
when a service is unavailable, which is exactly the posture we'd recommend to
any team building against a fast-moving inference platform under a deadline.
