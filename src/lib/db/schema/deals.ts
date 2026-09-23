import { pgTable, text, timestamp, uuid, index, integer } from 'drizzle-orm/pg-core';
import { dealStageEnum, sentimentEnum } from './enums';
import { contacts } from './contacts';

/**
 * One opportunity with one contact.
 *
 * `lastContactAt` is separate from `updatedAt` on purpose: editing a note
 * touches the row but does not mean you spoke to the client. Drift detection
 * reads `lastContactAt`, and conflating the two would make every deal look
 * healthy forever.
 */
export const deals = pgTable(
  'deals',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    contactId: uuid('contact_id')
      .notNull()
      .references(() => contacts.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    stage: dealStageEnum('stage').notNull().default('new'),
    nextAction: text('next_action'),
    deadline: timestamp('deadline', { withTimezone: true }),
    budget: text('budget'),
    /** Free text, because a memo says "they're worried about onboarding time". */
    concerns: text('concerns'),
    sentiment: sentimentEnum('sentiment').default('neutral'),
    /** 0-100, written by the nightly review. Null until first reviewed. */
    healthScore: integer('health_score'),
    lastContactAt: timestamp('last_contact_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('deals_contact_id_idx').on(table.contactId),
    index('deals_stage_idx').on(table.stage),
    index('deals_last_contact_at_idx').on(table.lastContactAt),
  ],
);

export type Deal = typeof deals.$inferSelect;
export type NewDeal = typeof deals.$inferInsert;
