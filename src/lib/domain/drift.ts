import { CLOSED_STAGES, type DealStage } from '@/lib/db/schema/enums';

/**
 * Deciding which deals are quietly dying.
 *
 * This runs before any model call, and that ordering is the point. Asking Ultra
 * to read twelve deals and guess which are stale would be slower, costlier and
 * less reliable than arithmetic on two timestamps. The model's job is to decide
 * what to *say* about a drifting deal; deciding *which* deals drift is
 * deterministic, explainable and free.
 *
 * Everything here is pure so the nightly review can be tested without a clock,
 * a database or a network.
 */

/** How long a deal may sit untouched in each stage before it counts as drifting. */
export const STAGE_SILENCE_TOLERANCE_DAYS: Record<DealStage, number> = {
  // A brand new lead going cold for a week is the most common failure mode.
  new: 3,
  contacted: 7,
  // Proposals out for review deserve the tightest leash: this is where revenue
  // is lost to silence rather than to rejection.
  proposal: 5,
  negotiation: 4,
  won: Number.POSITIVE_INFINITY,
  lost: Number.POSITIVE_INFINITY,
};

export type DriftReason =
  | 'deadline_passed'
  | 'deadline_imminent'
  | 'gone_quiet'
  | 'never_contacted'
  | 'stalled_commitment';

export interface DriftInput {
  id: string;
  title: string;
  stage: DealStage;
  lastContactAt: Date | null;
  deadline: Date | null;
  nextAction: string | null;
  createdAt: Date;
}

export interface DriftSignal {
  dealId: string;
  reason: DriftReason;
  /** 0-100. Higher means more urgent. Drives ordering in the briefing. */
  urgency: number;
  /** Plain sentence the UI and the model prompt both reuse. */
  explanation: string;
  daysSinceContact: number | null;
  daysUntilDeadline: number | null;
}

const MS_PER_DAY = 86_400_000;

/** Whole days between two instants, rounded down, negative when b precedes a. */
export function daysBetween(from: Date, to: Date): number {
  return Math.floor((to.getTime() - from.getTime()) / MS_PER_DAY);
}

/**
 * Evaluate one deal. Returns every signal that applies, strongest first —
 * a deal can be both past its deadline and silent for a fortnight, and the
 * briefing should be able to say so.
 */
export function detectDrift(deal: DriftInput, now: Date): DriftSignal[] {
  if (CLOSED_STAGES.includes(deal.stage)) return [];

  const signals: DriftSignal[] = [];

  const daysSinceContact = deal.lastContactAt ? daysBetween(deal.lastContactAt, now) : null;
  const daysUntilDeadline = deal.deadline ? daysBetween(now, deal.deadline) : null;

  if (daysUntilDeadline !== null) {
    if (daysUntilDeadline < 0) {
      const overdue = Math.abs(daysUntilDeadline);
      signals.push({
        dealId: deal.id,
        reason: 'deadline_passed',
        urgency: Math.min(100, 85 + overdue * 3),
        explanation: `The deadline on ${deal.title} passed ${dayPhrase(overdue)} ago${
          deal.nextAction ? ` and "${deal.nextAction}" is still open` : ''
        }.`,
        daysSinceContact,
        daysUntilDeadline,
      });
    } else if (daysUntilDeadline <= 2) {
      signals.push({
        dealId: deal.id,
        reason: 'deadline_imminent',
        urgency: daysUntilDeadline === 0 ? 90 : 80 - daysUntilDeadline * 5,
        explanation: `${deal.title} is due ${
          daysUntilDeadline === 0 ? 'today' : `in ${dayPhrase(daysUntilDeadline)}`
        }.`,
        daysSinceContact,
        daysUntilDeadline,
      });
    }
  }

  if (daysSinceContact === null) {
    const daysOpen = daysBetween(deal.createdAt, now);
    if (daysOpen >= 2) {
      signals.push({
        dealId: deal.id,
        reason: 'never_contacted',
        urgency: Math.min(75, 45 + daysOpen * 3),
        explanation: `${deal.title} has been open ${dayPhrase(daysOpen)} and you have not spoken to them yet.`,
        daysSinceContact,
        daysUntilDeadline,
      });
    }
  } else {
    const tolerance = STAGE_SILENCE_TOLERANCE_DAYS[deal.stage];
    if (daysSinceContact > tolerance) {
      const overrun = daysSinceContact - tolerance;
      signals.push({
        dealId: deal.id,
        reason: 'gone_quiet',
        urgency: Math.min(80, 40 + overrun * 5),
        explanation: `${deal.title} has gone quiet for ${dayPhrase(daysSinceContact)} — longer than ${dayPhrase(
          tolerance,
        )} is unusual at the ${deal.stage} stage.`,
        daysSinceContact,
        daysUntilDeadline,
      });
    }
  }

  // A promise with no date attached is the easiest thing in sales to forget.
  if (deal.nextAction && daysSinceContact !== null && daysSinceContact >= 3 && !deal.deadline) {
    signals.push({
      dealId: deal.id,
      reason: 'stalled_commitment',
      urgency: Math.min(70, 35 + daysSinceContact * 3),
      explanation: `You said you would "${deal.nextAction}" for ${deal.title} ${dayPhrase(
        daysSinceContact,
      )} ago and it has no date on it.`,
      daysSinceContact,
      daysUntilDeadline,
    });
  }

  return signals.sort((a, b) => b.urgency - a.urgency);
}

/** Evaluate a whole pipeline, most urgent signal first. */
export function detectPipelineDrift(deals: readonly DriftInput[], now: Date): DriftSignal[] {
  return deals.flatMap((deal) => detectDrift(deal, now)).sort((a, b) => b.urgency - a.urgency);
}

/**
 * Deal health, 0-100, derived from its worst signal.
 *
 * A single number so the kanban card can show a colour without the user reading
 * a paragraph.
 */
export function healthScore(deal: DriftInput, now: Date): number {
  if (deal.stage === 'won') return 100;
  if (deal.stage === 'lost') return 0;

  const signals = detectDrift(deal, now);
  if (signals.length === 0) return 92;

  const worst = signals[0];
  if (!worst) return 92;

  // Additional signals compound, but with diminishing effect — two problems is
  // worse than one, five is not five times worse than one.
  const compounding = Math.min(12, (signals.length - 1) * 4);
  return Math.max(5, 100 - worst.urgency - compounding);
}

function dayPhrase(days: number): string {
  if (!Number.isFinite(days)) return 'an indefinite period';
  if (days === 0) return 'today';
  if (days === 1) return '1 day';
  return `${days} days`;
}
