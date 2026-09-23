import { getNebiusClient } from './client';
import { MODEL_TIERS } from './models';
import type { ModelTrace, TraceCollector } from './trace';

/**
 * Getting words out of audio.
 *
 * This is the one part of the pipeline the platform does not settle for us.
 * Token Factory's documented API surface covers chat, embeddings, reranking and
 * image generation, but no `/audio/transcriptions` endpoint — while Nemotron 3
 * Nano Omni is natively multimodal and carries NVIDIA's Parakeet audio encoder,
 * so it should accept audio through the ordinary chat endpoint.
 *
 * Rather than betting the product on that, transcription sits behind a provider
 * interface with an ordered chain:
 *
 *   1. Nemotron Omni via chat completions — preferred, because it keeps the
 *      entire pipeline on NVIDIA open models running on Nebius.
 *   2. An OpenAI-compatible `/audio/transcriptions` endpoint, if one turns out
 *      to exist on Token Factory.
 *   3. Client-supplied text, which is also the typed-note path.
 *
 * The chain is what makes the audio question answerable in an afternoon once a
 * key exists, instead of a rewrite.
 */

export interface TranscriptionRequest {
  audio: Buffer;
  mimeType: string;
  /** Recording length, when the browser reported it. */
  durationSeconds?: number;
  collector?: TraceCollector;
}

export interface TranscriptionResult {
  text: string;
  provider: 'nemotron-omni' | 'audio-endpoint' | 'client-text';
  trace?: ModelTrace;
}

export class TranscriptionUnavailableError extends Error {
  constructor(readonly attempts: string[]) {
    super(
      `No transcription provider succeeded. Tried: ${attempts.join('; ')}. ` +
        'Type the note instead, or configure an audio-capable provider.',
    );
    this.name = 'TranscriptionUnavailableError';
  }
}

const TRANSCRIPTION_PROMPT =
  'Transcribe this voice memo verbatim. Output only the words spoken, with no commentary, ' +
  'no speaker labels and no summary. Preserve self-corrections exactly as spoken.';

/** Map a browser MIME type to the format hint the audio content part expects. */
export function audioFormatFromMime(mimeType: string): string {
  const normalised = mimeType.toLowerCase();
  if (normalised.includes('webm')) return 'webm';
  if (normalised.includes('ogg')) return 'ogg';
  if (normalised.includes('mp4') || normalised.includes('m4a')) return 'mp4';
  if (normalised.includes('mpeg') || normalised.includes('mp3')) return 'mp3';
  if (normalised.includes('wav')) return 'wav';
  return 'webm';
}

/**
 * Transcribe via Nemotron Omni's chat endpoint using an audio content part.
 *
 * Shaped after the OpenAI audio-input convention, which is what an
 * OpenAI-compatible gateway is most likely to accept.
 */
async function viaOmni(request: TranscriptionRequest): Promise<TranscriptionResult> {
  const client = getNebiusClient();
  const startedAt = Date.now();

  const response = await client.chat.completions.create({
    model: MODEL_TIERS.OMNI,
    temperature: 0,
    max_tokens: 1200,
    messages: [
      {
        role: 'user',
        // The SDK's types do not yet describe audio parts for every provider,
        // so this content array is asserted rather than typed.
        content: [
          { type: 'text', text: TRANSCRIPTION_PROMPT },
          {
            type: 'input_audio',
            input_audio: {
              data: request.audio.toString('base64'),
              format: audioFormatFromMime(request.mimeType),
            },
          },
        ] as never,
      },
    ],
  });

  const text = response.choices[0]?.message?.content?.trim() ?? '';
  if (!text) throw new Error('Omni returned an empty transcript');

  const trace: ModelTrace = {
    task: 'transcribe',
    tier: 'OMNI',
    model: MODEL_TIERS.OMNI,
    promptTokens: response.usage?.prompt_tokens ?? 0,
    completionTokens: response.usage?.completion_tokens ?? 0,
    latencyMs: Date.now() - startedAt,
  };
  request.collector?.record(trace);

  return { text, provider: 'nemotron-omni', trace };
}

/** Transcribe via a conventional audio-transcriptions endpoint, if present. */
async function viaAudioEndpoint(request: TranscriptionRequest): Promise<TranscriptionResult> {
  const client = getNebiusClient();
  const startedAt = Date.now();

  const file = new File([new Uint8Array(request.audio)], `memo.${audioFormatFromMime(request.mimeType)}`, {
    type: request.mimeType,
  });

  // Cast because the model id is provider-specific and not in the SDK's union.
  const response = await client.audio.transcriptions.create({
    file,
    model: MODEL_TIERS.OMNI,
  } as never);

  const text =
    typeof response === 'string'
      ? response.trim()
      : ((response as { text?: string }).text ?? '').trim();

  if (!text) throw new Error('Audio endpoint returned an empty transcript');

  const trace: ModelTrace = {
    task: 'transcribe',
    tier: 'OMNI',
    model: MODEL_TIERS.OMNI,
    promptTokens: 0,
    completionTokens: 0,
    latencyMs: Date.now() - startedAt,
  };
  request.collector?.record(trace);

  return { text, provider: 'audio-endpoint', trace };
}

/**
 * Try each provider in order of preference, collecting failures so the error
 * explains what was attempted rather than surfacing only the last problem.
 */
export async function transcribe(request: TranscriptionRequest): Promise<TranscriptionResult> {
  const attempts: string[] = [];

  for (const [label, provider] of [
    ['Nemotron Omni chat', viaOmni],
    ['audio transcriptions endpoint', viaAudioEndpoint],
  ] as const) {
    try {
      return await provider(request);
    } catch (error) {
      attempts.push(`${label} → ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  throw new TranscriptionUnavailableError(attempts);
}
