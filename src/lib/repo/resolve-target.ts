import { eq, and, desc, inArray } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { contacts } from '@/lib/db/schema/contacts';
import { deals } from '@/lib/db/schema/deals';
import { CLOSED_STAGES, type DealStage } from '@/lib/db/schema/enums';
import { normaliseName, normaliseCompany, matchContact } from '@/lib/domain/contact-matching';

/**
 * Turning "spoke to Priya" into a concrete contact and deal.
 *
 * This runs before the planner, because every tool needs a `dealId` and asking
 * the model to resolve identity would make a wrong answer expensive. The rule is
 * conservative: create rather than guess. A duplicate contact is visible and
 * fixable in one tap, whereas two clients merged into one silently corrupts the
 * memory the whole product is built on.
 */

export interface ResolvedTarget {
  contactId: string;
  contactName: string;
  company: string | null;
  dealId: string;
  dealTitle: string;
  stage: DealStage;
  lastContactAt: Date | null;
  createdContact: boolean;
  createdDeal: boolean;
  matchConfidence: 'exact' | 'company' | 'fuzzy' | 'new';
}

/** Names already on file, for anchoring extraction spelling. */
export async function knownContactNames(limit = 40): Promise<string[]> {
  const rows = await getDb()
    .select({ name: contacts.name })
    .from(contacts)
    .orderBy(desc(contacts.updatedAt))
    .limit(limit);
  return rows.map((row) => row.name);
}

/**
 * Resolve, or create, the contact and open deal a memo refers to.
 *
 * `spokenName` of null means the memo never named anyone, which is a real case —
 * people record thinking-out-loud notes. Those are filed against a standing
 * "Unfiled" contact rather than rejected, so the transcript is never lost.
 */
export async function resolveTarget(
  spokenName: string | null,
  spokenCompany: string | null,
  now: Date,
): Promise<ResolvedTarget> {
  const db = getDb();
  const name = spokenName?.trim() || 'Unfiled note';

  const candidates = await db
    .select({
      id: contacts.id,
      normalisedName: contacts.normalisedName,
      normalisedCompany: contacts.normalisedCompany,
    })
    .from(contacts);

  const match = matchContact(name, spokenCompany, candidates);

  let contactId: string;
  let createdContact = false;
  let confidence: ResolvedTarget['matchConfidence'];

  if (match) {
    contactId = match.id;
    confidence = match.confidence;
    // Backfill a company learned in a later call.
    if (spokenCompany) {
      await db
        .update(contacts)
        .set({
          company: spokenCompany,
          normalisedCompany: normaliseCompany(spokenCompany),
          updatedAt: now,
        })
        .where(eq(contacts.id, contactId));
    }
  } else {
    const [row] = await db
      .insert(contacts)
      .values({
        name,
        normalisedName: normaliseName(name),
        company: spokenCompany,
        normalisedCompany: spokenCompany ? normaliseCompany(spokenCompany) : null,
      })
      .returning({ id: contacts.id });

    if (!row) throw new Error('Failed to create contact');
    contactId = row.id;
    createdContact = true;
    confidence = 'new';
  }

  const [contact] = await db
    .select({ name: contacts.name, company: contacts.company })
    .from(contacts)
    .where(eq(contacts.id, contactId))
    .limit(1);

  // Reuse the most recently touched open deal; a second open deal with the same
  // person is a deliberate act the user performs in the UI, not something a memo
  // should trigger.
  const [openDeal] = await db
    .select({
      id: deals.id,
      title: deals.title,
      stage: deals.stage,
      lastContactAt: deals.lastContactAt,
    })
    .from(deals)
    .where(
      and(
        eq(deals.contactId, contactId),
        inArray(
          deals.stage,
          (['new', 'contacted', 'proposal', 'negotiation'] as const).filter(
            (stage) => !CLOSED_STAGES.includes(stage),
          ),
        ),
      ),
    )
    .orderBy(desc(deals.updatedAt))
    .limit(1);

  if (openDeal) {
    return {
      contactId,
      contactName: contact?.name ?? name,
      company: contact?.company ?? spokenCompany,
      dealId: openDeal.id,
      dealTitle: openDeal.title,
      stage: openDeal.stage,
      lastContactAt: openDeal.lastContactAt,
      createdContact,
      createdDeal: false,
      matchConfidence: confidence,
    };
  }

  const title = defaultDealTitle(contact?.name ?? name, contact?.company ?? spokenCompany);
  const [newDeal] = await db
    .insert(deals)
    .values({ contactId, title, stage: 'new' })
    .returning({ id: deals.id, title: deals.title, stage: deals.stage });

  if (!newDeal) throw new Error('Failed to create deal');

  return {
    contactId,
    contactName: contact?.name ?? name,
    company: contact?.company ?? spokenCompany,
    dealId: newDeal.id,
    dealTitle: newDeal.title,
    stage: newDeal.stage,
    lastContactAt: null,
    createdContact,
    createdDeal: true,
    matchConfidence: confidence,
  };
}

/** "Northwind — Priya Sharma", or just the name when no company is known. */
export function defaultDealTitle(name: string, company: string | null): string {
  return company ? `${company} — ${name}` : name;
}
