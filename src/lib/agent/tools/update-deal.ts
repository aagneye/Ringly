import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { deals } from '@/lib/db/schema/deals';
import { DEAL_STAGES } from '@/lib/db/schema/enums';
import { resolveDate, repairYear } from '@/lib/domain/dates';
import type { ToolDefinition, ToolContext, ToolOutcome } from './types';

const argsSchema = z.object({
  stage: z.enum(DEAL_STAGES).nullable().optional(),
  next_action: z.string().max(280).nullable().optional(),
  deadline: z.string().nullable().optional(),
  budget: z.string().max(80).nullable().optional(),
  concerns: z.string().max(600).nullable().optional(),
  sentiment: z.enum(['positive', 'neutral', 'negative']).nullable().optional(),
});

export type UpdateDealArgs = z.infer<typeof argsSchema>;

const jsonSchema = {
  type: 'object',
  properties: {
    stage: {
      type: ['string', 'null'],
      enum: [...DEAL_STAGES, null],
      description:
        'Move the deal to this pipeline stage. Only set it when the conversation actually justifies a move.',
    },
    next_action: {
      type: ['string', 'null'],
      description: 'The single concrete thing the user committed to doing next.',
    },
    deadline: {
      type: ['string', 'null'],
      description:
        'When the next action is due. An ISO date is preferred, but a phrase heard in the memo such as "Friday" or "end of next week" is accepted.',
    },
    budget: {
      type: ['string', 'null'],
      description: 'Budget as the client expressed it, verbatim, e.g. "around 12k".',
    },
    concerns: {
      type: ['string', 'null'],
      description: 'Objections or worries the client raised, in their own words where possible.',
    },
    sentiment: {
      type: ['string', 'null'],
      enum: ['positive', 'neutral', 'negative', null],
      description: 'How the conversation felt overall.',
    },
  },
  required: [],
  additionalProperties: false,
} as const;

/**
 * Writing the memo back onto the deal record.
 *
 * Every field is optional and null means "not mentioned", never "clear this".
 * That distinction is the whole reason this tool is hand-written rather than a
 * generic patch: a memo about scheduling should not wipe the budget captured
 * three calls ago just because it went unmentioned today.
 */
export const updateDealTool: ToolDefinition<UpdateDealArgs> = {
  name: 'update_deal',
  description:
    'Update the deal record for the contact this memo is about. Use it to move the pipeline stage, record what happens next, capture budget, or note concerns the client raised. Omit any field the conversation did not mention.',
  parameters: argsSchema,
  jsonSchema,
  reversible: true,
  async execute(args: UpdateDealArgs, context: ToolContext): Promise<ToolOutcome> {
    if (!context.dealId) {
      return {
        status: 'failed',
        summary: 'Could not update the deal',
        error: 'No deal was resolved for this run.',
      };
    }

    const patch: Record<string, unknown> = { updatedAt: context.now };
    const changes: string[] = [];

    if (args.stage) {
      patch.stage = args.stage;
      changes.push(`stage to ${args.stage}`);
    }
    if (args.next_action) {
      patch.nextAction = args.next_action;
      changes.push('next step');
    }
    if (args.budget) {
      patch.budget = args.budget;
      changes.push('budget');
    }
    if (args.concerns) {
      patch.concerns = args.concerns;
      changes.push('concerns');
    }
    if (args.sentiment) {
      patch.sentiment = args.sentiment;
    }

    if (args.deadline) {
      const resolved = resolveDate(args.deadline, context.now);
      if (resolved) {
        patch.deadline = repairYear(resolved.date, context.now);
        changes.push('deadline');
      }
    }

    // A memo is evidence of contact, regardless of which fields it touched.
    if (context.source === 'memo') {
      patch.lastContactAt = context.now;
    }

    if (changes.length === 0 && !args.sentiment) {
      return {
        status: 'applied',
        summary: 'Logged the call with no field changes',
        created: { dealId: context.dealId },
      };
    }

    await getDb().update(deals).set(patch).where(eq(deals.id, context.dealId));

    return {
      status: 'applied',
      summary: `Updated ${formatChangeList(changes)}`,
      created: { dealId: context.dealId, ...patch },
    };
  },
};

function formatChangeList(changes: string[]): string {
  if (changes.length === 0) return 'the deal';
  if (changes.length === 1) return changes[0] ?? 'the deal';
  const head = changes.slice(0, -1).join(', ');
  return `${head} and ${changes[changes.length - 1]}`;
}
