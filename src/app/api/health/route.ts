import { NextResponse } from 'next/server';
import { hasNebiusCredentials, hasDatabase, hasTavily } from '@/lib/env';

/**
 * What's configured, at a glance.
 *
 * Used by the setup notices on the Today page, and useful on its own when
 * checking a fresh deployment — a 200 with three booleans is faster to read than
 * digging through platform environment variable settings.
 */
export const runtime = 'nodejs';

export async function GET() {
  return NextResponse.json({
    ok: true,
    nebius: hasNebiusCredentials(),
    database: hasDatabase(),
    tavily: hasTavily(),
  });
}
