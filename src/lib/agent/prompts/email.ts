/**
 * Prompts for writing a follow-up email.
 *
 * Kept as pure string builders in their own module so the wording can be tested
 * and iterated without a network call. Prompt text is the actual product surface
 * here — the difference between an email a salesperson sends unedited and one
 * they rewrite is entirely in these instructions.
 */

export interface EmailContext {
  userName: string;
  contactName: string;
  company: string | null;
  stage: string;
  nextAction: string | null;
  deadlineText: string | null;
  concerns: string | null;
  budget: string | null;
  /** Most recent transcripts, newest first. Gives the model the real language. */
  recentTranscripts: readonly string[];
  /** Sourced facts about their company, if any were fetched. */
  companyFacts: readonly string[];
  /** Why this email is being written now, for unprompted nightly drafts. */
  occasion: 'after_call' | 'gone_quiet' | 'deadline_approaching';
}

export const EMAIL_SYSTEM_PROMPT = `You write follow-up emails on behalf of a salesperson or freelancer, in their voice.

Hard rules:
- Under 120 words. Shorter is better.
- No corporate filler. Never write "I hope this email finds you well", "circling back", "touching base", "as per our conversation", "reaching out", or "synergy".
- Never invent a fact, a price, a date or a commitment that is not in the context you were given.
- Never over-promise. If the context does not say something was agreed, do not imply it was.
- Reference something specific the client actually said. This is what separates a real email from a template.
- Plain sentences. No bullet points unless you are listing more than two concrete deliverables.
- One clear ask at the end, phrased as a question.
- Sign off with the sender's first name only.

Write as if you are a competent person who respects the reader's time, not a marketing department.`;

/** Build the user-side prompt with everything known about the relationship. */
export function buildEmailPrompt(context: EmailContext): string {
  const lines: string[] = [];

  lines.push(`Sender: ${context.userName}`);
  lines.push(`Recipient: ${context.contactName}${context.company ? ` at ${context.company}` : ''}`);
  lines.push(`Deal stage: ${context.stage}`);
  lines.push(`Reason for writing: ${describeOccasion(context.occasion)}`);

  if (context.nextAction) {
    lines.push(`What the sender committed to: ${context.nextAction}`);
  }
  if (context.deadlineText) {
    lines.push(`Relevant deadline: ${context.deadlineText}`);
  }
  if (context.concerns) {
    lines.push(`Concerns the client raised: ${context.concerns}`);
  }
  if (context.budget) {
    lines.push(`Budget discussed: ${context.budget}`);
  }

  if (context.companyFacts.length > 0) {
    lines.push('');
    lines.push('Recent public news about their company (only mention if genuinely relevant):');
    for (const fact of context.companyFacts.slice(0, 3)) {
      lines.push(`- ${fact}`);
    }
  }

  if (context.recentTranscripts.length > 0) {
    lines.push('');
    lines.push('What was actually said on recent calls, most recent first:');
    context.recentTranscripts.slice(0, 3).forEach((transcript, index) => {
      lines.push(`[Call ${index + 1}] ${truncate(transcript, 900)}`);
    });
  }

  lines.push('');
  lines.push('Return JSON with exactly two fields: "subject" and "body".');

  return lines.join('\n');
}

function describeOccasion(occasion: EmailContext['occasion']): string {
  switch (occasion) {
    case 'after_call':
      return 'The sender just finished a call with this person and is following up.';
    case 'gone_quiet':
      return 'This deal has gone quiet. The email should re-open the conversation without sounding needy or accusatory. Do not apologise for following up.';
    case 'deadline_approaching':
      return 'A deadline is close. The email should make the timing clear without applying pressure.';
  }
}

function truncate(text: string, limit: number): string {
  if (text.length <= limit) return text;
  return `${text.slice(0, limit)}…`;
}

/** Wire schema for the drafted email. */
export const EMAIL_WIRE_SCHEMA = {
  name: 'drafted_email',
  schema: {
    type: 'object',
    properties: {
      subject: { type: 'string', description: 'Subject line, under 60 characters.' },
      body: { type: 'string', description: 'Email body, under 120 words, plain text.' },
    },
    required: ['subject', 'body'],
    additionalProperties: false,
  },
} as const;
