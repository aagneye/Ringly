import { randomUUID } from 'crypto';
import { eq } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { briefings } from '@/lib/db/schema/briefings';
import { getEnv } from '@/lib/env';
import { structured } from '@/lib/nebius/structured';
import { TraceCollector } from '@/lib/nebius/trace';
import { persistTraces } from '@/lib/agent/runner';
import {
  BRIEFING_SYSTEM_PROMPT,
  BRIEFING_WIRE_SCHEMA,
  briefingSchema,
  buildBriefingPrompt,
  isBriefingEmpty,
  type BriefingInput,
  type BriefingOutput,
} from '@/lib/agent/prompts/briefing';
import {
  loadDueReminders,
  loadTodaysEvents,
  loadPendingDrafts,
  loadOpenDealsForDrift,
} from '@/lib/repo/queries';
import { detectPipelineDrift } from '@/lib/domain/drift';
import { formatDateKey, formatClock, formatRelativeDay } from '@/lib/format';

/**
 * The morning briefing, computed once a day.
 *
 * Ultra is the most expensive call in the product, and the briefing does not
 * change between two page loads on the same morning, so the result is cached by
 * calendar day. `force` exists for the demo: a judge watching the video needs to
 * see it generate, not read yesterday's cache.
 */

export interface BriefingResult {
  headline: string;
  spokenText: string;
  items: BriefingOutput['items'];
  cached: boolean;
  empty: boolean;
  runId: string | null;
}

export async function getBriefing(now = new Date(), force = false): Promise<BriefingResult> {
  const env = getEnv();
  const db = getDb();
  const dateKey = formatDateKey(now, env.RINGLY_TIMEZONE);

  if (!force) {
    const [existing] = await db
      .select()
      .from(briefings)
      .where(eq(briefings.forDate, dateKey))
      .limit(1);

    if (existing) {
      return {
        headline: existing.headline,
        spokenText: existing.spokenText,
        items: (existing.items as BriefingOutput['items']) ?? [],
        cached: true,
        empty: false,
        runId: existing.runId,
      };
    }
  }

  const [reminders, events, drafts, openDeals] = await Promise.all([
    loadDueReminders(now),
    loadTodaysEvents(now),
    loadPendingDrafts(),
    loadOpenDealsForDrift(),
  ]);

  const driftSignals = detectPipelineDrift(openDeals, now);

  const input: BriefingInput = {
    todayLabel: formatRelativeDay(now, now, env.RINGLY_TIMEZONE),
    userName: env.RINGLY_USER_NAME,
    meetings: events.map((event) => ({
      title: event.title,
      whenLabel: formatClock(event.startsAt, env.RINGLY_TIMEZONE),
      contactName: event.contactName,
      dealId: event.dealId,
    })),
    reminders: reminders.map((reminder) => ({
      message: reminder.message,
      dueLabel: formatRelativeDay(reminder.dueAt, now, env.RINGLY_TIMEZONE),
      dealId: reminder.dealId,
      overdue: reminder.dueAt.getTime() < now.getTime(),
    })),
    pendingDrafts: drafts.map((draft) => ({
      subject: draft.subject,
      contactName: draft.contactName,
      dealId: draft.dealId,
    })),
    driftSignals: driftSignals.map((signal) => ({
      dealId: signal.dealId,
      explanation: signal.explanation,
      urgency: signal.urgency,
    })),
  };

  // Nothing to reason about means no reason to spend an Ultra call.
  if (isBriefingEmpty(input)) {
    return {
      headline: 'Nothing pressing today.',
      spokenText: 'Your pipeline is quiet. Nothing needs you before this evening.',
      items: [],
      cached: false,
      empty: true,
      runId: null,
    };
  }

  const collector = new TraceCollector();
  const runId = randomUUID();

  const { data } = await structured({
    task: 'morning_briefing',
    schema: briefingSchema,
    wireSchema: BRIEFING_WIRE_SCHEMA,
    system: BRIEFING_SYSTEM_PROMPT,
    user: buildBriefingPrompt(input),
    temperature: 0.4,
    maxTokens: 1000,
    collector,
  });

  await persistTraces(runId, collector.all());

  // Upsert so a forced regeneration replaces rather than duplicates the day.
  await db
    .insert(briefings)
    .values({
      forDate: dateKey,
      headline: data.headline,
      spokenText: data.spoken_text,
      items: data.items,
      runId,
    })
    .onConflictDoNothing();

  if (force) {
    await db
      .update(briefings)
      .set({
        headline: data.headline,
        spokenText: data.spoken_text,
        items: data.items,
        runId,
      })
      .where(eq(briefings.forDate, dateKey));
  }

  return {
    headline: data.headline,
    spokenText: data.spoken_text,
    items: data.items,
    cached: false,
    empty: false,
    runId,
  };
}
