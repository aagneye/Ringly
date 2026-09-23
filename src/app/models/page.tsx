import { TIER_LABELS, TIER_RATIONALE, TASK_TIERS, MODEL_TIERS } from '@/lib/nebius/models';
import { hasDatabase } from '@/lib/env';
import { getDb } from '@/lib/db';
import { modelTraces } from '@/lib/db/schema/model-traces';
import { sql, desc } from 'drizzle-orm';
import { humanise } from '@/lib/agent/runner';

/**
 * Which Nemotron tier did what, and why.
 *
 * Exists to answer a judging question with evidence rather than prose: the table
 * is a live count from the trace table, so "Lightning handled 40 extractions
 * while Ultra ran 3 reviews" is a fact on the page rather than a claim in a
 * README. It doubles as the honest place to state that the tier mapping is a
 * design decision with reasons, not an arbitrary spread across three models.
 */
export const dynamic = 'force-dynamic';

export default async function ModelsPage() {
  const rows = hasDatabase() ? await loadUsage() : [];
  const recent = hasDatabase() ? await loadRecent() : [];

  const totalCalls = rows.reduce((sum, row) => sum + row.calls, 0);
  const totalTokens = rows.reduce((sum, row) => sum + row.promptTokens + row.completionTokens, 0);

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">Models</h1>
        <p className="mt-0.5 text-sm text-ink-400">
          Everything Ringly thinks with runs on NVIDIA Nemotron via Nebius Token Factory.
        </p>
      </div>

      <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4">
        <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-ink-400">
          Why three tiers
        </h2>
        <ul className="flex flex-col gap-3">
          {(['FAST', 'BALANCED', 'REASONING', 'OMNI'] as const).map((tier) => (
            <li key={tier} className="border-l-2 border-ink-700 pl-3">
              <p className="text-sm font-medium text-ink-50">{TIER_LABELS[tier]}</p>
              <p className="mt-0.5 text-xs text-ink-300">{TIER_RATIONALE[tier]}</p>
              <p className="mt-1 font-mono text-[11px] text-ink-600">{MODEL_TIERS[tier]}</p>
              <p className="mt-1 text-xs text-ink-400">
                {Object.entries(TASK_TIERS)
                  .filter(([, mapped]) => mapped === tier)
                  .map(([task]) => humanise(task))
                  .join(' · ')}
              </p>
            </li>
          ))}
        </ul>
      </section>

      <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4">
        <div className="mb-3 flex items-baseline justify-between">
          <h2 className="text-xs font-medium uppercase tracking-wide text-ink-400">
            Actual usage
          </h2>
          <p className="font-mono text-xs text-ink-400">
            {totalCalls} calls · {totalTokens.toLocaleString()} tokens
          </p>
        </div>

        {rows.length === 0 ? (
          <p className="text-sm text-ink-600">
            No model calls yet. Record a memo and this fills in.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="text-xs uppercase tracking-wide text-ink-400">
                  <th scope="col" className="pb-2 pr-4 font-medium">
                    Tier
                  </th>
                  <th scope="col" className="pb-2 pr-4 text-right font-medium">
                    Calls
                  </th>
                  <th scope="col" className="pb-2 pr-4 text-right font-medium">
                    Tokens
                  </th>
                  <th scope="col" className="pb-2 text-right font-medium">
                    Avg latency
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={`${row.tier}-${row.model}`} className="border-t border-ink-800">
                    <td className="py-2 pr-4">
                      <span className="text-ink-100">
                        {TIER_LABELS[row.tier as keyof typeof TIER_LABELS] ?? row.tier}
                      </span>
                      {row.failures > 0 && (
                        <span className="ml-2 text-xs text-danger-500">
                          {row.failures} failed
                        </span>
                      )}
                    </td>
                    <td className="py-2 pr-4 text-right font-mono text-ink-200">{row.calls}</td>
                    <td className="py-2 pr-4 text-right font-mono text-ink-200">
                      {(row.promptTokens + row.completionTokens).toLocaleString()}
                    </td>
                    <td className="py-2 text-right font-mono text-ink-200">
                      {row.avgLatencyMs}ms
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {recent.length > 0 && (
        <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4">
          <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-ink-400">
            Last {recent.length} calls
          </h2>
          <ul className="flex flex-col gap-1.5">
            {recent.map((trace, index) => (
              <li
                key={index}
                className="flex items-baseline justify-between gap-3 text-xs text-ink-300"
              >
                <span className="min-w-0 truncate">
                  {humanise(trace.task)}
                  <span className="ml-2 text-ink-600">
                    {TIER_LABELS[trace.tier as keyof typeof TIER_LABELS] ?? trace.tier}
                  </span>
                </span>
                <span className="shrink-0 font-mono text-ink-400">
                  {trace.latencyMs}ms
                  {trace.failed && <span className="ml-1.5 text-danger-500">failed</span>}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}

async function loadUsage() {
  return getDb()
    .select({
      tier: modelTraces.tier,
      model: modelTraces.model,
      calls: sql<number>`count(*)::int`,
      promptTokens: sql<number>`coalesce(sum(${modelTraces.promptTokens}), 0)::int`,
      completionTokens: sql<number>`coalesce(sum(${modelTraces.completionTokens}), 0)::int`,
      avgLatencyMs: sql<number>`coalesce(round(avg(${modelTraces.latencyMs})), 0)::int`,
      failures: sql<number>`coalesce(sum(case when ${modelTraces.failed} then 1 else 0 end), 0)::int`,
    })
    .from(modelTraces)
    .groupBy(modelTraces.tier, modelTraces.model);
}

async function loadRecent() {
  return getDb()
    .select({
      task: modelTraces.task,
      tier: modelTraces.tier,
      latencyMs: modelTraces.latencyMs,
      failed: modelTraces.failed,
    })
    .from(modelTraces)
    .orderBy(desc(modelTraces.createdAt))
    .limit(15);
}
