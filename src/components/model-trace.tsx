'use client';

import type { ModelTrace } from '@/lib/nebius/trace';
import { TIER_LABELS, TIER_RATIONALE, type ModelTier } from '@/lib/nebius/models';
import { humanise } from '@/lib/agent/runner';

/**
 * The strip that shows which Nemotron tier did what.
 *
 * Deliberately part of the product surface rather than a debug panel. It answers
 * the judging question "how effectively does this use Token Factory and Nemotron"
 * by letting someone watch Lightning, Super and Ultra each take the part of the
 * job they suit — and it is genuinely interesting to a user who wants to know why
 * one step took 400ms and another took four seconds.
 */

const TIER_COLOUR: Record<ModelTier, string> = {
  FAST: 'text-good-500 border-good-500/30 bg-good-500/5',
  BALANCED: 'text-accent-400 border-accent-500/30 bg-accent-500/5',
  REASONING: 'text-warn-500 border-warn-500/30 bg-warn-500/5',
  OMNI: 'text-ink-200 border-ink-600 bg-ink-800/40',
};

export function ModelTraceStrip({ traces }: { traces: ModelTrace[] }) {
  if (traces.length === 0) return null;

  const totalLatency = traces.reduce((sum, trace) => sum + trace.latencyMs, 0);
  const totalTokens = traces.reduce(
    (sum, trace) => sum + trace.promptTokens + trace.completionTokens,
    0,
  );

  return (
    <section
      aria-label="Model usage for this run"
      className="rounded-(--radius-card) border border-ink-800 bg-ink-900/60 p-4"
    >
      <div className="mb-3 flex items-baseline justify-between">
        <h3 className="text-xs font-medium uppercase tracking-wide text-ink-400">
          Running on Nebius Token Factory
        </h3>
        <p className="font-mono text-xs text-ink-400">
          {totalTokens.toLocaleString()} tokens · {(totalLatency / 1000).toFixed(1)}s
        </p>
      </div>

      <ul className="flex flex-col gap-2">
        {traces.map((trace, index) => (
          <li
            key={`${trace.task}-${index}`}
            className={`flex items-center justify-between gap-3 rounded-lg border px-3 py-2 ${
              TIER_COLOUR[trace.tier]
            }`}
          >
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">
                {TIER_LABELS[trace.tier]}
                {trace.failed && <span className="ml-2 text-danger-500">failed</span>}
              </p>
              <p className="truncate text-xs opacity-70" title={TIER_RATIONALE[trace.tier]}>
                {humanise(trace.task)} — {TIER_RATIONALE[trace.tier]}
              </p>
            </div>
            <p className="shrink-0 font-mono text-xs opacity-80">
              {trace.latencyMs}ms
              {trace.completionTokens > 0 && ` · ${trace.completionTokens}t`}
            </p>
          </li>
        ))}
      </ul>
    </section>
  );
}

/** Compact one-line variant for the deal detail header. */
export function TierPill({ tier }: { tier: ModelTier }) {
  return (
    <span
      title={TIER_RATIONALE[tier]}
      className={`rounded-full border px-2 py-0.5 text-[10px] ${TIER_COLOUR[tier]}`}
    >
      {TIER_LABELS[tier]}
    </span>
  );
}
