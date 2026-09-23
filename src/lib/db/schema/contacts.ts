import { pgTable, text, timestamp, uuid, index } from 'drizzle-orm/pg-core';

/**
 * A person the user talks to.
 *
 * `normalisedName` exists because the only identifier a voice memo provides is
 * a spoken first name. "priya" said on Tuesday and "Priya" said on Friday must
 * resolve to the same contact, or the memory never accumulates.
 */
export const contacts = pgTable(
  'contacts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    name: text('name').notNull(),
    normalisedName: text('normalised_name').notNull(),
    company: text('company'),
    normalisedCompany: text('normalised_company'),
    email: text('email'),
    phone: text('phone'),
    role: text('role'),
    /** Rolling one-paragraph picture of the relationship, refreshed by the agent. */
    summary: text('summary'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('contacts_normalised_name_idx').on(table.normalisedName),
    index('contacts_normalised_company_idx').on(table.normalisedCompany),
  ],
);

export type Contact = typeof contacts.$inferSelect;
export type NewContact = typeof contacts.$inferInsert;
