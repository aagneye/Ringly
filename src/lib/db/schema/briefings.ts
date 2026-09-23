import { pgTable, text, timestamp, uuid, index, jsonb, date } from 'drizzle-orm/pg-core';

/**
 * A generated morning briefing, cached for the day.
 *
 * Ultra is the most expensive call in the product and the briefing does not
 * change between two page loads on the same morning, so it is computed once per
 * day and read from here afterwards. `items` holds the structured list the UI
 * renders; `spokenText` is the flattened version handed to speech synthesis.
 */
export const briefings = pgTable(
  'briefings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    /** Local calendar day this briefing covers. One row per day. */
    forDate: date('for_date').notNull(),
    headline: text('headline').notNull(),
    spokenText: text('spoken_text').notNull(),
    items: jsonb('items').notNull(),
    runId: uuid('run_id'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [index('briefings_for_date_idx').on(table.forDate)],
);

export type Briefing = typeof briefings.$inferSelect;
export type NewBriefing = typeof briefings.$inferInsert;
