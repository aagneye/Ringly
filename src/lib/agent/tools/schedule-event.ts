import { z } from 'zod';
import { getDb } from '@/lib/db';
import { events } from '@/lib/db/schema/events';
import { resolveDate, repairYear } from '@/lib/domain/dates';
import type { ToolDefinition, ToolContext, ToolOutcome } from './types';

const argsSchema = z.object({
  title: z.string().min(3).max(160),
  start: z.string().min(1),
  duration_minutes: z.number().int().min(5).max(480).nullable().optional(),
  location: z.string().max(200).nullable().optional(),
  notes: z.string().max(600).nullable().optional(),
});

export type ScheduleEventArgs = z.infer<typeof argsSchema>;

const jsonSchema = {
  type: 'object',
  properties: {
    title: {
      type: 'string',
      description: 'Short meeting title, e.g. "Pricing walkthrough with Priya".',
    },
    start: {
      type: 'string',
      description:
        'When the meeting starts. ISO date-time preferred; a phrase from the memo such as "Friday" or "next Tuesday" is accepted.',
    },
    duration_minutes: {
      type: ['integer', 'null'],
      description: 'Length in minutes. Defaults to 30 when the memo does not say.',
    },
    location: {
      type: ['string', 'null'],
      description: 'Where it happens, or the call link if one was mentioned.',
    },
    notes: {
      type: ['string', 'null'],
      description: 'Anything to remember going in.',
    },
  },
  required: ['title', 'start'],
  additionalProperties: false,
} as const;

const DEFAULT_DURATION_MINUTES = 30;

/**
 * Putting a meeting on the calendar.
 *
 * Reversible because this writes to Ringly's own calendar, where a wrong entry
 * is one tap to delete and nobody outside is notified. If this ever pushes to an
 * external calendar that invites the client, it becomes irreversible and must be
 * reclassified — that is why the flag lives on the tool rather than in the
 * runner.
 *
 * An unresolvable start time fails loudly instead of guessing. A reminder on the
 * wrong day is a small annoyance; a meeting on the wrong day means standing
 * someone up.
 */
export const scheduleEventTool: ToolDefinition<ScheduleEventArgs> = {
  name: 'schedule_event',
  description:
    'Put a meeting or call on the calendar. Use this only when a specific meeting was agreed or proposed. Do not use it for tasks or follow-ups — those are reminders.',
  parameters: argsSchema,
  jsonSchema,
  reversible: true,
  async execute(args: ScheduleEventArgs, context: ToolContext): Promise<ToolOutcome> {
    if (!context.dealId) {
      return {
        status: 'failed',
        summary: 'Could not schedule the meeting',
        error: 'No deal was resolved for this run.',
      };
    }

    const resolved = resolveDate(args.start, context.now);
    if (!resolved) {
      return {
        status: 'failed',
        summary: `Could not schedule "${args.title}" — I did not understand "${args.start}"`,
        error: `Unresolvable start time: ${args.start}`,
      };
    }

    const startsAt = repairYear(resolved.date, context.now);
    const minutes = args.duration_minutes ?? DEFAULT_DURATION_MINUTES;
    const endsAt = new Date(startsAt.getTime() + minutes * 60_000);

    const [row] = await getDb()
      .insert(events)
      .values({
        dealId: context.dealId,
        title: args.title,
        startsAt,
        endsAt,
        location: args.location ?? null,
        notes: args.notes ?? null,
        createdBy: context.source,
      })
      .returning();

    return {
      status: 'applied',
      summary: `Scheduled "${args.title}" for ${formatWhen(startsAt, context.timezone)}`,
      created: { eventId: row?.id, startsAt, endsAt, approximate: resolved.precision !== 'exact' },
    };
  },
};

function formatWhen(date: Date, timeZone: string): string {
  try {
    return new Intl.DateTimeFormat('en-GB', {
      weekday: 'long',
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
      timeZone,
    }).format(date);
  } catch {
    // An invalid IANA zone from config should not take the tool down with it.
    return date.toISOString();
  }
}
