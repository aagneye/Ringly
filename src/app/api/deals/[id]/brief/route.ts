import { NextResponse } from 'next/server';
import { getPrecallBrief } from '@/lib/agent/precall';
import { handleApiError } from '@/lib/api';

/** The pre-call brief for one deal. Never cached — freshness is the point. */
export const runtime = 'nodejs';
export const maxDuration = 90;
export const dynamic = 'force-dynamic';

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const brief = await getPrecallBrief(id, new Date());
    return NextResponse.json(brief);
  } catch (error) {
    return handleApiError(error);
  }
}
