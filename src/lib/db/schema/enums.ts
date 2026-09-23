import { pgEnum } from 'drizzle-orm/pg-core';

/**
 * Pipeline stages, in the order a deal moves through them. The order matters:
 * drift detection and the kanban column layout both read it.
 */
export const dealStageEnum = pgEnum('deal_stage', [
  'new',
  'contacted',
  'proposal',
  'negotiation',
  'won',
  'lost',
]);

export const DEAL_STAGES = dealStageEnum.enumValues;
export type DealStage = (typeof DEAL_STAGES)[number];

/** Stages where no further follow-up is expected. */
export const CLOSED_STAGES: readonly DealStage[] = ['won', 'lost'];

export const sentimentEnum = pgEnum('sentiment', ['positive', 'neutral', 'negative']);
export type Sentiment = (typeof sentimentEnum.enumValues)[number];

export const draftStatusEnum = pgEnum('draft_status', [
  'draft',
  'approved',
  'sent',
  'discarded',
]);
export type DraftStatus = (typeof draftStatusEnum.enumValues)[number];

export const reminderStatusEnum = pgEnum('reminder_status', ['pending', 'done', 'dismissed']);
export type ReminderStatus = (typeof reminderStatusEnum.enumValues)[number];

/**
 * Where an agent action came from. Distinguishing these is what lets the UI
 * say "Ringly did this while you slept" versus "Ringly did this from your memo".
 */
export const actionSourceEnum = pgEnum('action_source', [
  'memo',
  'nightly_review',
  'manual',
  'question',
]);
export type ActionSource = (typeof actionSourceEnum.enumValues)[number];

/**
 * Reversible actions are applied immediately; irreversible ones wait for a tap.
 * This is the trust model of the product, encoded in the data.
 */
export const actionStatusEnum = pgEnum('action_status', [
  'applied',
  'awaiting_approval',
  'approved',
  'rejected',
  'failed',
]);
export type ActionStatus = (typeof actionStatusEnum.enumValues)[number];
