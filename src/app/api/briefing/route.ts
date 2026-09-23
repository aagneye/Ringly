import { NextResponse } from 'next/server';
import { getBriefing } from '@/lib/agent/briefing';
import { handleApiError } from '@/lib/api';

/**
 * The morning briefing.
 *
 * `?force=1` bypasses the daily cache, which is what the demo uses so a judge
 * watches Ultra generate the briefing rather than reading a cached one.
 */
export const runtime = 'nodejs';
export const maxDuration = 120;
export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const url = new URL(request.url);
    const force = url.searchParams.get('force') === '1';
    const briefing = await getBriefing(new Date(), force);
    return NextResponse.json(briefing);
  } catch (error) {
    return handleApiError(error);
  }
}
