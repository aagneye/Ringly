import { z } from 'zod';
import { DEAL_STAGES } from '@/lib/db/schema/enums';

/**
 * Pulling structure out of a raw voice memo.
 *
 * This is the one call that runs on every single memo, so it is deliberately
 * the cheapest: schema-constrained, low temperature, small model. It answers
 * only "who and what", never "what should be done about it" — deciding actions
 * is the planner's job on a stronger tier.
 *
 * The recurring failure this prompt is written against is invention. Asked for a
 * deal stage, a model will happily promote a deal to "negotiation" because the
 * call sounded upbeat. Hence the repeated, explicit instruction to return null.
 */

export const EXTRACTION_SYSTEM_PROMPT = `You extract structured CRM data from a voice memo a salesperson or freelancer recorded straight after a client call. The transcript is informal, unpunctuated, and may contain filler words and self-corrections.

Rules:
- Use ONLY what is present in the transcript. Never infer, never fill gaps with what is typical.
- If a field is not mentioned, return null. A null is always better than a guess.
- contact_name: the client's name as spoken. First name only is normal and fine.
- company: only if actually named. Do not derive it from an email domain or guess from context.
- stage_guess: the pipeline stage the transcript supports. If the memo does not indicate a stage, return null rather than defaulting to any value.
- next_action: the single concrete thing the speaker said THEY would do. Not what the client will do.
- deadline: repeat the time phrase exactly as spoken, e.g. "Friday", "end of next week", "in a couple of days". Do not convert it to a date yourself. Null if no timing was mentioned.
- budget: the figure as spoken, e.g. "around 12k", "under 5 lakh". Null if money was not discussed.
- concerns: objections or hesitations the client expressed, in their words where you can.
- sentiment: how the call felt to the speaker.
- gist: one short sentence summarising the call, written in the third person.

When the speaker corrects themselves, take the correction. "Thursday, no wait, Friday" means Friday.`;

export const extractionSchema = z.object({
  contact_name: z.string().nullable(),
  company: z.string().nullable(),
  stage_guess: z.enum(DEAL_STAGES).nullable(),
  next_action: z.string().nullable(),
  deadline: z.string().nullable(),
  budget: z.string().nullable(),
  concerns: z.string().nullable(),
  sentiment: z.enum(['positive', 'neutral', 'negative']).nullable(),
  gist: z.string(),
});

export type Extraction = z.infer<typeof extractionSchema>;

export const EXTRACTION_WIRE_SCHEMA = {
  name: 'call_extraction',
  schema: {
    type: 'object',
    properties: {
      contact_name: { type: ['string', 'null'], description: 'Client name as spoken.' },
      company: { type: ['string', 'null'], description: 'Company name, only if named.' },
      stage_guess: {
        type: ['string', 'null'],
        enum: [...DEAL_STAGES, null],
        description: 'Pipeline stage the transcript supports, or null.',
      },
      next_action: {
        type: ['string', 'null'],
        description: 'The one concrete thing the speaker said they would do next.',
      },
      deadline: {
        type: ['string', 'null'],
        description: 'Time phrase exactly as spoken. Do not convert to a date.',
      },
      budget: { type: ['string', 'null'], description: 'Money as spoken.' },
      concerns: { type: ['string', 'null'], description: "The client's objections or worries." },
      sentiment: {
        type: ['string', 'null'],
        enum: ['positive', 'neutral', 'negative', null],
      },
      gist: { type: 'string', description: 'One sentence summary in the third person.' },
    },
    required: [
      'contact_name',
      'company',
      'stage_guess',
      'next_action',
      'deadline',
      'budget',
      'concerns',
      'sentiment',
      'gist',
    ],
    additionalProperties: false,
  },
} as const;

/** Build the user turn for extraction. */
export function buildExtractionPrompt(transcript: string, knownContacts: readonly string[]): string {
  const lines = [`Transcript:\n${transcript}`];

  if (knownContacts.length > 0) {
    lines.push('');
    lines.push(
      `People already in the CRM (prefer one of these spellings if the transcript clearly means one of them): ${knownContacts
        .slice(0, 40)
        .join(', ')}`,
    );
  }

  return lines.join('\n');
}

/** Strip a value the model returned as a literal placeholder rather than null. */
export function cleanNullish(value: string | null): string | null {
  if (value === null) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  const lowered = trimmed.toLowerCase();
  // Models routinely return these strings instead of a JSON null.
  if (
    ['null', 'none', 'n/a', 'na', 'unknown', 'not mentioned', 'not specified', '-'].includes(lowered)
  ) {
    return null;
  }
  return trimmed;
}

/** Apply placeholder cleaning across every nullable text field. */
export function normaliseExtraction(extraction: Extraction): Extraction {
  return {
    ...extraction,
    contact_name: cleanNullish(extraction.contact_name),
    company: cleanNullish(extraction.company),
    next_action: cleanNullish(extraction.next_action),
    deadline: cleanNullish(extraction.deadline),
    budget: cleanNullish(extraction.budget),
    concerns: cleanNullish(extraction.concerns),
  };
}
