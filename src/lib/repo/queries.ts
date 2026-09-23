import { eq, and, desc, asc, gte, lte, inArray, sql } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { contacts } from '@/lib/db/schema/contacts';
import { deals } from '@/lib/db/schema/deals';
import { notes } from '@/lib/db/schema/notes';
import { drafts } from '@/lib/db/schema/drafts';
import { reminders } from '@/lib/db/schema/reminders';
import { events } from '@/lib/db/schema/events';
import { agentActions } from '@/lib/db/schema/agent-actions';
import { companyFacts } from '@/lib/db/schema/company-facts';
import { DEAL_STAGES, type DealStage } from '@/lib/db/schema/enums';
import { detectDrift, healthScore, type DriftInput, type DriftSignal } from '@/lib/domain/drift';

/** A deal as the kanban board needs it. */
export interface BoardDeal {
  id: string;
  title: string;
  stage: DealStage;
  contactId: string;
  contactName: string;
  company: string | null;
  nextAction: string | null;
  deadline: Date | null;
  budget: string | null;
  sentiment: string | null;
  lastContactAt: Date | null;
  createdAt: Date;
  health: number;
  signals: DriftSignal[];
  noteCount: number;
  pendingDraftCount: number;
}

export interface Board {
  columns: { stage: DealStage; deals: BoardDeal[] }[];
  total: number;
}

/**
 * Everything the board needs, in three queries rather than one per card.
 *
 * Counts are aggregated separately and joined in memory. A correlated subquery
 * per deal would be tidier to write, but on a serverless HTTP connection the
 * round trips dominate and the board is the first thing a judge sees.
 */
export async function loadBoard(now: Date): Promise<Board> {
  const db = getDb();

  const rows = await db
    .select({
      id: deals.id,
      title: deals.title,
      stage: deals.stage,
      nextAction: deals.nextAction,
      deadline: deals.deadline,
      budget: deals.budget,
      sentiment: deals.sentiment,
      lastContactAt: deals.lastContactAt,
      createdAt: deals.createdAt,
      contactId: contacts.id,
      contactName: contacts.name,
      company: contacts.company,
    })
    .from(deals)
    .innerJoin(contacts, eq(deals.contactId, contacts.id))
    .orderBy(desc(deals.updatedAt));

  const dealIds = rows.map((row) => row.id);

  const [noteCounts, draftCounts] = await Promise.all([
    dealIds.length > 0
      ? db
          .select({ dealId: notes.dealId, count: sql<number>`count(*)::int` })
          .from(notes)
          .where(inArray(notes.dealId, dealIds))
          .groupBy(notes.dealId)
      : Promise.resolve([]),
    dealIds.length > 0
      ? db
          .select({ dealId: drafts.dealId, count: sql<number>`count(*)::int` })
          .from(drafts)
          .where(and(inArray(drafts.dealId, dealIds), eq(drafts.status, 'draft')))
          .groupBy(drafts.dealId)
      : Promise.resolve([]),
  ]);

  const noteCountByDeal = new Map(noteCounts.map((row) => [row.dealId, row.count]));
  const draftCountByDeal = new Map(draftCounts.map((row) => [row.dealId, row.count]));

  const enriched: BoardDeal[] = rows.map((row) => {
    const driftInput: DriftInput = {
      id: row.id,
      title: row.title,
      stage: row.stage,
      lastContactAt: row.lastContactAt,
      deadline: row.deadline,
      nextAction: row.nextAction,
      createdAt: row.createdAt,
    };
    return {
      ...row,
      health: healthScore(driftInput, now),
      signals: detectDrift(driftInput, now),
      noteCount: noteCountByDeal.get(row.id) ?? 0,
      pendingDraftCount: draftCountByDeal.get(row.id) ?? 0,
    };
  });

  return {
    columns: DEAL_STAGES.map((stage) => ({
      stage,
      deals: enriched.filter((deal) => deal.stage === stage),
    })),
    total: enriched.length,
  };
}

/** Open deals shaped for drift analysis, without the display joins. */
export async function loadOpenDealsForDrift(): Promise<DriftInput[]> {
  const rows = await getDb()
    .select({
      id: deals.id,
      title: deals.title,
      stage: deals.stage,
      lastContactAt: deals.lastContactAt,
      deadline: deals.deadline,
      nextAction: deals.nextAction,
      createdAt: deals.createdAt,
    })
    .from(deals)
    .where(inArray(deals.stage, ['new', 'contacted', 'proposal', 'negotiation']));

  return rows;
}

