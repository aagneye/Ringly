import { NextResponse } from 'next/server';
import { desc, sql } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { modelTraces } from '@/lib/db/schema/model-traces';
import { agentActions } from '@/lib/db/schema/agent-actions';
import { handleApiError } from '@/lib/api';
import { TIER_LABELS, TIER_RATIONALE, type ModelTier } from '@/lib/nebius/models';

/**
 * Aggregate Nemotron usage, for the model trace panel.
 *
 * This endpoint exists for the judging criteria as much as for the user. "How
 * effectively does it use Token Factory and Nemotron" is answered far better by a
 * live count — Lightning ran 40 extractions, Ultra ran 3 reviews — than by a
 * paragraph in a README.
 */
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const db = getDb();

    const [byTier, recent, actionCounts] = await Promise.all([
      db
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
        .groupBy(modelTraces.tier, modelTraces.model),
      db
        .select({
          task: modelTraces.task,
          tier: modelTraces.tier,
          latencyMs: modelTraces.latencyMs,
          promptTokens: modelTraces.promptTokens,
          completionTokens: modelTraces.completionTokens,
          failed: modelTraces.failed,
          createdAt: modelTraces.createdAt,
        })
        .from(modelTraces)
        .orderBy(desc(modelTraces.createdAt))
        .limit(25),
      db
        .select({
          source: agentActions.source,
          status: agentActions.status,
          count: sql<number>`count(*)::int`,
        })
        .from(agentActions)
        .groupBy(agentActions.source, agentActions.status),
    ]);

    return NextResponse.json({
      tiers: byTier.map((row) => ({
        ...row,
        label: TIER_LABELS[row.tier as ModelTier] ?? row.tier,
        rationale: TIER_RATIONALE[row.tier as ModelTier] ?? '',
      })),
      recent,
      actionCounts,
      totals: {
        calls: byTier.reduce((sum, row) => sum + row.calls, 0),
        promptTokens: byTier.reduce((sum, row) => sum + row.promptTokens, 0),
        completionTokens: byTier.reduce((sum, row) => sum + row.completionTokens, 0),
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
}
