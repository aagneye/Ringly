import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { companyFacts } from '@/lib/db/schema/company-facts';
import { contacts } from '@/lib/db/schema/contacts';
import { search, TavilyNotConfiguredError } from '@/lib/tavily';
import { structured } from '@/lib/nebius/structured';
import type { ToolDefinition, ToolContext, ToolOutcome } from './types';

const argsSchema = z.object({
  company: z.string().min(2).max(120),
});

export type LookupCompanyArgs = z.infer<typeof argsSchema>;

const jsonSchema = {
  type: 'object',
  properties: {
    company: {
      type: 'string',
      description: 'The company name to research, as mentioned in the memo.',
    },
  },
  required: ['company'],
  additionalProperties: false,
} as const;

const factsSchema = z.object({
  facts: z
    .array(
      z.object({
        fact: z.string().min(10).max(220),
        source_index: z.number().int().min(0),
      }),
    )
    .max(3),
});

const FACTS_WIRE_SCHEMA = {
  name: 'company_facts',
  schema: {
    type: 'object',
    properties: {
      facts: {
        type: 'array',
        maxItems: 3,
        items: {
          type: 'object',
          properties: {
            fact: {
              type: 'string',
              description:
                'One sentence a salesperson could usefully mention on a call. Concrete and dated where possible.',
            },
            source_index: {
              type: 'integer',
              description: 'Index of the search result this fact came from.',
            },
          },
          required: ['fact', 'source_index'],
          additionalProperties: false,
        },
      },
    },
    required: ['facts'],
    additionalProperties: false,
  },
} as const;

const SYSTEM_PROMPT = `You turn web search results about a company into facts a salesperson can use on a call.

Rules:
- At most three facts. Fewer is fine. Zero is correct when nothing useful is there.
- Each fact must be something that would change how you talk to this company: funding, a launch, an acquisition, a leadership change, expansion, layoffs, a named customer win.
- Ignore boilerplate: "is a leading provider of", career pages, generic about-us copy, directory listings.
- Never state anything the search results do not support. No inference about their budget or intent.
- Attribute every fact to the index of the result it came from.
- Concrete beats vague. "Raised a $12M Series A in August 2026" is useful; "is growing quickly" is not.`;

/**
 * Enriching a company from the open web.
 *
 * Two stages rather than one: Tavily retrieves, then a fast Nemotron call
 * distils. Handing raw search snippets to the email drafter produced emails that
 * quoted marketing copy back at the client, so the distillation step exists to
 * discard boilerplate before anything reaches the drafting prompt.
 *
 * Degrades quietly. No Tavily key, no results, or a model that finds nothing
 * worth saying all end the same way: the tool reports it found nothing and the
 * run continues.
 */
export const lookupCompanyTool: ToolDefinition<LookupCompanyArgs> = {
  name: 'lookup_company',
  description:
    "Search the web for recent news about the contact's company. Use this when a company is mentioned that has no facts on file yet, or when the user asks what is going on with them. Do not use it for companies you have already researched in this run.",
  parameters: argsSchema,
  jsonSchema,
  reversible: true,
  async execute(args: LookupCompanyArgs, context: ToolContext): Promise<ToolOutcome> {
    if (!context.contactId) {
      return {
        status: 'failed',
        summary: 'Could not research the company',
        error: 'No contact was resolved for this run.',
      };
    }

    let hits;
    try {
      hits = await search({
        query: `${args.company} company news funding launch announcement`,
        topic: 'news',
        days: 180,
        maxResults: 5,
      });
    } catch (error) {
      if (error instanceof TavilyNotConfiguredError) {
        return {
          status: 'failed',
          summary: 'Skipped the company lookup — web search is not configured',
          error: error.message,
        };
      }
      return {
        status: 'failed',
        summary: `Could not research ${args.company}`,
        error: error instanceof Error ? error.message : String(error),
      };
    }

    if (hits.length === 0) {
      return {
        status: 'applied',
        summary: `Searched for ${args.company} but found nothing recent`,
      };
    }

    const numbered = hits
      .map((hit, index) => `[${index}] ${hit.title}\n${hit.content.slice(0, 600)}`)
      .join('\n\n');

    const { data } = await structured({
      task: 'summarise_contact',
      schema: factsSchema,
      wireSchema: FACTS_WIRE_SCHEMA,
      system: SYSTEM_PROMPT,
      user: `Company: ${args.company}\n\nSearch results:\n${numbered}`,
      temperature: 0.1,
      maxTokens: 600,
    });

    if (data.facts.length === 0) {
      return {
        status: 'applied',
        summary: `Searched for ${args.company} but nothing was worth noting`,
      };
    }

    const db = getDb();

    // Replace rather than accumulate: stale funding news sitting alongside
    // fresher news is worse than either alone.
    await db.delete(companyFacts).where(eq(companyFacts.contactId, context.contactId));

    const rows = data.facts.flatMap((entry) => {
      const hit = hits[entry.source_index];
      if (!hit) return [];
      return [
        {
          contactId: context.contactId as string,
          company: args.company,
          fact: entry.fact,
          sourceUrl: hit.url,
          sourceTitle: hit.title,
        },
      ];
    });

    if (rows.length === 0) {
      return {
        status: 'applied',
        summary: `Searched for ${args.company} but could not attribute any facts`,
      };
    }

    await db.insert(companyFacts).values(rows);

    // Backfill the company on the contact if the memo taught us something new.
    await db
      .update(contacts)
      .set({ company: args.company, updatedAt: context.now })
      .where(eq(contacts.id, context.contactId));

    return {
      status: 'applied',
      summary: `Found ${rows.length} recent ${rows.length === 1 ? 'fact' : 'facts'} about ${args.company}`,
      created: { facts: rows.map((row) => ({ fact: row.fact, source: row.sourceUrl })) },
    };
  },
};
