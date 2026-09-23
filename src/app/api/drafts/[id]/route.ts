import { NextResponse } from 'next/server';
import { eq } from 'drizzle-orm';
import { randomUUID } from 'crypto';
import { z } from 'zod';
import { getDb } from '@/lib/db';
import { drafts } from '@/lib/db/schema/drafts';
import { agentActions } from '@/lib/db/schema/agent-actions';
import { handleApiError, jsonError, readJsonBody } from '@/lib/api';

/**
 * The human tap that resolves an irreversible action.
 *
 * Ringly does not send mail itself. "Approved" means the user opened it in their
 * own mail client and we recorded that they did — which keeps the product honest
 * about what it actually did, and avoids asking for mailbox credentials to
 * demonstrate a feature that is about judgement rather than delivery.
 */

export const runtime = 'nodejs';

const bodySchema = z.object({
  action: z.enum(['approve', 'discard']),
  /** Edits the user made before approving. */
  subject: z.string().min(1).max(200).optional(),
  body: z.string().min(1).optional(),
});

export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const parsed = bodySchema.safeParse(await readJsonBody<unknown>(request));

    if (!parsed.success) {
      return jsonError('Expected action "approve" or "discard".', 400, 'invalid_body');
    }

    const db = getDb();
    const now = new Date();

    const [draft] = await db
      .select({ id: drafts.id, dealId: drafts.dealId, subject: drafts.subject })
      .from(drafts)
      .where(eq(drafts.id, id))
      .limit(1);

    if (!draft) return jsonError('That draft does not exist.', 404, 'draft_not_found');

    const approving = parsed.data.action === 'approve';

    await db
      .update(drafts)
      .set({
        status: approving ? 'approved' : 'discarded',
        ...(parsed.data.subject ? { subject: parsed.data.subject } : {}),
        ...(parsed.data.body ? { body: parsed.data.body } : {}),
        updatedAt: now,
      })
      .where(eq(drafts.id, id));

    await db.insert(agentActions).values({
      runId: randomUUID(),
      dealId: draft.dealId,
      tool: 'draft_email',
      args: { draftId: id, decision: parsed.data.action },
      status: approving ? 'approved' : 'rejected',
      source: 'manual',
      summary: approving
        ? `You approved the email "${parsed.data.subject ?? draft.subject}"`
        : `You discarded the email "${draft.subject}"`,
      resolvedAt: now,
    });

    return NextResponse.json({ ok: true, id, status: approving ? 'approved' : 'discarded' });
  } catch (error) {
    return handleApiError(error);
  }
}
