import { randomUUID } from 'crypto';
import { getEnv } from '@/lib/env';
import { structured } from '@/lib/nebius/structured';
import { TraceCollector } from '@/lib/nebius/trace';
import { persistTraces } from '@/lib/agent/runner';
import {
  ASK_SYSTEM_PROMPT,
  ASK_WIRE_SCHEMA,
  askSchema,
  buildAskPrompt,
  selectRelevantDeals,
  type AskContextDeal,
} from '@/lib/agent/prompts/ask';
import { loadBoard, loadRecentTranscripts } from '@/lib/repo/queries';
import { formatAgo, formatLongDate } from '@/lib/format';

/**
 * Answering a spoken question from the note history.
 *
 * Relevant deals are narrowed by keyword before any transcript is loaded, which
 * keeps the prompt small and the answer grounded. Loading every note for every
 * deal would technically work and would also make the model's job harder, not
 * easier — more context is not better context when most of it is noise.
 */

export interface AskResult {
  question: string;
  answer: string;
  referencedDealIds: string[];
  insufficientInformation: boolean;
  runId: string;
}

export async function askRingly(question: string, now = new Date()): Promise<AskResult> {
  const env = getEnv();
  const board = await loadBoard(now);
  const allDeals = board.columns.flatMap((column) => column.deals);

  const relevant = selectRelevantDeals(question, allDeals, 4);

  const contexts: AskContextDeal[] = await Promise.all(
    relevant.map(async (deal): Promise<AskContextDeal> => {
      const transcripts = await loadRecentTranscripts(deal.contactId, 4);
      return {
        dealId: deal.id,
        contactName: deal.contactName,
        company: deal.company,
        stage: deal.stage,
        nextAction: deal.nextAction,
        deadlineLabel: deal.deadline ? formatLongDate(deal.deadline, env.RINGLY_TIMEZONE) : null,
        budget: deal.budget,
        concerns: null,
        lastContactLabel: deal.lastContactAt
          ? formatAgo(deal.lastContactAt, now, env.RINGLY_TIMEZONE)
          : null,
        notes: transcripts.map((note) => ({
          text: note.rawTranscript,
          whenLabel: formatAgo(note.createdAt, now, env.RINGLY_TIMEZONE),
        })),
      };
    }),
  );

  const collector = new TraceCollector();
  const runId = randomUUID();

  const { data } = await structured({
    task: 'answer_question',
    schema: askSchema,
    wireSchema: ASK_WIRE_SCHEMA,
    system: ASK_SYSTEM_PROMPT,
    user: buildAskPrompt(question, contexts, formatLongDate(now, env.RINGLY_TIMEZONE)),
    temperature: 0.2,
    maxTokens: 700,
    collector,
  });

  await persistTraces(runId, collector.all());

  return {
    question,
    answer: data.answer,
    referencedDealIds: data.referenced_deal_ids,
    insufficientInformation: data.insufficient_information,
    runId,
  };
}
