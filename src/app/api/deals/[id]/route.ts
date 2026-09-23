import { NextResponse } from 'next/server';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { getDb } from '@/lib/db';
import { deals } from '@/lib/db/schema/deals';
import { agentActions } from '@/lib/db/schema/agent-actions';
import { DEAL_STAGES } from '@/lib/db/schema/enums';
import { loadDealDetail } from '@/lib/repo/queries';
import { handleApiError, jsonError, readJsonBody } from '@/lib/api';
import { randomUUID } from 'crypto';

/**
 * Manual edits, chiefly dragging a card between columns.
 *
 * A manual change is written to the same audit table as an agent action, with
 * source 'manual'. Keeping one timeline per deal is what lets the detail view
 * show "Ringly moved this to Proposal" and "you moved it back" in order, which is
 * the only honest way to present a shared history.
 */

export const runtime = 'nodejs';

const patchSchema = z.object({
  stage: z.enum(DEAL_STAGES).optional(),
  title: z.string().min(1).max(200).optional(),
  nextAction: z.string().max(280).nullable().optional(),
  budget: z.string().max(80).nullable().optional(),
});

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const detail = await loadDealDetail(id, new Date());
    if (!detail) return jsonError('That deal does not exist.', 404, 'deal_not_found');
    return NextResponse.json(detail);
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const body = await readJsonBody<unknown>(request);

    const parsed = patchSchema.safeParse(body);
    if (!parsed.success) {
      return jsonError(
        `Invalid update: ${parsed.error.issues.map((issue) => issue.message).join('; ')}`,
        400,
        'invalid_body',
      );
    }

    const db = getDb();
    const now = new Date();

    const [existing] = await db
      .select({ stage: deals.stage, title: deals.title })
      .from(deals)
      .where(eq(deals.id, id))
      .limit(1);

    if (!existing) return jsonError('That deal does not exist.', 404, 'deal_not_found');

    const patch: Record<string, unknown> = { updatedAt: now };
    if (parsed.data.stage !== undefined) patch.stage = parsed.data.stage;
    if (parsed.data.title !== undefined) patch.title = parsed.data.title;
    if (parsed.data.nextAction !== undefined) patch.nextAction = parsed.data.nextAction;
    if (parsed.data.budget !== undefined) patch.budget = parsed.data.budget;

    await db.update(deals).set(patch).where(eq(deals.id, id));

    if (parsed.data.stage && parsed.data.stage !== existing.stage) {
      await db.insert(agentActions).values({
        runId: randomUUID(),
        dealId: id,
        tool: 'manual_stage_change',
        args: { from: existing.stage, to: parsed.data.stage },
        status: 'applied',
        source: 'manual',
        summary: `You moved this from ${existing.stage} to ${parsed.data.stage}`,
        resolvedAt: now,
      });
    }

    return NextResponse.json({ ok: true, id, ...parsed.data });
  } catch (error) {
    return handleApiError(error);
  }
}
