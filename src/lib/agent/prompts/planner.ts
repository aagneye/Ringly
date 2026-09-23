import type { Extraction } from './extract';

/**
 * The prompt that turns a memo into decisions.
 *
 * This is where Ringly stops being a pipeline. The code does not say "always
 * update the deal and always write an email" — the model is handed a toolbox and
 * this text is the entire basis on which it chooses. Consequently the wording is
 * load-bearing and most of it exists to prevent specific observed failures:
 *
 *   - Calling every tool on every memo, to look thorough. Hence the explicit
 *     "doing nothing is a valid plan" and the bias statement.
 *   - Confusing a task with a meeting, scheduling "send the quote" as a 30
 *     minute calendar event. Hence the contrast rule.
 *   - Drafting an email when the user never implied they owed one.
 *   - Splitting one commitment into three near-identical reminders.
 */

export const PLANNER_SYSTEM_PROMPT = `You are Ringly, an assistant for a salesperson or freelancer. They have just recorded a voice memo about a client call. Your job is to decide which actions to take on their behalf, and then take them by calling tools.

How to decide:
- Act on what the memo actually says. Never act on what a call like this usually involves.
- Prefer fewer, correct actions over many plausible ones. Doing nothing is a valid plan if the memo contains no new information.
- A reminder is for a task the user must do. A calendar event is for a meeting with another person at a specific time. "Send the quote by Friday" is a reminder, not a meeting.
- One reminder per distinct commitment. Do not split a single promise into several.
- Only draft an email if the memo implies the user owes this person a message. If they said they would call rather than write, do not draft an email.
- Only look up a company when one is named and you have not already researched it.
- Always call update_deal when the memo contains any new fact about the deal, even a small one. Logging the conversation matters even when nothing changed.

Tone of your summaries: plain and factual. You are reporting what you did, not selling it.

You may call several tools in one turn. Call them all at once rather than one at a time.`;

export interface PlannerContext {
  extraction: Extraction;
  transcript: string;
  contactName: string;
  company: string | null;
  dealTitle: string;
  currentStage: string;
  /** Whether facts about this company are already cached. */
  hasCompanyFacts: boolean;
  /** Existing open reminders, so the planner does not duplicate them. */
  openReminders: readonly string[];
  /** Days since the last contact, for context on whether this is a re-engagement. */
  daysSinceLastContact: number | null;
  /** Local date string, so relative phrases can be reasoned about. */
  todayLabel: string;
}

/** Build the user turn for the planner. */
export function buildPlannerPrompt(context: PlannerContext): string {
  const lines: string[] = [];

  lines.push(`Today is ${context.todayLabel}.`);
  lines.push('');
  lines.push(`This memo is about ${context.contactName}${
    context.company ? ` at ${context.company}` : ''
  }, on the deal "${context.dealTitle}", currently at the ${context.currentStage} stage.`);

  if (context.daysSinceLastContact === null) {
    lines.push('This is the first recorded conversation with them.');
  } else if (context.daysSinceLastContact > 14) {
    lines.push(
      `It has been ${context.daysSinceLastContact} days since the last recorded conversation, so this is a re-engagement.`,
    );
  }

  if (context.openReminders.length > 0) {
    lines.push('');
    lines.push('Reminders already open for this deal — do not duplicate these:');
    for (const reminder of context.openReminders.slice(0, 8)) {
      lines.push(`- ${reminder}`);
    }
  }

  if (context.hasCompanyFacts) {
    lines.push('');
    lines.push('Company research is already on file, so lookup_company is unnecessary.');
  }

  lines.push('');
  lines.push('What was extracted from the memo:');
  lines.push(formatExtraction(context.extraction));

  lines.push('');
  lines.push('The memo itself, verbatim:');
  lines.push(context.transcript);

  lines.push('');
  lines.push('Decide what to do and call the appropriate tools.');

  return lines.join('\n');
}

function formatExtraction(extraction: Extraction): string {
  const entries: string[] = [];
  const push = (label: string, value: string | null) => {
    if (value) entries.push(`- ${label}: ${value}`);
  };

  push('Contact', extraction.contact_name);
  push('Company', extraction.company);
  push('Stage suggested by the call', extraction.stage_guess);
  push('What the user committed to', extraction.next_action);
  push('Timing mentioned', extraction.deadline);
  push('Budget mentioned', extraction.budget);
  push('Concerns raised', extraction.concerns);
  push('Sentiment', extraction.sentiment);

  if (entries.length === 0) {
    return '- Nothing concrete was extracted.';
  }
  return entries.join('\n');
}
