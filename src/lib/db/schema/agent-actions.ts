import { pgTable, text, timestamp, uuid, index, jsonb } from 'drizzle-orm/pg-core';
import { deals } from './deals';
import { notes } from './notes';
import { actionSourceEnum, actionStatusEnum } from './enums';

/**
 * Every tool call the agent made, and what happened to it.
 *
 * This table is the honesty layer of the product. The screen that says "here is
 * what I just did for you" reads from here, not from a hopeful summary written
 * by the model — so the UI can never claim an action that did not actually
 * land. Failed calls are recorded too, which is what lets the app say "I tried
 * to schedule this but couldn't read the date" instead of silently dropping it.
 */
export const agentActions = pgTable(
  'agent_actions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    /** Groups the actions that came out of one agent run. */
    runId: uuid('run_id').notNull(),
    noteId: uuid('note_id').references(() => notes.id, { onDelete: 'set null' }),
    dealId: uuid('deal_id').references(() => deals.id, { onDelete: 'cascade' }),
    /** Tool name, e.g. 'set_reminder'. */
    tool: text('tool').notNull(),
    /** Validated arguments the tool was invoked with. */
    args: jsonb('args'),
    status: actionStatusEnum('status').notNull(),
    source: actionSourceEnum('source').notNull(),
    /** One sentence the UI shows: "Moved Priya to Proposal". */
    summary: text('summary').notNull(),
    /** Why the agent chose this, for the 2am drafts especially. */
    reasoning: text('reasoning'),
    /** Error detail when status is 'failed'. */
    error: text('error'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
  },
  (table) => [
    index('agent_actions_run_id_idx').on(table.runId),
    index('agent_actions_deal_id_idx').on(table.dealId),
    index('agent_actions_status_idx').on(table.status),
    index('agent_actions_created_at_idx').on(table.createdAt),
  ],
);

export type AgentAction = typeof agentActions.$inferSelect;
export type NewAgentAction = typeof agentActions.$inferInsert;