/** Full picture of one deal, for the detail view and the pre-call brief. */
export async function loadDealDetail(dealId: string, now: Date) {
  const db = getDb();

  const [deal] = await db
    .select({
      id: deals.id,
      title: deals.title,
      stage: deals.stage,
      nextAction: deals.nextAction,
      deadline: deals.deadline,
      budget: deals.budget,
      concerns: deals.concerns,
      sentiment: deals.sentiment,
      lastContactAt: deals.lastContactAt,
      createdAt: deals.createdAt,
      contactId: contacts.id,
      contactName: contacts.name,
      company: contacts.company,
      email: contacts.email,
      role: contacts.role,
      summary: contacts.summary,
    })
    .from(deals)
    .innerJoin(contacts, eq(deals.contactId, contacts.id))
    .where(eq(deals.id, dealId))
    .limit(1);

  if (!deal) return null;

  const [noteRows, draftRows, reminderRows, eventRows, actionRows, factRows] = await Promise.all([
    db
      .select({
        id: notes.id,
        rawTranscript: notes.rawTranscript,
        gist: notes.gist,
        createdAt: notes.createdAt,
        durationSeconds: notes.durationSeconds,
        source: notes.source,
      })
      .from(notes)
      .where(eq(notes.dealId, dealId))
      .orderBy(desc(notes.createdAt))
      .limit(20),
    db
      .select()
      .from(drafts)
      .where(eq(drafts.dealId, dealId))
      .orderBy(desc(drafts.createdAt))
      .limit(10),
    db
      .select()
      .from(reminders)
      .where(eq(reminders.dealId, dealId))
      .orderBy(asc(reminders.dueAt))
      .limit(20),
    db
      .select()
      .from(events)
      .where(eq(events.dealId, dealId))
      .orderBy(asc(events.startsAt))
      .limit(20),
    db
      .select()
      .from(agentActions)
      .where(eq(agentActions.dealId, dealId))
      .orderBy(desc(agentActions.createdAt))
      .limit(30),
    db.select().from(companyFacts).where(eq(companyFacts.contactId, deal.contactId)).limit(5),
  ]);

  const driftInput: DriftInput = {
    id: deal.id,
    title: deal.title,
    stage: deal.stage,
    lastContactAt: deal.lastContactAt,
    deadline: deal.deadline,
    nextAction: deal.nextAction,
    createdAt: deal.createdAt,
  };

  return {
    deal,
    health: healthScore(driftInput, now),
    signals: detectDrift(driftInput, now),
    notes: noteRows,
    drafts: draftRows,
    reminders: reminderRows,
    events: eventRows,
    actions: actionRows,
    facts: factRows,
  };
}

/** Reminders due on or before the end of today, plus anything overdue. */
export async function loadDueReminders(now: Date) {
  const endOfDay = new Date(now);
  endOfDay.setHours(23, 59, 59, 999);

  return getDb()
    .select({
      id: reminders.id,
      message: reminders.message,
      dueAt: reminders.dueAt,
      createdBy: reminders.createdBy,
      dealId: reminders.dealId,
      dealTitle: deals.title,
      contactName: contacts.name,
    })
    .from(reminders)
    .innerJoin(deals, eq(reminders.dealId, deals.id))
    .innerJoin(contacts, eq(deals.contactId, contacts.id))
    .where(and(eq(reminders.status, 'pending'), lte(reminders.dueAt, endOfDay)))
    .orderBy(asc(reminders.dueAt));
}

/** Meetings starting between now and the end of today. */
export async function loadTodaysEvents(now: Date) {
  const endOfDay = new Date(now);
  endOfDay.setHours(23, 59, 59, 999);
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);

  return getDb()
    .select({
      id: events.id,
      title: events.title,
      startsAt: events.startsAt,
      endsAt: events.endsAt,
      location: events.location,
      dealId: events.dealId,
      contactName: contacts.name,
      company: contacts.company,
    })
    .from(events)
    .innerJoin(deals, eq(events.dealId, deals.id))
    .innerJoin(contacts, eq(deals.contactId, contacts.id))
    .where(and(gte(events.startsAt, startOfDay), lte(events.startsAt, endOfDay)))
    .orderBy(asc(events.startsAt));
}

/** Drafts still waiting for a human tap. */
export async function loadPendingDrafts() {
  return getDb()
    .select({
      id: drafts.id,
      subject: drafts.subject,
      body: drafts.body,
      reasoning: drafts.reasoning,
      createdAt: drafts.createdAt,
      dealId: drafts.dealId,
      dealTitle: deals.title,
      contactName: contacts.name,
      contactEmail: contacts.email,
    })
    .from(drafts)
    .innerJoin(deals, eq(drafts.dealId, deals.id))
    .innerJoin(contacts, eq(deals.contactId, contacts.id))
    .where(eq(drafts.status, 'draft'))
    .orderBy(desc(drafts.createdAt));
}

/** Recent transcripts for a contact, newest first. */
export async function loadRecentTranscripts(contactId: string, limit = 5) {
  return getDb()
    .select({
      rawTranscript: notes.rawTranscript,
      gist: notes.gist,
      createdAt: notes.createdAt,
    })
    .from(notes)
    .where(eq(notes.contactId, contactId))
    .orderBy(desc(notes.createdAt))
    .limit(limit);
}

/** Open reminder messages for a deal, so the planner does not duplicate them. */
export async function loadOpenReminderMessages(dealId: string): Promise<string[]> {
  const rows = await getDb()
    .select({ message: reminders.message })
    .from(reminders)
    .where(and(eq(reminders.dealId, dealId), eq(reminders.status, 'pending')))
    .limit(8);
  return rows.map((row) => row.message);
}

/** Whether company research is already cached for a contact. */
export async function hasCompanyFacts(contactId: string): Promise<boolean> {
  const rows = await getDb()
    .select({ id: companyFacts.id })
    .from(companyFacts)
    .where(eq(companyFacts.contactId, contactId))
    .limit(1);
  return rows.length > 0;
}
