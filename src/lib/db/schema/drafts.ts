import { pgTable, text, timestamp, uuid, index } from 'drizzle-orm/pg-core';
import { deals } from './deals';
import { draftStatusEnum } from './enums';

/**
 * An email the agent wrote and the user has not yet sent.
 *
 * Sending is the one irreversible action in the product, so a draft is never
 * dispatched by the agent — it sits here until the user approves it. The
 * `reasoning` column holds the agent's one-line justification, which is what
 * makes an unrequested 2am draft feel helpful instead of presumptuous.
 */
export const drafts = pgTable(
  'drafts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    dealId: uuid('deal_id')
      .notNull()
      .references(() => deals.id, { onDelete: 'cascade' }),
    subject: text('subject').notNull(),
    body: text('body').notNull(),
    status: draftStatusEnum('status').notNull().default('draft'),
    /** Why the agent thought this email was worth writing. */
    reasoning: text('reasoning'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('drafts_deal_id_idx').on(table.dealId),
    index('drafts_status_idx').on(table.status),
  ],
);

export type Draft = typeof drafts.$inferSelect;
export type NewDraft = typeof drafts.$inferInsert;
