import 'dotenv/config';
import { getDb } from '@/lib/db';
import { contacts } from '@/lib/db/schema/contacts';
import { deals } from '@/lib/db/schema/deals';
import { notes } from '@/lib/db/schema/notes';
import { reminders } from '@/lib/db/schema/reminders';
import { normaliseName, normaliseCompany } from '@/lib/domain/contact-matching';

/**
 * Seed one believable deal so the app is never blank for a judge on first load.
 *
 * Deliberately a single deal rather than a dozen. A crowded demo pipeline
 * distracts from the one flow that matters — record a memo, watch the agent act
 * — and a judge's first ninety seconds are better spent there than scrolling a
 * kanban board of placeholder names.
 */
async function seed() {
  const db = getDb();
  const now = new Date();
  const nineDaysAgo = new Date(now.getTime() - 9 * 86_400_000);

  const [contact] = await db
    .insert(contacts)
    .values({
      name: 'Priya Sharma',
      normalisedName: normaliseName('Priya Sharma'),
      company: 'Northwind Logistics',
      normalisedCompany: normaliseCompany('Northwind Logistics'),
      email: 'priya@northwind.example',
      role: 'Head of Operations',
    })
    .returning({ id: contacts.id });

  if (!contact) throw new Error('Failed to seed contact');

  const [deal] = await db
    .insert(deals)
    .values({
      contactId: contact.id,
      title: 'Northwind Logistics — Priya Sharma',
      stage: 'proposal',
      nextAction: 'Send the revised pricing sheet',
      budget: 'around 12 lakh per year',
      concerns: 'worried about how long onboarding takes for her ops team',
      sentiment: 'positive',
      lastContactAt: nineDaysAgo,
    })
    .returning({ id: deals.id });

  if (!deal) throw new Error('Failed to seed deal');

  await db.insert(notes).values({
    dealId: deal.id,
    contactId: contact.id,
    rawTranscript:
      "just got off the phone with priya at northwind she's keen but wants to see the " +
      "revised pricing before her board meeting she mentioned she's still a bit worried " +
      'about how long onboarding takes for her ops team, they have about forty people ' +
      "who'd need to move over. said budget is around twelve lakh a year which is roughly " +
      "what we quoted. asked me to send the pricing sheet, said she'd get back to me by " +
      'friday',
    gist: 'Priya wants revised pricing before her board meeting; concerned about onboarding time for her team of 40.',
    source: 'voice',
    durationSeconds: 52,
  });

  await db.insert(reminders).values({
    dealId: deal.id,
    message: 'Send Priya the revised pricing sheet',
    dueAt: new Date(now.getTime() + 86_400_000),
    createdBy: 'memo',
  });

  console.log(`Seeded contact ${contact.id} and deal ${deal.id}.`);
  console.log('Nine days of silence since the last contact — the pipeline page will show drift.');
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exit(1);
  });
