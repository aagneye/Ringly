import { randomUUID } from 'crypto';
import { getDb } from '@/lib/db';
import { notes } from '@/lib/db/schema/notes';
import { deals } from '@/lib/db/schema/deals';
import { eq } from 'drizzle-orm';
import { getEnv } from '@/lib/env';
import { chat } from '@/lib/nebius/chat';
import { structured } from '@/lib/nebius/structured';
import { TraceCollector, type TraceSummary } from '@/lib/nebius/trace';
import { wireTools } from '@/lib/agent/tools';
import { executeToolCalls, persistTraces, type RunReport } from '@/lib/agent/runner';
import {
  EXTRACTION_SYSTEM_PROMPT,
  EXTRACTION_WIRE_SCHEMA,
  buildExtractionPrompt,
  extractionSchema,
  normaliseExtraction,
  type Extraction,
} from '@/lib/agent/prompts/extract';
import { PLANNER_SYSTEM_PROMPT, buildPlannerPrompt } from '@/lib/agent/prompts/planner';
import {
  resolveTarget,
  knownContactNames,
  type ResolvedTarget,
} from '@/lib/repo/resolve-target';
import { loadOpenReminderMessages, hasCompanyFacts } from '@/lib/repo/queries';
import { daysBetween } from '@/lib/domain/drift';
import type { ToolContext } from '@/lib/agent/tools/types';

/**
 * The core loop: a transcript becomes a set of actions that actually happened.
 *
 * Three model calls, on three different tiers, for three different reasons:
 *
 *   1. Extraction on the FAST tier. Runs on every memo, schema-bound, so latency
 *      matters and model quality barely does.
 *   2. Planning on the BALANCED tier with tools attached. This is the decision
 *      step — the model, not this code, picks which actions to take.
 *   3. Drafting on BALANCED again, but only if the planner asked for it, and
 *      billed inside the tool rather than here.
 *
 * Identity resolution sits deliberately between steps 1 and 2. The planner
 * cannot be trusted to work out which stored contact "Priya" is, and every tool
 * needs a concrete deal id before it can run.
 */

export interface MemoInput {
  transcript: string;
  durationSeconds?: number;
  source: 'voice' | 'text';
}

export interface MemoResult {
  runId: string;
  noteId: string;
  transcript: string;
  extraction: Extraction;
  target: ResolvedTarget;
  report: RunReport;
  traces: TraceSummary;
  /** Present when the planner chose to take no action at all. */
  noActionReason: string | null;
}

export async function processMemo(input: MemoInput, now = new Date()): Promise<MemoResult> {
  const env = getEnv();
  const collector = new TraceCollector();
  const runId = randomUUID();
  const db = getDb();

  // ---- 1. Extract -----------------------------------------------------------
  const roster = await knownContactNames();
  const extractionResult = await structured({
    task: 'extract',
    schema: extractionSchema,
    wireSchema: EXTRACTION_WIRE_SCHEMA,
    system: EXTRACTION_SYSTEM_PROMPT,
    user: buildExtractionPrompt(input.transcript, roster),
    temperature: 0.1,
    maxTokens: 800,
    collector,
  });
  const extraction = normaliseExtraction(extractionResult.data);

  // ---- 2. Resolve identity --------------------------------------------------
  const target = await resolveTarget(extraction.contact_name, extraction.company, now);

  // Store the note before planning, so a planner failure still preserves what
  // the user said. Losing a transcript is the one unrecoverable failure here.
  const [note] = await db
    .insert(notes)
    .values({
      dealId: target.dealId,
      contactId: target.contactId,
      rawTranscript: input.transcript,
      gist: extraction.gist,
      structured: extraction,
      durationSeconds: input.durationSeconds ?? null,
      source: input.source,
    })
    .returning({ id: notes.id });

  const noteId = note?.id ?? null;

  // ---- 3. Plan --------------------------------------------------------------
  const [openReminders, factsCached] = await Promise.all([
    loadOpenReminderMessages(target.dealId),
    hasCompanyFacts(target.contactId),
  ]);

  const plannerPrompt = buildPlannerPrompt({
    extraction,
    transcript: input.transcript,
    contactName: target.contactName,
    company: target.company,
    dealTitle: target.dealTitle,
    currentStage: target.stage,
    hasCompanyFacts: factsCached,
    openReminders,
    daysSinceLastContact: target.lastContactAt ? daysBetween(target.lastContactAt, now) : null,
    todayLabel: formatToday(now, env.RINGLY_TIMEZONE),
  });

  const plan = await chat({
    task: 'plan_actions',
    messages: [
      { role: 'system', content: PLANNER_SYSTEM_PROMPT },
      { role: 'user', content: plannerPrompt },
    ],
    tools: wireTools(),
    temperature: 0.3,
    maxTokens: 1200,
    collector,
  });

  // ---- 4. Execute -----------------------------------------------------------
  const context: ToolContext = {
    runId,
    now,
    noteId,
    dealId: target.dealId,
    contactId: target.contactId,
    source: 'memo',
    userName: env.RINGLY_USER_NAME,
    timezone: env.RINGLY_TIMEZONE,
  };

  const report = await executeToolCalls(plan.toolCalls, context);

  // A memo is evidence of contact even when the planner changed nothing, so the
  // timestamp is stamped here rather than relying on update_deal being called.
  await db
    .update(deals)
    .set({ lastContactAt: now, updatedAt: now })
    .where(eq(deals.id, target.dealId));

  const traces = collector.summarise();
  await persistTraces(runId, traces.traces);

  return {
    runId,
    noteId: noteId ?? '',
    transcript: input.transcript,
    extraction,
    target,
    report,
    traces,
    noActionReason:
      report.actions.length === 0
        ? plan.content.trim() || 'Nothing in this memo needed an action.'
        : null,
  };
}

function formatToday(now: Date, timeZone: string): string {
  try {
    return new Intl.DateTimeFormat('en-GB', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      timeZone,
    }).format(now);
  } catch {
    return now.toDateString();
  }
}
