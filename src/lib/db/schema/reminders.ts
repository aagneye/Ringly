import { pgTable, text, timestamp, uuid, index } from 'drizzle-orm/pg-core';
import { deals } from './deals';
import { reminderStatusEnum, actionSourceEnum } from './enums';

/**
 * A nudge with a due time.
 *
 * Reminders are reversible, so the agent creates them without asking. Recording
 * `createdBy` lets the UI distinguish "you asked for this" from "Ringly noticed
 * this", which is the difference between the app feeling attentive and feeling
 * noisy.
 */
export const reminders = pgTable(
  'reminders',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    dealId: uuid('deal_id')
      .notNull()
      .references(() => deals.id, { onDelete: 'cascade' }),
    message: text('message').notNull(),
    dueAt: timestamp('due_at', { withTimezone: true }).notNull(),
    status: reminderStatusEnum('status').notNull().default('pending'),
    createdBy: actionSourceEnum('created_by').notNull().default('memo'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    completedAt: timestamp('completed_at', { withTimezone: true }),
  },
  (table) => [
    index('reminders_deal_id_idx').on(table.dealId),
    index('reminders_due_at_idx').on(table.dueAt),
    index('reminders_status_idx').on(table.status),
  ],
);

export type Reminder = typeof reminders.$inferSelect;
export type NewReminder = typeof reminders.$inferInsert;
