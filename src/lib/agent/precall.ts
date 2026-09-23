import { randomUUID } from 'crypto';
import { getEnv } from '@/lib/env';
import { structured } from '@/lib/nebius/structured';
import { TraceCollector } from '@/lib/nebius/trace';
import { persistTraces } from '@/lib/agent/runner';
import {
  PRECALL_SYSTEM_PROMPT,
  PRECALL_WIRE_SCHEMA,
  precallSchema,
  buildPrecallPrompt,
  type PrecallOutput,
} from '@/lib/agent/prompts/precall';
import { loadDealDetail } from '@/lib/repo/queries';
import { formatAgo, formatLongDate } from '@/lib/format';
import { daysBetween } from '@/lib/domain/drift';

/**
 * The pre-call brief for one deal.
 *
 * Not cached. A brief read five minutes before a call must reflect the memo
 * recorded ten minutes ago, and the BALANCED tier makes it cheap enough that
 * freshness beats reuse.
 */

export interface PrecallResult extends PrecallOutput {
  contactName: string;
  company: string | null;
  dealTitle: string;
  stage: string;
  runId: string;
  /** True when there was no history at all, so the UI can set expectations. */
  firstConversation: boolean;
}

export class DealNotFoundError extends Error {
  constructor(dealId: string) {
    super(`Deal ${dealId} was not found.`);
    this.name = 'DealNotFoundError';
  }
}

export async function getPrecallBrief(dealId: string, now = new Date()): Promise<PrecallResult> {
  const env = getEnv();
  const detail = await loadDealDetail(dealId, now);
  if (!detail) throw new DealNotFoundError(dealId);

  const { deal, notes, reminders, facts } = detail;

  const collector = new TraceCollector();
  const runId = randomUUID();

  const { data } = await structured({
    task: 'precall_brief',
    schema: precallSchema,
    wireSchema: PRECALL_WIRE_SCHEMA,
    system: PRECALL_SYSTEM_PROMPT,
    user: buildPrecallPrompt({
      contactName: deal.contactName,
      company: deal.company,
      role: deal.role,
      dealTitle: deal.title,
      stage: deal.stage,
      nextAction: deal.nextAction,
      deadlineLabel: deal.deadline ? formatLongDate(deal.deadline, env.RINGLY_TIMEZONE) : null,
      budget: deal.budget,
      concerns: deal.concerns,
      daysSinceLastContact: deal.lastContactAt ? daysBetween(deal.lastContactAt, now) : null,
      transcripts: notes.map((note) => ({
        text: note.rawTranscript,
        whenLabel: formatAgo(note.createdAt, now, env.RINGLY_TIMEZONE),
      })),
      openReminders: reminders
        .filter((reminder) => reminder.status === 'pending')
        .map((reminder) => reminder.message),
      companyFacts: facts.map((fact) => fact.fact),
    }),
    temperature: 0.3,
    maxTokens: 1200,
    collector,
  });

  await persistTraces(runId, collector.all());

  return {
    ...data,
    contactName: deal.contactName,
    company: deal.company,
    dealTitle: deal.title,
    stage: deal.stage,
    runId,
    firstConversation: notes.length === 0,
  };
}
