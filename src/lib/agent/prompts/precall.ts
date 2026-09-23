import { z } from 'zod';

/**
 * The pre-call brief.
 *
 * The highest-value screen in the product: five minutes before a call, what do I
 * need to know? It answers from verbatim transcripts rather than from the
 * structured projection, because the useful material is the phrasing — "she said
 * onboarding time was her worry" beats "concerns: onboarding".
 *
 * The open questions are the part that earns trust. Anyone can summarise history;
 * suggesting what to ask next is what a good chief of staff does.
 */

export const PRECALL_SYSTEM_PROMPT = `You are Ringly, preparing a salesperson or freelancer for a call that is about to start. They have perhaps two minutes to read this.

You will be given the deal record and the verbatim notes from previous calls with this person.

Produce four things:

1. where_we_are — one or two sentences on the state of this relationship. Not a history lesson. Where things stand right now.
2. they_care_about — the two or three things this person has actually shown they care about, quoting their phrasing where you can. Drawn from what they said, never from what clients generally care about.
3. you_promised — anything the user committed to and whether it appears to have been done. If they promised something and there is no sign it happened, say so plainly. This is the most important field: walking into a call having forgotten a promise is the worst outcome.
4. ask_about — two or three specific questions worth asking on this call. Specific to this deal. Never generic discovery questions like "what are your goals".

Rules:
- Every claim must trace to the notes you were given. If the notes are thin, say they are thin.
- Quote the client's own words where it helps, in quotation marks.
- No filler. No "it is important to build rapport". They know how to sell.
- If there are no previous notes at all, say this is a first conversation and suggest what to establish.`;

export const precallSchema = z.object({
  where_we_are: z.string().min(3),
  they_care_about: z.array(z.string().min(3)).max(4),
  you_promised: z.array(
    z.object({
      promise: z.string().min(3),
      appears_done: z.boolean(),
    }),
  ),
  ask_about: z.array(z.string().min(3)).max(4),
});

export type PrecallOutput = z.infer<typeof precallSchema>;

export const PRECALL_WIRE_SCHEMA = {
  name: 'precall_brief',
  schema: {
    type: 'object',
    properties: {
      where_we_are: {
        type: 'string',
        description: 'One or two sentences on the current state of the relationship.',
      },
      they_care_about: {
        type: 'array',
        maxItems: 4,
        items: { type: 'string' },
        description: "Things this person has shown they care about, in their words where possible.",
      },
      you_promised: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            promise: { type: 'string' },
            appears_done: {
              type: 'boolean',
              description: 'Whether the notes suggest this was followed through.',
            },
          },
          required: ['promise', 'appears_done'],
          additionalProperties: false,
        },
      },
      ask_about: {
        type: 'array',
        maxItems: 4,
        items: { type: 'string' },
        description: 'Specific questions worth asking on this call.',
      },
    },
    required: ['where_we_are', 'they_care_about', 'you_promised', 'ask_about'],
    additionalProperties: false,
  },
} as const;

export interface PrecallInput {
  contactName: string;
  company: string | null;
  role: string | null;
  dealTitle: string;
  stage: string;
  nextAction: string | null;
  deadlineLabel: string | null;
  budget: string | null;
  concerns: string | null;
  daysSinceLastContact: number | null;
  transcripts: readonly { text: string; whenLabel: string }[];
  openReminders: readonly string[];
  companyFacts: readonly string[];
}

export function buildPrecallPrompt(input: PrecallInput): string {
  const lines: string[] = [];

  lines.push(
    `You are about to call ${input.contactName}${input.company ? ` at ${input.company}` : ''}${
      input.role ? `, ${input.role}` : ''
    }.`,
  );
  lines.push(`Deal: ${input.dealTitle}, currently at the ${input.stage} stage.`);

  if (input.daysSinceLastContact !== null) {
    lines.push(`Last spoke ${input.daysSinceLastContact} days ago.`);
  }

  const record: string[] = [];
  if (input.nextAction) record.push(`Next action on file: ${input.nextAction}`);
  if (input.deadlineLabel) record.push(`Deadline: ${input.deadlineLabel}`);
  if (input.budget) record.push(`Budget discussed: ${input.budget}`);
  if (input.concerns) record.push(`Concerns on file: ${input.concerns}`);
  if (record.length > 0) {
    lines.push('');
    lines.push('DEAL RECORD:');
    lines.push(...record.map((entry) => `- ${entry}`));
  }

  if (input.openReminders.length > 0) {
    lines.push('');
    lines.push('STILL OUTSTANDING:');
    lines.push(...input.openReminders.map((reminder) => `- ${reminder}`));
  }

  if (input.companyFacts.length > 0) {
    lines.push('');
    lines.push('RECENT COMPANY NEWS:');
    lines.push(...input.companyFacts.map((fact) => `- ${fact}`));
  }

  lines.push('');
  if (input.transcripts.length === 0) {
    lines.push('PREVIOUS CALLS: none. This is the first conversation.');
  } else {
    lines.push('PREVIOUS CALLS, verbatim, most recent first:');
    for (const transcript of input.transcripts.slice(0, 5)) {
      lines.push(`[${transcript.whenLabel}] ${transcript.text}`);
    }
  }

  lines.push('');
  lines.push('Write the brief.');

  return lines.join('\n');
}
