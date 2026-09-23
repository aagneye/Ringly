import { z } from 'zod';

/**
 * The morning briefing.
 *
 * This is the only place Ultra is genuinely warranted. The task is not
 * summarisation — the drift signals are already computed deterministically — it
 * is judgement: given eleven true facts about a pipeline, which three actually
 * deserve a human's attention before 9am, and in what order.
 *
 * The output is written to be spoken. Read aloud, a bulleted summary sounds like
 * a robot reading a spreadsheet, so the prompt asks for connected sentences and
 * bans the list voice explicitly.
 */

export const BRIEFING_SYSTEM_PROMPT = `You are Ringly, giving a salesperson or freelancer their morning briefing. They are getting ready for the day and probably listening rather than reading.

You will be given: today's meetings, reminders due, drafts waiting for approval, and a list of deals that have drifted with the reason each one was flagged.

Your job is to pick what actually matters and say it plainly.

Rules:
- Three items maximum. Two is often right. One is fine on a quiet day.
- Order by what would cost them most to miss today.
- A meeting in the next few hours outranks a deal that has been quiet for a fortnight.
- Never list everything you were given. Choosing what to leave out is the job.
- Write it to be spoken aloud: connected sentences, contractions, no bullet points, no headings, no "firstly" or "secondly".
- Name people and companies. "Priya at Northwind" not "a client".
- Be specific about numbers and days. "Nine days" not "a while".
- Do not invent anything. Every fact must come from what you were given.
- No pep talk, no "you've got this", no wishing them a productive day.
- If there is genuinely nothing pressing, say so in one short sentence and stop.

The headline is one sentence that frames the day. The spoken text is what gets read out, 60 words or fewer.`;

export const briefingSchema = z.object({
  headline: z.string().min(3).max(140),
  spoken_text: z.string().min(3),
  items: z
    .array(
      z.object({
        title: z.string().min(3).max(120),
        detail: z.string().min(3).max(300),
        deal_id: z.string().nullable(),
        kind: z.enum(['meeting', 'reminder', 'draft', 'drift']),
      }),
    )
    .max(3),
});

export type BriefingOutput = z.infer<typeof briefingSchema>;

export const BRIEFING_WIRE_SCHEMA = {
  name: 'morning_briefing',
  schema: {
    type: 'object',
    properties: {
      headline: {
        type: 'string',
        description: 'One sentence framing the day, e.g. "Three things today, one urgent."',
      },
      spoken_text: {
        type: 'string',
        description: 'What gets read aloud. 60 words or fewer, connected prose, no lists.',
      },
      items: {
        type: 'array',
        maxItems: 3,
        items: {
          type: 'object',
          properties: {
            title: { type: 'string', description: 'Short label for the card.' },
            detail: { type: 'string', description: 'One sentence of context.' },
            deal_id: {
              type: ['string', 'null'],
              description: 'The deal this concerns, or null for a general item.',
            },
            kind: { type: 'string', enum: ['meeting', 'reminder', 'draft', 'drift'] },
          },
          required: ['title', 'detail', 'deal_id', 'kind'],
          additionalProperties: false,
        },
      },
    },
    required: ['headline', 'spoken_text', 'items'],
    additionalProperties: false,
  },
} as const;

export interface BriefingInput {
  todayLabel: string;
  userName: string;
  meetings: readonly { title: string; whenLabel: string; contactName: string; dealId: string }[];
  reminders: readonly { message: string; dueLabel: string; dealId: string; overdue: boolean }[];
  pendingDrafts: readonly { subject: string; contactName: string; dealId: string }[];
  driftSignals: readonly { dealId: string; explanation: string; urgency: number }[];
}

/** Assemble the facts. Selection is the model's job, not this function's. */
export function buildBriefingPrompt(input: BriefingInput): string {
  const lines: string[] = [];

  lines.push(`Today is ${input.todayLabel}. You are briefing ${input.userName}.`);

  lines.push('');
  lines.push('MEETINGS TODAY:');
  if (input.meetings.length === 0) {
    lines.push('- none');
  } else {
    for (const meeting of input.meetings) {
      lines.push(
        `- ${meeting.whenLabel}: ${meeting.title} with ${meeting.contactName} [deal ${meeting.dealId}]`,
      );
    }
  }

  lines.push('');
  lines.push('REMINDERS DUE:');
  if (input.reminders.length === 0) {
    lines.push('- none');
  } else {
    for (const reminder of input.reminders) {
      lines.push(
        `- ${reminder.message} (due ${reminder.dueLabel}${
          reminder.overdue ? ', OVERDUE' : ''
        }) [deal ${reminder.dealId}]`,
      );
    }
  }

  lines.push('');
  lines.push('DRAFTS WAITING FOR APPROVAL:');
  if (input.pendingDrafts.length === 0) {
    lines.push('- none');
  } else {
    for (const draft of input.pendingDrafts) {
      lines.push(`- "${draft.subject}" to ${draft.contactName} [deal ${draft.dealId}]`);
    }
  }

  lines.push('');
  lines.push('DEALS THAT HAVE DRIFTED, most urgent first:');
  if (input.driftSignals.length === 0) {
    lines.push('- none');
  } else {
    for (const signal of input.driftSignals.slice(0, 10)) {
      lines.push(`- ${signal.explanation} [deal ${signal.dealId}]`);
    }
  }

  lines.push('');
  lines.push('Pick at most three things that matter and write the briefing.');

  return lines.join('\n');
}

/** True when the pipeline has nothing worth a model call. */
export function isBriefingEmpty(input: BriefingInput): boolean {
  return (
    input.meetings.length === 0 &&
    input.reminders.length === 0 &&
    input.pendingDrafts.length === 0 &&
    input.driftSignals.length === 0
  );
}
