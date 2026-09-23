import { describe, it, expect } from 'vitest';
import {
  REVIEW_SYSTEM_PROMPT,
  buildReviewPrompt,
  selectReviewCandidates,
  type ReviewDealContext,
} from '@/lib/agent/prompts/review';
import { inferDealId } from '@/lib/agent/review';

function reviewDeal(overrides: Partial<ReviewDealContext> = {}): ReviewDealContext {
  return {
    dealId: 'deal-1',
    contactName: 'Priya Sharma',
    company: 'Northwind',
    stage: 'proposal',
    signals: ['Northwind pilot has gone quiet for 12 days.'],
    nextAction: 'send the pricing sheet',
    deadlineLabel: null,
    lastContactLabel: '12 days ago',
    openReminders: [],
    hasPendingDraft: false,
    recentNotes: [{ text: 'she was worried about onboarding time', whenLabel: '12 days ago' }],
    ...overrides,
  };
}

describe('REVIEW_SYSTEM_PROMPT', () => {
  it('sets a hard cap of three deals', () => {
    expect(REVIEW_SYSTEM_PROMPT).toContain('more than three deals');
  });

  it('prefers inaction over marginal action', () => {
    expect(REVIEW_SYSTEM_PROMPT).toContain('Prefer doing nothing over doing something marginal');
  });

  it('treats calling no tools as a success', () => {
    expect(REVIEW_SYSTEM_PROMPT).toContain('that is a good outcome, not a failure');
  });

  it('forbids changing a deal stage overnight', () => {
    expect(REVIEW_SYSTEM_PROMPT).toContain("Change a deal's stage");
  });

  it('forbids vague check-in emails', () => {
    expect(REVIEW_SYSTEM_PROMPT).toContain('vague check-in email is worse than no email');
  });

  it('requires reasoning grounded in a specific note', () => {
    expect(REVIEW_SYSTEM_PROMPT).toContain('specific fact from the notes');
  });
});

describe('selectReviewCandidates', () => {
  it('drops deals that already have a draft waiting', () => {
    const result = selectReviewCandidates([
      reviewDeal({ dealId: 'a', hasPendingDraft: false }),
      reviewDeal({ dealId: 'b', hasPendingDraft: true }),
    ]);
    expect(result.map((deal) => deal.dealId)).toEqual(['a']);
  });

  it('caps the candidate list', () => {
    const many = Array.from({ length: 20 }, (_, i) =>
      reviewDeal({ dealId: `deal-${i}`, hasPendingDraft: false }),
    );
    expect(selectReviewCandidates(many)).toHaveLength(8);
  });

  it('respects a custom limit', () => {
    const many = Array.from({ length: 20 }, (_, i) =>
      reviewDeal({ dealId: `deal-${i}`, hasPendingDraft: false }),
    );
    expect(selectReviewCandidates(many, 3)).toHaveLength(3);
  });

  it('returns nothing when every deal already has a draft', () => {
    expect(
      selectReviewCandidates([reviewDeal({ hasPendingDraft: true })]),
    ).toEqual([]);
  });

  it('handles an empty input', () => {
    expect(selectReviewCandidates([])).toEqual([]);
  });
});

describe('buildReviewPrompt', () => {
  it('states how many deals drifted', () => {
    expect(buildReviewPrompt([reviewDeal()], 'Wednesday 23 September')).toContain(
      '1 deals have drifted',
    );
  });

  it('labels each deal with its id so tool calls can be attributed', () => {
    expect(buildReviewPrompt([reviewDeal()], 'Wednesday')).toContain('[deal deal-1]');
  });

  it('includes the drift reason', () => {
    expect(buildReviewPrompt([reviewDeal()], 'Wednesday')).toContain('gone quiet for 12 days');
  });

  it('includes recent note text', () => {
    expect(buildReviewPrompt([reviewDeal()], 'Wednesday')).toContain(
      'she was worried about onboarding time',
    );
  });

  it('warns when a draft is already waiting', () => {
    expect(buildReviewPrompt([reviewDeal({ hasPendingDraft: true })], 'Wednesday')).toContain(
      'ALREADY waiting',
    );
  });

  it('lists open reminders to prevent duplication', () => {
    expect(
      buildReviewPrompt([reviewDeal({ openReminders: ['Chase the order form'] })], 'Wednesday'),
    ).toContain('Chase the order form');
  });

  it('says plainly when a deal has no notes to reference', () => {
    expect(buildReviewPrompt([reviewDeal({ recentNotes: [] })], 'Wednesday')).toContain(
      'nothing specific to reference',
    );
  });

  it('states that acting on none is acceptable', () => {
    expect(buildReviewPrompt([reviewDeal()], 'Wednesday')).toContain('Acting on none is acceptable');
  });
});

describe('inferDealId', () => {
  const candidates = [{ dealId: 'deal-aaa' }, { dealId: 'deal-bbb' }];

  it('finds the deal id echoed in the arguments', () => {
    expect(inferDealId('{"occasion":"gone_quiet","deal":"deal-bbb"}', candidates)).toBe('deal-bbb');
  });

  it('falls back to the most urgent candidate when no id appears', () => {
    expect(inferDealId('{"occasion":"gone_quiet"}', candidates)).toBe('deal-aaa');
  });

  it('returns null when there are no candidates', () => {
    expect(inferDealId('{}', [])).toBeNull();
  });
});
