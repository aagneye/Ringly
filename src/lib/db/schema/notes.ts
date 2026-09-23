import { pgTable, text, timestamp, uuid, index, jsonb, integer } from 'drizzle-orm/pg-core';
import { deals } from './deals';
import { contacts } from './contacts';

/**
 * The raw material of the product: what was actually said, verbatim.
 *
 * Structured fields on `deals` are a lossy projection of this. The pre-call
 * brief and the "what did she say about budget?" question both answer from
 * `rawTranscript`, not from the projection — which is why transcripts are kept
 * forever rather than discarded after extraction.
 *
 * `contactId` is denormalised from the deal so a memo can be filed against a
 * person before it is clear which deal it belongs to.
 */
export const notes = pgTable(
  'notes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    dealId: uuid('deal_id').references(() => deals.id, { onDelete: 'cascade' }),
    contactId: uuid('contact_id').references(() => contacts.id, { onDelete: 'cascade' }),
    rawTranscript: text('raw_transcript').notNull(),
    /** One-line gist, used to build history context cheaply. */
    gist: text('gist'),
    /** Full extraction output, kept for debugging and for the demo trace. */
    structured: jsonb('structured'),
    /** Recording length in seconds. Null when the note was typed. */
    durationSeconds: integer('duration_seconds'),
    /** 'voice' or 'text' — the demo shows both paths. */
    source: text('source').notNull().default('voice'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index('notes_deal_id_idx').on(table.dealId),
    index('notes_contact_id_idx').on(table.contactId),
    index('notes_created_at_idx').on(table.createdAt),
  ],
);

export type Note = typeof notes.$inferSelect;
export type NewNote = typeof notes.$inferInsert;
