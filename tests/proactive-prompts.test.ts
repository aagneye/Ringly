import { describe, it, expect } from 'vitest';
import {
  buildBriefingPrompt,
  isBriefingEmpty,
  BRIEFING_SYSTEM_PROMPT,
  type BriefingInput,
} from '@/lib/agent/prompts/briefing';
import { buildAskPrompt, selectRelevantDeals, ASK_SYSTEM_PROMPT } from '@/lib/agent/prompts/ask';
import { buildPrecallPrompt, type PrecallInput } from '@/lib/agent/prompts/precall';

function briefingInput(overrides: Partial<BriefingInput> = {}): BriefingInput {
  return {
    todayLabel: 'Wednesday 23 September 2026',
    userName: 'Alex',
    meetings: [],
    reminders: [],
    pendingDrafts: [],
    driftSignals: [],
    ...overrides,
  };
}

describe('BRIEFING_SYSTEM_PROMPT', () => {
  it('caps the briefing at three items', () => {
    expect(BRIEFING_SYSTEM_PROMPT).toContain('Three items maximum');
  });

  it('bans the list voice so it reads aloud well', () => {
    expect(BRIEFING_SYSTEM_PROMPT).toContain('no bullet points');
  });

  it('forbids pep talk', () => {
    expect(BRIEFING_SYSTEM_PROMPT).toContain('No pep talk');
  });

  it('makes leaving things out part of the job', () => {
    expect(BRIEFING_SYSTEM_PROMPT).toContain('Choosing what to leave out is the job');
  });
});

describe('isBriefingEmpty', () => {
  it('is true for a completely quiet pipeline', () => {
    expect(isBriefingEmpty(briefingInput())).toBe(true);
  });

  it('is false when a meeting exists', () => {
    expect(
      isBriefingEmpty(
        briefingInput({
          meetings: [{ title: 'Call', whenLabel: '11:00', contactName: 'Priya', dealId: 'd1' }],
        }),
      ),
    ).toBe(false);
  });

  it('is false when only drift exists', () => {
    expect(
      isBriefingEmpty(
        briefingInput({ driftSignals: [{ dealId: 'd1', explanation: 'quiet', urgency: 50 }] }),
      ),
    ).toBe(false);
  });

  it('is false when only a draft is pending', () => {
    expect(
      isBriefingEmpty(
        briefingInput({
          pendingDrafts: [{ subject: 'Pricing', contactName: 'Priya', dealId: 'd1' }],
        }),
      ),
    ).toBe(false);
  });
});

describe('buildBriefingPrompt', () => {
  it('writes "none" for each empty section', () => {
    const prompt = buildBriefingPrompt(briefingInput());
    expect(prompt.match(/- none/g)).toHaveLength(4);
  });

  it('renders meetings with time and person', () => {
    const prompt = buildBriefingPrompt(
      briefingInput({
        meetings: [
          { title: 'Pricing walkthrough', whenLabel: '11:00', contactName: 'Priya', dealId: 'd1' },
        ],
      }),
    );
    expect(prompt).toContain('11:00: Pricing walkthrough with Priya');
    expect(prompt).toContain('[deal d1]');
  });

  it('marks overdue reminders', () => {
    const prompt = buildBriefingPrompt(
      briefingInput({
        reminders: [
          { message: 'Send quote', dueLabel: 'yesterday', dealId: 'd1', overdue: true },
        ],
      }),
    );
    expect(prompt).toContain('OVERDUE');
  });

  it('caps drift signals so a large pipeline cannot flood the prompt', () => {
    const many = Array.from({ length: 40 }, (_, i) => ({
      dealId: `d${i}`,
      explanation: `Deal ${i} has gone quiet`,
      urgency: 50,
    }));
    const prompt = buildBriefingPrompt(briefingInput({ driftSignals: many }));
    expect(prompt).not.toContain('Deal 20 has gone quiet');
  });
});

describe('ASK_SYSTEM_PROMPT', () => {
  it('requires admitting ignorance rather than inventing', () => {
    expect(ASK_SYSTEM_PROMPT).toContain('Never fill a gap with what is plausible');
  });

  it('requires saying when the information was heard', () => {
    expect(ASK_SYSTEM_PROMPT).toContain('Say when you heard it');
  });

  it('separates answering from acting', () => {
    expect(ASK_SYSTEM_PROMPT).toContain('Answering is not doing');
  });
});

