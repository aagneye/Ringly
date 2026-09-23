import { pgTable, text, timestamp, uuid, index, boolean } from 'drizzle-orm/pg-core';
import { deals } from './deals';
import { actionSourceEnum } from './enums';

/**
 * A meeting on Ringly's own calendar.
 *
 * Deliberately not a Google Calendar mirror. Owning the calendar keeps the
 * agent loop complete without an OAuth dependency that can fail during a live
 * demo; `externalRef` and `exportedAt` leave room to push the event outward
 * later without reshaping the table.
 */
export const events = pgTable(
  'events',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    dealId: uuid('deal_id')
      .notNull()
      .references(() => deals.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    startsAt: timestamp('starts_at', { withTimezone: true }).notNull(),
    endsAt: timestamp('ends_at', { withTimezone: true }).notNull(),
    location: text('location'),
    notes: text('notes'),
    createdBy: actionSourceEnum('created_by').notNull().default('memo'),
    /** True once the user has seen this event, so new ones can be highlighted. */
    acknowledged: boolean('acknowledged').notNull().default(false),
    /** Identifier in an external calendar, if the event was ever exported. */
    externalRef: text('external_ref'),
    exportedAt: timestamp('exported_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('events_deal_id_idx').on(table.dealId),
    index('events_starts_at_idx').on(table.startsAt),
  ],
);

export type CalendarEvent = typeof events.$inferSelect;
export type NewCalendarEvent = typeof events.$inferInsert;
