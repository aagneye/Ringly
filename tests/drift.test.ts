import { describe, it, expect } from 'vitest';
import {
  detectDrift,
  detectPipelineDrift,
  healthScore,
  daysBetween,
  STAGE_SILENCE_TOLERANCE_DAYS,
  type DriftInput,
} from '@/lib/domain/drift';

const NOW = new Date('2026-09-23T12:00:00Z');

function daysAgo(days: number): Date {
  return new Date(NOW.getTime() - days * 86_400_000);
}

function daysAhead(days: number): Date {
  return new Date(NOW.getTime() + days * 86_400_000);
}

function deal(overrides: Partial<DriftInput> = {}): DriftInput {
  return {
    id: 'd1',
    title: 'Northwind pilot',
    stage: 'proposal',
    lastContactAt: daysAgo(1),
    deadline: null,
    nextAction: null,
    createdAt: daysAgo(10),
    ...overrides,
  };
}

describe('daysBetween', () => {
  it('counts whole days forward', () => {
    expect(daysBetween(daysAgo(3), NOW)).toBe(3);
  });

  it('is negative when the target is in the past', () => {
    expect(daysBetween(NOW, daysAgo(2))).toBe(-2);
  });

  it('is zero within the same day', () => {
    expect(daysBetween(new Date('2026-09-23T01:00:00Z'), NOW)).toBe(0);
  });
});

describe('detectDrift', () => {
  it('reports nothing for a healthy recent deal', () => {
    expect(detectDrift(deal(), NOW)).toEqual([]);
  });

  it('ignores won deals entirely', () => {
    const signals = detectDrift(deal({ stage: 'won', lastContactAt: daysAgo(400) }), NOW);
    expect(signals).toEqual([]);
  });

  it('ignores lost deals entirely', () => {
    const signals = detectDrift(deal({ stage: 'lost', lastContactAt: daysAgo(400) }), NOW);
    expect(signals).toEqual([]);
  });

  it('flags a deal that has gone quiet past its stage tolerance', () => {
    const signals = detectDrift(deal({ stage: 'proposal', lastContactAt: daysAgo(9) }), NOW);
    expect(signals.map((s) => s.reason)).toContain('gone_quiet');
  });

  it('does not flag silence within the stage tolerance', () => {
    const tolerance = STAGE_SILENCE_TOLERANCE_DAYS.contacted;
    const signals = detectDrift(
      deal({ stage: 'contacted', lastContactAt: daysAgo(tolerance) }),
      NOW,
    );
    expect(signals.map((s) => s.reason)).not.toContain('gone_quiet');
  });

  it('applies a tighter tolerance at the proposal stage than when contacted', () => {
    expect(STAGE_SILENCE_TOLERANCE_DAYS.proposal).toBeLessThan(
      STAGE_SILENCE_TOLERANCE_DAYS.contacted,
    );
  });

  it('flags a passed deadline with high urgency', () => {
    const signals = detectDrift(deal({ deadline: daysAgo(4) }), NOW);
    const passed = signals.find((s) => s.reason === 'deadline_passed');
    expect(passed).toBeDefined();
    expect(passed!.urgency).toBeGreaterThan(85);
  });

  it('flags a deadline due today', () => {
    const signals = detectDrift(deal({ deadline: new Date(NOW.getTime() + 3_600_000) }), NOW);
    expect(signals.map((s) => s.reason)).toContain('deadline_imminent');
  });

  it('flags a deadline two days out', () => {
    const signals = detectDrift(deal({ deadline: daysAhead(2) }), NOW);
    expect(signals.map((s) => s.reason)).toContain('deadline_imminent');
  });

  it('ignores a deadline comfortably in the future', () => {
    const signals = detectDrift(deal({ deadline: daysAhead(20) }), NOW);
    expect(signals.map((s) => s.reason)).not.toContain('deadline_imminent');
  });

  it('flags a deal never contacted after two days open', () => {
    const signals = detectDrift(deal({ lastContactAt: null, createdAt: daysAgo(5) }), NOW);
    expect(signals.map((s) => s.reason)).toContain('never_contacted');
  });

  it('gives a brand new uncontacted deal a grace period', () => {
    const signals = detectDrift(deal({ lastContactAt: null, createdAt: daysAgo(1) }), NOW);
    expect(signals).toEqual([]);
  });

  it('flags a promise left without a date', () => {
    const signals = detectDrift(
      deal({ stage: 'contacted', nextAction: 'send the pricing sheet', lastContactAt: daysAgo(4) }),
      NOW,
    );
    expect(signals.map((s) => s.reason)).toContain('stalled_commitment');
  });

  it('does not raise a stalled commitment when a deadline exists', () => {
    const signals = detectDrift(
      deal({ nextAction: 'send pricing', lastContactAt: daysAgo(4), deadline: daysAhead(10) }),
      NOW,
    );
    expect(signals.map((s) => s.reason)).not.toContain('stalled_commitment');
  });

  it('returns multiple signals sorted by descending urgency', () => {
    const signals = detectDrift(
      deal({ stage: 'proposal', lastContactAt: daysAgo(14), deadline: daysAgo(3) }),
      NOW,
    );
    expect(signals.length).toBeGreaterThan(1);
    for (let i = 1; i < signals.length; i += 1) {
      expect(signals[i - 1]!.urgency).toBeGreaterThanOrEqual(signals[i]!.urgency);
    }
  });

  it('writes an explanation naming the deal', () => {
    const signals = detectDrift(deal({ lastContactAt: daysAgo(12) }), NOW);
    expect(signals[0]!.explanation).toContain('Northwind pilot');
  });

  it('caps urgency at 100 for a long overdue deadline', () => {
    const signals = detectDrift(deal({ deadline: daysAgo(400) }), NOW);
    expect(signals[0]!.urgency).toBeLessThanOrEqual(100);
  });
});

