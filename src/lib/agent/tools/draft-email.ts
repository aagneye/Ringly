import { z } from 'zod';
import { eq, desc } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { drafts } from '@/lib/db/schema/drafts';
import { deals } from '@/lib/db/schema/deals';
import { contacts } from '@/lib/db/schema/contacts';
import { notes } from '@/lib/db/schema/notes';
import { companyFacts } from '@/lib/db/schema/company-facts';
import { structured } from '@/lib/nebius/structured';
import { buildEmailPrompt, EMAIL_SYSTEM_PROMPT, EMAIL_WIRE_SCHEMA } from '@/lib/agent/prompts/email';
import type { ToolDefinition, ToolContext, ToolOutcome } from './types';

const argsSchema = z.object({
  occasion: z.enum(['after_call', 'gone_quiet', 'deadline_approaching']).default('after_call'),
  instruction: z.string().max(400).nullable().optional(),
});

export type DraftEmailArgs = z.infer<typeof argsSchema>;

const jsonSchema = {
  type: 'object',
  properties: {
    occasion: {
      type: 'string',
      enum: ['after_call', 'gone_quiet', 'deadline_approaching'],
      description: 'Why this email is being written now.',
    },
    instruction: {
      type: ['string', 'null'],
      description:
        'Any specific steer from the user about what the email should say, if they stated one.',
    },
  },
  required: ['occasion'],
  additionalProperties: false,
} as const;

const emailSchema = z.object({
  subject: z.string().min(1).max(200),
  body: z.string().min(1),
});

/**
 * Writing the follow-up email.
 *
 * This is the only tool marked irreversible. Sending an email cannot be undone
 * and a wrong one damages a real relationship, so the agent is allowed to write
 * but never to send: the row lands with status 'draft' and the run reports it as
 * awaiting approval.
 *
 * Note this tool makes its own model call, on the BALANCED tier. Extraction is
 * cheap and schema-bound, but tone is the product here, so the extra cost is the
 * point rather than an oversight.
 */
export const draftEmailTool: ToolDefinition<DraftEmailArgs> = {
  name: 'draft_email',
  description:
    'Write a follow-up email to the contact. Use this when the memo implies the user owes them a message, or when re-opening a conversation that has gone quiet. The email is never sent automatically — the user approves it first.',
  parameters: argsSchema,
  jsonSchema,
  reversible: false,
  async execute(args: DraftEmailArgs, context: ToolContext): Promise<ToolOutcome> {
    if (!context.dealId) {
      return {
        status: 'failed',
        summary: 'Could not draft the email',
        error: 'No deal was resolved for this run.',
      };
    }

    const db = getDb();

    const [deal] = await db
      .select({
        title: deals.title,
        stage: deals.stage,
        nextAction: deals.nextAction,
        deadline: deals.deadline,
        concerns: deals.concerns,
        budget: deals.budget,
        contactName: contacts.name,
        company: contacts.company,
        contactId: contacts.id,
      })
      .from(deals)
      .innerJoin(contacts, eq(deals.contactId, contacts.id))
      .where(eq(deals.id, context.dealId))
      .limit(1);

    if (!deal) {
      return {
        status: 'failed',
        summary: 'Could not draft the email',
        error: `Deal ${context.dealId} not found.`,
      };
    }

    const history = await db
      .select({ rawTranscript: notes.rawTranscript })
      .from(notes)
      .where(eq(notes.dealId, context.dealId))
      .orderBy(desc(notes.createdAt))
      .limit(3);

    const facts = await db
      .select({ fact: companyFacts.fact })
      .from(companyFacts)
      .where(eq(companyFacts.contactId, deal.contactId))
      .limit(3);

    const prompt = buildEmailPrompt({
      userName: context.userName,
      contactName: deal.contactName,
      company: deal.company,
      stage: deal.stage,
      nextAction: deal.nextAction,
      deadlineText: deal.deadline ? deal.deadline.toDateString() : null,
      concerns: deal.concerns,
      budget: deal.budget,
      recentTranscripts: history.map((row) => row.rawTranscript),
      companyFacts: facts.map((row) => row.fact),
      occasion: args.occasion,
    });

    const userPrompt = args.instruction
      ? `${prompt}\n\nThe user specifically asked: ${args.instruction}`
      : prompt;

    const { data } = await structured({
      task: 'draft_email',
      schema: emailSchema,
      wireSchema: EMAIL_WIRE_SCHEMA,
      system: EMAIL_SYSTEM_PROMPT,
      user: userPrompt,
      // Higher than extraction: an email at temperature 0.1 reads like a form
      // letter, and sounding human is the entire value of this step.
      temperature: 0.6,
      maxTokens: 700,
    });

    const [row] = await db
      .insert(drafts)
      .values({
        dealId: context.dealId,
        subject: data.subject,
        body: data.body,
        status: 'draft',
        reasoning: reasoningFor(args.occasion, deal.contactName),
      })
      .returning();

    return {
      status: 'awaiting_approval',
      summary: `Drafted an email to ${deal.contactName} — waiting for your approval`,
      created: { draftId: row?.id, subject: data.subject, body: data.body },
    };
  },
};

function reasoningFor(occasion: DraftEmailArgs['occasion'], contactName: string): string {
  switch (occasion) {
    case 'gone_quiet':
      return `${contactName} has not been contacted in a while and the deal is still open.`;
    case 'deadline_approaching':
      return `A deadline on ${contactName}'s deal is close.`;
    case 'after_call':
    default:
      return `You just spoke to ${contactName} and owe them a follow-up.`;
  }
}
