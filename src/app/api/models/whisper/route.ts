import { NextResponse } from 'next/server';
import { whisperManifest } from '@/lib/whisper-manifest';

/**
 * GET /api/models/whisper — the catalogue of on-device Whisper models.
 *
 * Static data (see src/lib/whisper-manifest.ts), so it is safe to cache at the
 * edge for an hour: the client only needs it when the user opens the model
 * download row in settings, and the underlying hashes change roughly never.
 */
export const runtime = 'nodejs';

export function GET() {
  return NextResponse.json(whisperManifest(), {
    headers: {
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
