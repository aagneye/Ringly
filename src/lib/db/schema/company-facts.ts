import { pgTable, text, timestamp, uuid, index } from 'drizzle-orm/pg-core';
import { contacts } from './contacts';

/**
 * Facts pulled from the open web about a contact's company.
 *
 * Cached rather than fetched per view: search costs money and a funding round
 * does not change between two page loads. `sourceUrl` is mandatory because an
 * unattributed claim about a client is worse than no claim — the user needs to
 * see where it came from before repeating it on a call.
 */
export const companyFacts = pgTable(
  'company_facts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    contactId: uuid('contact_id')
      .notNull()
      .references(() => contacts.id, { onDelete: 'cascade' }),
    company: text('company').notNull(),
    fact: text('fact').notNull(),
    sourceUrl: text('source_url').notNull(),
    sourceTitle: text('source_title'),
    fetchedAt: timestamp('fetched_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('company_facts_contact_id_idx').on(table.contactId),
    index('company_facts_company_idx').on(table.company),
  ],
);

export type CompanyFact = typeof companyFacts.$inferSelect;
export type NewCompanyFact = typeof companyFacts.$inferInsert;