describe('detectPipelineDrift', () => {
  it('returns an empty list for an empty pipeline', () => {
    expect(detectPipelineDrift([], NOW)).toEqual([]);
  });

  it('orders signals across deals by urgency', () => {
    const signals = detectPipelineDrift(
      [
        deal({ id: 'quiet', stage: 'contacted', lastContactAt: daysAgo(9) }),
        deal({ id: 'overdue', deadline: daysAgo(6) }),
      ],
      NOW,
    );
    expect(signals[0]!.dealId).toBe('overdue');
  });

  it('skips healthy deals', () => {
    const signals = detectPipelineDrift([deal({ id: 'fine' }), deal({ id: 'also-fine' })], NOW);
    expect(signals).toEqual([]);
  });
});

describe('healthScore', () => {
  it('is 100 for a won deal', () => {
    expect(healthScore(deal({ stage: 'won' }), NOW)).toBe(100);
  });

  it('is 0 for a lost deal', () => {
    expect(healthScore(deal({ stage: 'lost' }), NOW)).toBe(0);
  });

  it('is high for a healthy deal', () => {
    expect(healthScore(deal(), NOW)).toBeGreaterThan(85);
  });

  it('drops sharply for an overdue deal', () => {
    expect(healthScore(deal({ deadline: daysAgo(5) }), NOW)).toBeLessThan(20);
  });

  it('never goes below 5 for an open deal', () => {
    const score = healthScore(
      deal({ stage: 'proposal', lastContactAt: daysAgo(90), deadline: daysAgo(90) }),
      NOW,
    );
    expect(score).toBeGreaterThanOrEqual(5);
  });

  it('compounds multiple problems', () => {
    const single = healthScore(deal({ stage: 'proposal', lastContactAt: daysAgo(9) }), NOW);
    const multiple = healthScore(
      deal({
        stage: 'proposal',
        lastContactAt: daysAgo(9),
        nextAction: 'send revised quote',
      }),
      NOW,
    );
    expect(multiple).toBeLessThan(single);
  });
});
