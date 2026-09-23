import { NextResponse } from 'next/server';
import { transcribe } from '@/lib/nebius/transcribe';
import { processMemo } from '@/lib/agent/process-memo';
import { handleApiError, jsonError } from '@/lib/api';

/**
 * The endpoint the record button hits.
 *
 * Accepts either multipart audio or a JSON transcript. The text path is not a
 * fallback bolted on for testing — typing a note is a legitimate way to use the
 * product, and it keeps the whole agent loop demonstrable when a microphone or a
 * transcription provider is unavailable.
 */

export const runtime = 'nodejs';
export const maxDuration = 120;

const MAX_AUDIO_BYTES = 10 * 1024 * 1024;
const MAX_TRANSCRIPT_CHARS = 20_000;

export async function POST(request: Request) {
  try {
    const contentType = request.headers.get('content-type') ?? '';

    if (contentType.includes('multipart/form-data')) {
      return await handleAudio(request);
    }

    return await handleText(request);
  } catch (error) {
    return handleApiError(error);
  }
}

async function handleAudio(request: Request) {
  const form = await request.formData();
  const audio = form.get('audio');

  if (!(audio instanceof File)) {
    return jsonError('No audio file was included in the request.', 400, 'missing_audio');
  }

  if (audio.size === 0) {
    return jsonError('The recording was empty. Try again.', 400, 'empty_audio');
  }

  if (audio.size > MAX_AUDIO_BYTES) {
    return jsonError(
      'That recording is too long. Keep memos under about 90 seconds.',
      413,
      'audio_too_large',
    );
  }

  const durationRaw = form.get('durationSeconds');
  const durationSeconds =
    typeof durationRaw === 'string' && durationRaw !== '' ? Number(durationRaw) : undefined;

  const buffer = Buffer.from(await audio.arrayBuffer());

  const transcription = await transcribe({
    audio: buffer,
    mimeType: audio.type || 'audio/webm',
    durationSeconds,
  });

  if (!transcription.text.trim()) {
    return jsonError(
      'Nothing was audible in that recording. Try again somewhere quieter.',
      422,
      'empty_transcript',
    );
  }

  const result = await processMemo({
    transcript: transcription.text,
    durationSeconds: Number.isFinite(durationSeconds) ? durationSeconds : undefined,
    source: 'voice',
  });

  return NextResponse.json({
    ...result,
    transcriptionProvider: transcription.provider,
  });
}

async function handleText(request: Request) {
  let body: { transcript?: unknown } | null = null;
  try {
    body = (await request.json()) as { transcript?: unknown };
  } catch {
    return jsonError('Expected a JSON body with a "transcript" field.', 400, 'invalid_body');
  }

  const transcript = typeof body?.transcript === 'string' ? body.transcript.trim() : '';

  if (!transcript) {
    return jsonError('Write a note first.', 400, 'missing_transcript');
  }

  if (transcript.length > MAX_TRANSCRIPT_CHARS) {
    return jsonError('That note is too long.', 413, 'transcript_too_large');
  }

  const result = await processMemo({ transcript, source: 'text' });

  return NextResponse.json({ ...result, transcriptionProvider: 'client-text' });
}
