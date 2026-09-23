import { randomUUID } from 'crypto';
import { eq, and, desc, inArray } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { contacts } from '@/lib/db/schema/contacts';
import { deals } from '@/lib/db/schema/deals';
import { notes } from '@/lib/db/schema/notes';
import { drafts } from '@/lib/db/schema/drafts';
import { reminders } from '@/lib/db/schema/reminders';
import { getEnv } from '@/lib/env';
import { chat } from '@/lib/nebius/chat';
import { TraceCollector, type TraceSummary } from '@/lib/nebius/trace';
import { wireTools } from '@/lib/agent/tools';
import { executeToolCalls, persistTraces, type ExecutedAction } from '@/lib/agent/runner';
import {
  REVIEW_SYSTEM_PROMPT,
  buildReviewPrompt,
  selectReviewCandidates,
  type ReviewDealContext,
} from '@/lib/agent/prompts/review';
import { loadOpenDealsForDrift } from '@/lib/repo/queries';
import { detectPipelineDrift } from '@/lib/domain/drift';
import { formatAgo, formatLongDate } from '@/lib/format';
import type { ToolContext } from '@/lib/agent/tools/types';

/**
 * The agent working while nobody watches.
 *
 * Structurally the same as the memo flow — gather context, let the model choose
 * tools, execute with auditing — with two deliberate differences:
 *
 *   - Only drafting and reminders are offered. The reviewer cannot move a deal's
 *     stage, because it has not spoken to anyone and has no standing to judge.
 *   - It runs on the REASONING tier. Picking three deals out of twenty on the
 *     strength of their notes is the one genuinely hard judgement in the product.
 */

export interface ReviewResult {
  runId: string;
  candidatesConsidered: number;
  actions: ExecutedAction[];
  traces: TraceSummary;
  /** Present when the reviewer deliberately did nothing. */
  noActionReason: string | null;
}

export async function runNightlyReview(now = new Date()): Promise<ReviewResult> {
  const env = getEnv();
  const db = getDb();
  const runId = randomUUID();
  const collector = new TraceCollector();

  const openDeals = await loadOpenDealsForDrift();
  const signals = detectPipelineDrift(openDeals, now);

  if (signals.length === 0) {
    return {
      runId,
      candidatesConsidered: 0,
      actions: [],
      traces: collector.summarise(),
      noActionReason: 'No deals have drifted, so there was nothing to review.',
    };
  }

  // Group signals by deal, preserving urgency order.
  const signalsByDeal = new Map<string, string[]>();
  for (const signal of signals) {
    const existing = signalsByDeal.get(signal.dealId) ?? [];
    existing.push(signal.explanation);
    signalsByDeal.set(signal.dealId, existing);
  }

  const driftedIds = [...signalsByDeal.keys()];

  const [dealRows, noteRows, draftRows, reminderRows] = await Promise.all([
    db
      .select({
        id: deals.id,
        stage: deals.stage,
        nextAction: deals.nextAction,
        deadline: deals.deadline,
        lastContactAt: deals.lastContactAt,
        contactId: contacts.id,
        contactName: contacts.name,
        company: contacts.company,
      })
      .from(deals)
      .innerJoin(contacts, eq(deals.contactId, contacts.id))
      .where(inArray(deals.id, driftedIds)),
    db
      .select({
        dealId: notes.dealId,
        rawTranscript: notes.rawTranscript,
        createdAt: notes.createdAt,
      })
      .from(notes)
      .where(inArray(notes.dealId, driftedIds))
      .orderBy(desc(notes.createdAt))
      .limit(60),
    db
      .select({ dealId: drafts.dealId })
      .from(drafts)
      .where(and(inArray(drafts.dealId, driftedIds), eq(drafts.status, 'draft'))),
    db
      .select({ dealId: reminders.dealId, message: reminders.message })
      .from(reminders)
      .where(and(inArray(reminders.dealId, driftedIds), eq(reminders.status, 'pending'))),
  ]);

  const dealsWithDrafts = new Set(draftRows.map((row) => row.dealId));

  const contexts: ReviewDealContext[] = dealRows.map((row) => ({
    dealId: row.id,
    contactName: row.contactName,
    company: row.company,
    stage: row.stage,
    signals: signalsByDeal.get(row.id) ?? [],
    nextAction: row.nextAction,
    deadlineLabel: row.deadline ? formatLongDate(row.deadline, env.RINGLY_TIMEZONE) : null,
    lastContactLabel: row.lastContactAt
      ? formatAgo(row.lastContactAt, now, env.RINGLY_TIMEZONE)
      : null,
    openReminders: reminderRows
      .filter((reminder) => reminder.dealId === row.id)
      .map((reminder) => reminder.message),
    hasPendingDraft: dealsWithDrafts.has(row.id),
    recentNotes: noteRows
      .filter((note) => note.dealId === row.id)
      .slice(0, 2)
      .map((note) => ({
        text: note.rawTranscript,
        whenLabel: formatAgo(note.createdAt, now, env.RINGLY_TIMEZONE),
      })),
  }));

  const candidates = selectReviewCandidates(contexts);

  if (candidates.length === 0) {
    return {
      runId,
      candidatesConsidered: 0,
      actions: [],
      traces: collector.summarise(),
      noActionReason: 'Every drifting deal already has a draft waiting for approval.',
    };
  }

  const plan = await chat({
    task: 'pipeline_review',
    messages: [
      { role: 'system', content: REVIEW_SYSTEM_PROMPT },
      {
        role: 'user',
        content: buildReviewPrompt(candidates, formatLongDate(now, env.RINGLY_TIMEZONE)),
      },
    ],
    // Only the two tools the reviewer is permitted to use.
    tools: wireTools(['draft_email', 'set_reminder']),
    temperature: 0.4,
    maxTokens: 1500,
    collector,
  });

  // Each call names its own deal, so tools run with that deal in context rather
  // than a single global one.
  const actions: ExecutedAction[] = [];

  for (const call of plan.toolCalls) {
    const dealId = inferDealId(call.rawArguments, candidates);
    const context: ToolContext = {
      runId,
      now,
      noteId: null,
      dealId,
      contactId: dealRows.find((row) => row.id === dealId)?.contactId ?? null,
      source: 'nightly_review',
      userName: env.RINGLY_USER_NAME,
      timezone: env.RINGLY_TIMEZONE,
    };
    const report = await executeToolCalls([call], context);
    actions.push(...report.actions);
  }

  const traces = collector.summarise();
  await persistTraces(runId, traces.traces);

  return {
    runId,
    candidatesConsidered: candidates.length,
    actions,
    traces,
    noActionReason:
      actions.length === 0
        ? plan.content.trim() || 'Reviewed the pipeline and judged that nothing warranted action.'
        : null,
  };
}

/**
 * Work out which deal a tool call is about.
 *
 * The prompt labels each deal with its id, and models reliably echo that id
 * somewhere in the arguments. Falling back to the most urgent candidate is
 * better than dropping the action, since the reviewer only ever sees drifting
 * deals and the list is ordered by urgency.
 */
export function inferDealId(
  rawArguments: string,
  candidates: readonly { dealId: string }[],
): string | null {
  for (const candidate of candidates) {
    if (rawArguments.includes(candidate.dealId)) return candidate.dealId;
  }
  return candidates[0]?.dealId ?? null;
}
