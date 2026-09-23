import { z } from 'zod';
import { getDb } from '@/lib/db';
import { reminders } from '@/lib/db/schema/reminders';
import { resolveDate, repairYear } from '@/lib/domain/dates';
import type { ToolDefinition, ToolContext, ToolOutcome } from './types';

const argsSchema = z.object({
  message: z.string().min(3).max(200),
  due: z.string().min(1),
});

export type SetReminderArgs = z.infer<typeof argsSchema>;

const jsonSchema = {
  type: 'object',
  properties: {
    message: {
      type: 'string',
      description:
        'What the user needs to do, phrased as an instruction to them, e.g. "Send Priya the revised pricing sheet".',
    },
    due: {
      type: 'string',
      description:
        'When to surface it. An ISO date is preferred, but a phrase from the memo such as "Thursday", "tomorrow morning" or "in three days" is accepted.',
    },
  },
  required: ['message', 'due'],
  additionalProperties: false,
} as const;

/**
 * Creating a nudge.
 *
 * Reversible, so the agent does this without asking — a wrong reminder costs one
 * dismissal, while a missing one costs a deal. When the date phrase cannot be
 * resolved the reminder is still created, dated one business-morning out, rather
 * than being dropped: an approximately-timed nudge is far more useful than
 * silence, and the summary says plainly that the timing was a guess.
 */
export const setReminderTool: ToolDefinition<SetReminderArgs> = {
  name: 'set_reminder',
  description:
    'Create a reminder for something the user must do. Use this whenever the memo contains a commitment, a promise, or a thing to chase. Prefer one reminder per distinct commitment.',
  parameters: argsSchema,
  jsonSchema,
  reversible: true,
  async execute(args: SetReminderArgs, context: ToolContext): Promise<ToolOutcome> {
    if (!context.dealId) {
      return {
        status: 'failed',
        summary: 'Could not set the reminder',
        error: 'No deal was resolved for this run.',
      };
    }

    const resolved = resolveDate(args.due, context.now);
    const guessed = resolved === null;
    const dueAt = resolved
      ? repairYear(resolved.date, context.now)
      : defaultDueDate(context.now);

    const [row] = await getDb()
      .insert(reminders)
      .values({
        dealId: context.dealId,
        message: args.message,
        dueAt,
        createdBy: context.source,
      })
      .returning();

    return {
      status: 'applied',
      summary: guessed
        ? `Set a reminder to ${lowerFirst(args.message)} — I could not pin down "${args.due}", so I put it on tomorrow`
        : `Set a reminder to ${lowerFirst(args.message)}`,
      created: { reminderId: row?.id, dueAt, guessedDate: guessed },
    };
  },
};

/** Tomorrow at 09:00 local. */
function defaultDueDate(now: Date): Date {
  const tomorrow = new Date(now.getTime() + 86_400_000);
  tomorrow.setHours(9, 0, 0, 0);
  return tomorrow;
}

function lowerFirst(text: string): string {
  if (!text) return text;
  // Leave acronyms and proper nouns alone; only fix a sentence-case opener.
  if (text.length > 1 && text[1] === text[1]?.toUpperCase() && /[A-Z]/.test(text[1] ?? '')) {
    return text;
  }
  return text.charAt(0).toLowerCase() + text.slice(1);
}
