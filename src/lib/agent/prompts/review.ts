/**
 * The nightly pipeline review.
 *
 * This is the "runs itself" half of the product. Nobody is talking to Ringly; a
 * clock wakes it, it reads the pipeline, and it acts.
 *
 * The prompt is markedly more restrictive than the memo planner, and deliberately
 * so. Unrequested action has a much higher bar than requested action: a wrong
 * reminder created from a memo the user just recorded is forgivable, whereas
 * three wrong emails waiting when they open the app in the morning destroys
 * trust in the whole product. Hence the hard cap and the instruction to prefer
 * doing nothing.
 */

export const REVIEW_SYSTEM_PROMPT = `You are Ringly, reviewing a salesperson's pipeline overnight. Nobody asked you to do this. They will see the results when they wake up.

Because this is unrequested, the bar for acting is high.

You will be given deals that have drifted, with the reason each was flagged, and the recent notes for each.

What you may do:
- draft_email, for a deal where a message would genuinely help. The user approves it before it sends.
- set_reminder, for something that has clearly been forgotten.

What you must not do:
- Act on more than three deals. Pick the three where your help is worth most.
- Draft an email for a deal where the notes give you nothing specific to say. A vague check-in email is worse than no email.
- Set a reminder that duplicates one already open.
- Touch deals marked won or lost.
- Change a deal's stage. You did not speak to the client; you do not know.

Prefer doing nothing over doing something marginal. A morning with one excellent draft beats a morning with four mediocre ones. If no deal genuinely warrants action, call no tools at all — that is a good outcome, not a failure.

For each action, your reasoning must state the specific fact from the notes that justifies it.`;

export interface ReviewDealContext {
  dealId: string;
  contactName: string;
  company: string | null;
  stage: string;
  signals: readonly string[];
  nextAction: string | null;
  deadlineLabel: string | null;
  lastContactLabel: string | null;
  openReminders: readonly string[];
  hasPendingDraft: boolean;
  recentNotes: readonly { text: string; whenLabel: string }[];
}

export function buildReviewPrompt(
  deals: readonly ReviewDealContext[],
  todayLabel: string,
): string {
  const lines: string[] = [];

  lines.push(`It is the night of ${todayLabel}.`);
  lines.push(`${deals.length} deals have drifted. Review them and act on at most three.`);

  for (const deal of deals) {
    lines.push('');
    lines.push(
      `--- ${deal.contactName}${deal.company ? ` at ${deal.company}` : ''} [deal ${deal.dealId}] ---`,
    );
    lines.push(`Stage: ${deal.stage}`);
    lines.push(`Why flagged: ${deal.signals.join(' ')}`);
    if (deal.lastContactLabel) lines.push(`Last spoke: ${deal.lastContactLabel}`);
    if (deal.nextAction) lines.push(`Next action on file: ${deal.nextAction}`);
    if (deal.deadlineLabel) lines.push(`Deadline: ${deal.deadlineLabel}`);

    if (deal.hasPendingDraft) {
      lines.push('A draft is ALREADY waiting for this deal. Do not write another.');
    }
    if (deal.openReminders.length > 0) {
      lines.push(`Reminders already open: ${deal.openReminders.join('; ')}`);
    }

    if (deal.recentNotes.length > 0) {
      lines.push('Recent notes:');
      for (const note of deal.recentNotes.slice(0, 2)) {
        lines.push(`  [${note.whenLabel}] ${note.text}`);
      }
    } else {
      lines.push('No notes recorded — you have nothing specific to reference.');
    }
  }

  lines.push('');
  lines.push(
    'Decide which deals, if any, deserve action tonight, and call the tools. Acting on none is acceptable.',
  );

  return lines.join('\n');
}

/**
 * Deals worth showing the reviewer at all.
 *
 * Filtering before the model call keeps an Ultra prompt from carrying twenty
 * healthy deals, and guarantees the cap is about judgement rather than context
 * length.
 */
export function selectReviewCandidates<T extends { dealId: string; hasPendingDraft: boolean }>(
  candidates: readonly T[],
  limit = 8,
): T[] {
  // A deal with a draft already waiting has had its help; showing it again just
  // invites a duplicate.
  return candidates.filter((candidate) => !candidate.hasPendingDraft).slice(0, limit);
}
