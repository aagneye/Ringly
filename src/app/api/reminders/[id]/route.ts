import { NextResponse } from 'next/server';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { getDb } from '@/lib/db';
import { reminders } from '@/lib/db/schema/reminders';
import { handleApiError, jsonError, readJsonBody } from '@/lib/api';

/** Tick off or dismiss a reminder. */
export const runtime = 'nodejs';

const bodySchema = z.object({
  status: z.enum(['done', 'dismissed', 'pending']),
});

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const parsed = bodySchema.safeParse(await readJsonBody<unknown>(request));

    if (!parsed.success) {
      return jsonError('Expected status "done", "dismissed" or "pending".', 400, 'invalid_body');
    }

    const db = getDb();
    const now = new Date();

    const [existing] = await db
      .select({ id: reminders.id })
      .from(reminders)
      .where(eq(reminders.id, id))
      .limit(1);

    if (!existing) return jsonError('That reminder does not exist.', 404, 'reminder_not_found');

    await db
      .update(reminders)
      .set({
        status: parsed.data.status,
        // Reopening a reminder must clear the completion stamp, or the UI shows a
        // pending item that claims to have been finished.
        completedAt: parsed.data.status === 'pending' ? null : now,
      })
      .where(eq(reminders.id, id));

    return NextResponse.json({ ok: true, id, status: parsed.data.status });
  } catch (error) {
    return handleApiError(error);
  }
}
