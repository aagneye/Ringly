import { z } from 'zod';

/**
 * "What's happening with Priya?"
 *
 * Answers from the verbatim note history, which is the whole reason transcripts
 * are kept rather than discarded after extraction. A CRM can tell you a deal is
 * at "proposal"; only the transcript can tell you she was worried about
 * onboarding time and wanted to involve her CTO.
 *
 * The prompt is aggressive about admitting ignorance. An assistant that invents
 * a plausible answer about a client is worse than useless — it is dangerous,
 * because the user will repeat it on a call.
 */

export const ASK_SYSTEM_PROMPT = `You are Ringly, answering a question about the user's own deals and clients. You have their notes.

Rules:
- Answer only from the notes provided. Never fill a gap with what is plausible.
- If the notes do not contain the answer, say exactly what you do and do not know. "Your notes do not mention her budget" is a good answer.
- Be brief. Two or three sentences unless the question genuinely needs more.
- Quote the client's own words when they are the answer.
- Say when you heard it. "As of your call nine days ago" matters, because a stale fact presented as current is misleading.
- Write to be spoken aloud: contractions, no bullet points, no headings.
- No preamble. Do not say "Based on your notes" — just answer.
- If the question is about something you could act on, mention that you can, but do not act. Answering is not doing.`;

export const askSchema = z.object({
  answer: z.string().min(1),
  /** Deals the answer drew on, so the UI can link to them. */
  referenced_deal_ids: z.array(z.string()).max(6),
  /** True when the notes did not contain enough to answer properly. */
  insufficient_information: z.boolean(),
});

export type AskOutput = z.infer<typeof askSchema>;

export const ASK_WIRE_SCHEMA = {
  name: 'memory_answer',
  schema: {
    type: 'object',
    properties: {
      answer: {
        type: 'string',
        description: 'The answer, written to be read aloud. Brief.',
      },
      referenced_deal_ids: {
        type: 'array',
        maxItems: 6,
        items: { type: 'string' },
        description: 'Ids of deals the answer drew on.',
      },
      insufficient_information: {
        type: 'boolean',
        description: 'True when the notes did not contain enough to answer.',
      },
    },
    required: ['answer', 'referenced_deal_ids', 'insufficient_information'],
    additionalProperties: false,
  },
} as const;

export interface AskContextDeal {
  dealId: string;
  contactName: string;
  company: string | null;
  stage: string;
  nextAction: string | null;
  deadlineLabel: string | null;
  budget: string | null;
  concerns: string | null;
  lastContactLabel: string | null;
  notes: readonly { text: string; whenLabel: string }[];
}

export function buildAskPrompt(
  question: string,
  deals: readonly AskContextDeal[],
  todayLabel: string,
): string {
  const lines: string[] = [];

  lines.push(`Today is ${todayLabel}.`);
  lines.push('');
  lines.push(`Question: ${question}`);
  lines.push('');

  if (deals.length === 0) {
    lines.push('You have no deals on file that relate to this question.');
    return lines.join('\n');
  }

  lines.push('RELEVANT DEALS AND NOTES:');

  for (const deal of deals) {
    lines.push('');
    lines.push(
      `--- ${deal.contactName}${deal.company ? ` at ${deal.company}` : ''} [deal ${deal.dealId}] ---`,
    );
    lines.push(`Stage: ${deal.stage}`);
    if (deal.lastContactLabel) lines.push(`Last spoke: ${deal.lastContactLabel}`);
    if (deal.nextAction) lines.push(`Next action: ${deal.nextAction}`);
    if (deal.deadlineLabel) lines.push(`Deadline: ${deal.deadlineLabel}`);
    if (deal.budget) lines.push(`Budget: ${deal.budget}`);
    if (deal.concerns) lines.push(`Concerns: ${deal.concerns}`);

    if (deal.notes.length > 0) {
      lines.push('Notes, most recent first:');
      for (const note of deal.notes.slice(0, 4)) {
        lines.push(`  [${note.whenLabel}] ${note.text}`);
      }
    } else {
      lines.push('No call notes recorded.');
    }
  }

  lines.push('');
  lines.push('Answer the question.');

  return lines.join('\n');
}

/**
 * Narrow the pipeline to the deals a question is plausibly about.
 *
 * A keyword pass rather than a model call: cheap, predictable, and good enough
 * because the question almost always names the person. When nothing matches, the
 * whole pipeline is passed through — an over-broad context costs tokens, whereas
 * an over-narrow one produces a confidently wrong answer.
 */
export function selectRelevantDeals<T extends { contactName: string; company: string | null }>(
  question: string,
  deals: readonly T[],
  limit = 4,
): T[] {
  const words = question
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((word) => word.length > 2);

  if (words.length === 0) return [...deals].slice(0, limit);

  const scored = deals.map((deal) => {
    const haystack = `${deal.contactName} ${deal.company ?? ''}`.toLowerCase();
    const score = words.reduce((total, word) => (haystack.includes(word) ? total + 1 : total), 0);
    return { deal, score };
  });

  const matched = scored.filter((entry) => entry.score > 0);
  if (matched.length === 0) return [...deals].slice(0, limit);

  return matched
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((entry) => entry.deal);
}
