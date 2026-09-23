import { relations } from 'drizzle-orm';
import { contacts } from './contacts';
import { deals } from './deals';
import { notes } from './notes';
import { drafts } from './drafts';
import { reminders } from './reminders';
import { events } from './events';
import { agentActions } from './agent-actions';
import { companyFacts } from './company-facts';

/**
 * Relations exist so the pre-call brief can load a contact, their deal, the
 * last few transcripts and any pending drafts in one round trip. On a
 * serverless Postgres connection the round trips, not the query cost, are what
 * make a page feel slow.
 */

export const contactsRelations = relations(contacts, ({ many }) => ({
  deals: many(deals),
  notes: many(notes),
  companyFacts: many(companyFacts),
}));

export const dealsRelations = relations(deals, ({ one, many }) => ({
  contact: one(contacts, {
    fields: [deals.contactId],
    references: [contacts.id],
  }),
  notes: many(notes),
  drafts: many(drafts),
  reminders: many(reminders),
  events: many(events),
  actions: many(agentActions),
}));

export const notesRelations = relations(notes, ({ one }) => ({
  deal: one(deals, { fields: [notes.dealId], references: [deals.id] }),
  contact: one(contacts, { fields: [notes.contactId], references: [contacts.id] }),
}));

export const draftsRelations = relations(drafts, ({ one }) => ({
  deal: one(deals, { fields: [drafts.dealId], references: [deals.id] }),
}));

export const remindersRelations = relations(reminders, ({ one }) => ({
  deal: one(deals, { fields: [reminders.dealId], references: [deals.id] }),
}));

export const eventsRelations = relations(events, ({ one }) => ({
  deal: one(deals, { fields: [events.dealId], references: [deals.id] }),
}));

export const agentActionsRelations = relations(agentActions, ({ one }) => ({
  deal: one(deals, { fields: [agentActions.dealId], references: [deals.id] }),
  note: one(notes, { fields: [agentActions.noteId], references: [notes.id] }),
}));

export const companyFactsRelations = relations(companyFacts, ({ one }) => ({
  contact: one(contacts, { fields: [companyFacts.contactId], references: [contacts.id] }),
}));
