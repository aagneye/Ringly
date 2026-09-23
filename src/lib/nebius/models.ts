/**
 * The three Nemotron tiers Ringly uses, and the rule for choosing between them.
 *
 * The hackathon brief asks builders to "reach for Nemotron 3 Ultra when you
 * need serious reasoning, and let Nano or Super handle the fast, everyday
 * calls". That is not decoration here — each tier is mapped to a task whose
 * cost/quality profile genuinely differs:
 *
 *   FAST      extraction and classification. Runs on every memo, must feel
 *             instant, and the output is schema-constrained so model quality
 *             matters far less than latency.
 *   BALANCED  writing in the user's voice. Tone is the product, so this is
 *             worth paying for, but it is still a single-turn generation.
 *   REASONING  multi-step judgement over the whole pipeline: which of twelve
 *             deals is quietly dying, and what should be done about it. This
 *             is the only place we need a frontier model.
 */
export const MODEL_TIERS = {
  FAST: 'nvidia/Nemotron-3_5-Lightning',
  BALANCED: 'nvidia/nemotron-3-super-120b-a12b',
  REASONING: 'nvidia/Nemotron-3-Ultra-550b-a55b',
  OMNI: 'nvidia/nemotron-3-nano-omni',
} as const;

export type ModelTier = keyof typeof MODEL_TIERS;
export type ModelId = (typeof MODEL_TIERS)[ModelTier];

/** Human-facing labels, shown in the model trace strip in the UI. */
export const TIER_LABELS: Record<ModelTier, string> = {
  FAST: 'Nemotron 3.5 Lightning',
  BALANCED: 'Nemotron 3 Super 120B',
  REASONING: 'Nemotron 3 Ultra 550B',
  OMNI: 'Nemotron 3 Nano Omni',
};

/** One-line reason each tier was chosen, surfaced as a tooltip in the UI. */
export const TIER_RATIONALE: Record<ModelTier, string> = {
  FAST: 'Schema-constrained extraction — optimised for latency, runs on every memo',
  BALANCED: 'Writes in your voice — tone quality matters more than speed here',
  REASONING: 'Multi-step judgement across the whole pipeline',
  OMNI: 'Native audio understanding — hears the memo without a separate STT hop',
};

/** Every task Ringly performs, mapped to the tier that serves it. */
export const TASK_TIERS = {
  transcribe: 'OMNI',
  extract: 'FAST',
  classify_intent: 'FAST',
  plan_actions: 'BALANCED',
  draft_email: 'BALANCED',
  summarise_contact: 'FAST',
  answer_question: 'BALANCED',
  morning_briefing: 'REASONING',
  precall_brief: 'BALANCED',
  pipeline_review: 'REASONING',
} as const satisfies Record<string, ModelTier>;

export type RinglyTask = keyof typeof TASK_TIERS;

/** Resolve the concrete model id for a task. */
export function modelForTask(task: RinglyTask): ModelId {
  return MODEL_TIERS[TASK_TIERS[task]];
}

/** Resolve the tier name for a task, for display and tracing. */
export function tierForTask(task: RinglyTask): ModelTier {
  return TASK_TIERS[task];
}
