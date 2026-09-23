import { NextResponse } from 'next/server';
import { MissingNebiusKeyError } from '@/lib/nebius/client';
import { MissingDatabaseUrlError } from '@/lib/db';
import { StructuredOutputError } from '@/lib/nebius/structured';
import { ChatCallError } from '@/lib/nebius/chat';
import { TranscriptionUnavailableError } from '@/lib/nebius/transcribe';
import { DealNotFoundError } from '@/lib/agent/precall';

/**
 * One place that turns a thrown error into a response.
 *
 * The distinction that matters is setup problems versus runtime failures. An
 * absent API key is not a 500 — it is a configuration step, and returning it as
 * a server error sends the user hunting through logs for a mistake that a
 * sentence could have explained. Those cases return 503 with the fix in the
 * message.
 */

export interface ApiErrorBody {
  error: string;
  /** Machine-readable discriminator for the client. */
  code: string;
  /** Present when the user can fix this themselves. */
  hint?: string;
}

export function jsonError(
  message: string,
  status: number,
  code: string,
  hint?: string,
): NextResponse<ApiErrorBody> {
  return NextResponse.json({ error: message, code, ...(hint ? { hint } : {}) }, { status });
}

export function handleApiError(error: unknown): NextResponse<ApiErrorBody> {
  if (error instanceof MissingNebiusKeyError) {
    return jsonError(error.message, 503, 'nebius_not_configured', 'Add NEBIUS_API_KEY to .env.local');
  }

  if (error instanceof MissingDatabaseUrlError) {
    return jsonError(error.message, 503, 'database_not_configured', 'Add DATABASE_URL to .env.local');
  }

  if (error instanceof TranscriptionUnavailableError) {
    return jsonError(
      error.message,
      503,
      'transcription_unavailable',
      'Use the type-a-note option instead.',
    );
  }

  if (error instanceof DealNotFoundError) {
    return jsonError(error.message, 404, 'deal_not_found');
  }

  if (error instanceof StructuredOutputError) {
    return jsonError(
      'The model did not return usable structured output. Try again.',
      502,
      'bad_model_output',
    );
  }

  if (error instanceof ChatCallError) {
    return jsonError(`Model call failed: ${error.message}`, 502, 'model_call_failed');
  }

  const message = error instanceof Error ? error.message : String(error);
  // Log server-side; the client gets a generic message so internals do not leak.
  console.error('[ringly] unhandled API error:', error);
  return jsonError(
    process.env.NODE_ENV === 'development' ? message : 'Something went wrong.',
    500,
    'internal_error',
  );
}

/** Parse a JSON body, returning null rather than throwing on malformed input. */
export async function readJsonBody<T>(request: Request): Promise<T | null> {
  try {
    return (await request.json()) as T;
  } catch {
    return null;
  }
}

/**
 * Guard an endpoint that a scheduler calls.
 *
 * The nightly review writes to the database and spends tokens, so it must not be
 * publicly triggerable. When CRON_SECRET is unset the route is allowed only
 * outside production, which keeps local development frictionless without leaving
 * a deployed instance open.
 */
export function isAuthorisedCron(request: Request, secret: string | undefined): boolean {
  if (!secret) return process.env.NODE_ENV !== 'production';

  const header = request.headers.get('authorization');
  if (header === `Bearer ${secret}`) return true;

  // Vercel Cron sends the secret this way.
  return request.headers.get('x-cron-secret') === secret;
}
