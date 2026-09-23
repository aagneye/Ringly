import { NextResponse } from 'next/server';
import { runNightlyReview } from '@/lib/agent/review';
import { getEnv } from '@/lib/env';
import { handleApiError, jsonError, isAuthorisedCron } from '@/lib/api';

/**
 * The nightly review.
 *
 * Guarded, because it spends Ultra tokens and writes drafts. A scheduler calls
 * POST with the secret; the demo calls it from a button in the UI, which works
 * locally without a secret and requires one in production.
 *
 * Suitable for Nebius Serverless Jobs, or any cron that can send a bearer token.
 */
export const runtime = 'nodejs';
export const maxDuration = 300;

export async function POST(request: Request) {
  try {
    const { CRON_SECRET } = getEnv();

    if (!isAuthorisedCron(request, CRON_SECRET)) {
      return jsonError(
        'This endpoint requires the cron secret.',
        401,
        'unauthorised',
        'Send Authorization: Bearer $CRON_SECRET',
      );
    }

    const result = await runNightlyReview(new Date());
    return NextResponse.json(result);
  } catch (error) {
    return handleApiError(error);
  }
}

/** GET is allowed so a scheduler that cannot POST still works. */
export async function GET(request: Request) {
  return POST(request);
}
