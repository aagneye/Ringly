import { NextResponse } from 'next/server';
import { loadDueReminders, loadTodaysEvents, loadPendingDrafts } from '@/lib/repo/queries';
import { handleApiError } from '@/lib/api';

/** Everything due today, for the home screen. */
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const now = new Date();
    const [reminders, events, drafts] = await Promise.all([
      loadDueReminders(now),
      loadTodaysEvents(now),
      loadPendingDrafts(),
    ]);

    return NextResponse.json({ reminders, events, drafts, now: now.toISOString() });
  } catch (error) {
    return handleApiError(error);
  }
}