describe('selectRelevantDeals', () => {
  const deals = [
    { contactName: 'Priya Sharma', company: 'Northwind' },
    { contactName: 'Ahmed Khan', company: 'Kessler' },
    { contactName: 'Sam Torres', company: 'Acme' },
  ];

  it('picks the deal whose contact is named', () => {
    expect(selectRelevantDeals('what is happening with priya', deals)).toEqual([deals[0]]);
  });

  it('matches on company as well as name', () => {
    expect(selectRelevantDeals('any news from kessler', deals)).toEqual([deals[1]]);
  });

  it('falls back to the whole pipeline when nothing matches', () => {
    expect(selectRelevantDeals('what should I focus on', deals)).toHaveLength(3);
  });

  it('respects the limit on the fallback path', () => {
    expect(selectRelevantDeals('what should I focus on', deals, 2)).toHaveLength(2);
  });

  it('ignores short filler words', () => {
    // "is" and "on" are too short to match anything; "sam" should still win.
    expect(selectRelevantDeals('is sam on track', deals)).toEqual([deals[2]]);
  });

  it('handles an empty deal list', () => {
    expect(selectRelevantDeals('anything', [])).toEqual([]);
  });

  it('handles a question of only punctuation', () => {
    expect(selectRelevantDeals('???', deals)).toHaveLength(3);
  });
});

describe('buildAskPrompt', () => {
  it('says plainly when there are no deals', () => {
    expect(buildAskPrompt('what about priya', [], 'Wednesday')).toContain('no deals on file');
  });

  it('includes the question and note text', () => {
    const prompt = buildAskPrompt(
      'what did priya say about budget',
      [
        {
          dealId: 'd1',
          contactName: 'Priya',
          company: 'Northwind',
          stage: 'proposal',
          nextAction: null,
          deadlineLabel: null,
          budget: 'around 12k',
          concerns: null,
          lastContactLabel: '3 days ago',
          notes: [{ text: 'she mentioned twelve thousand', whenLabel: '3 days ago' }],
        },
      ],
      'Wednesday',
    );
    expect(prompt).toContain('what did priya say about budget');
    expect(prompt).toContain('she mentioned twelve thousand');
    expect(prompt).toContain('around 12k');
  });

  it('states when a deal has no notes', () => {
    const prompt = buildAskPrompt(
      'anything',
      [
        {
          dealId: 'd1',
          contactName: 'Priya',
          company: null,
          stage: 'new',
          nextAction: null,
          deadlineLabel: null,
          budget: null,
          concerns: null,
          lastContactLabel: null,
          notes: [],
        },
      ],
      'Wednesday',
    );
    expect(prompt).toContain('No call notes recorded');
  });
});

describe('buildPrecallPrompt', () => {
  function precall(overrides: Partial<PrecallInput> = {}): PrecallInput {
    return {
      contactName: 'Priya Sharma',
      company: 'Northwind',
      role: 'Head of Ops',
      dealTitle: 'Northwind pilot',
      stage: 'proposal',
      nextAction: 'send pricing',
      deadlineLabel: 'Friday',
      budget: 'around 12k',
      concerns: 'onboarding time',
      daysSinceLastContact: 4,
      transcripts: [{ text: 'she worried about onboarding', whenLabel: '4 days ago' }],
      openReminders: ['Send the pricing sheet'],
      companyFacts: ['Raised a Series A in August 2026'],
      ...overrides,
    };
  }

  it('names the person, company and role', () => {
    const prompt = buildPrecallPrompt(precall());
    expect(prompt).toContain('Priya Sharma');
    expect(prompt).toContain('Northwind');
    expect(prompt).toContain('Head of Ops');
  });

  it('includes verbatim transcripts', () => {
    expect(buildPrecallPrompt(precall())).toContain('she worried about onboarding');
  });

  it('flags a first conversation when there is no history', () => {
    expect(buildPrecallPrompt(precall({ transcripts: [] }))).toContain(
      'This is the first conversation',
    );
  });

  it('lists outstanding commitments', () => {
    expect(buildPrecallPrompt(precall())).toContain('STILL OUTSTANDING');
  });

  it('omits the company news section when there are no facts', () => {
    expect(buildPrecallPrompt(precall({ companyFacts: [] }))).not.toContain('RECENT COMPANY NEWS');
  });

  it('omits the deal record section when every field is empty', () => {
    const prompt = buildPrecallPrompt(
      precall({ nextAction: null, deadlineLabel: null, budget: null, concerns: null }),
    );
    expect(prompt).not.toContain('DEAL RECORD');
  });
});
