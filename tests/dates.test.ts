import { describe, it, expect } from 'vitest';
import { resolveDate, isPlausibleDeadline, repairYear } from '@/lib/domain/dates';

// Wednesday 23 September 2026, local time.
const WEDNESDAY = new Date(2026, 8, 23, 12, 0, 0, 0);

function iso(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

describe('resolveDate', () => {
  it('returns null for null and empty input', () => {
    expect(resolveDate(null, WEDNESDAY)).toBeNull();
    expect(resolveDate(undefined, WEDNESDAY)).toBeNull();
    expect(resolveDate('   ', WEDNESDAY)).toBeNull();
  });

  it('accepts a full ISO timestamp verbatim', () => {
    const result = resolveDate('2026-10-30T14:30:00Z', WEDNESDAY);
    expect(result?.precision).toBe('exact');
    expect(result?.date.toISOString()).toBe('2026-10-30T14:30:00.000Z');
  });

  it('gives a bare ISO date a business morning time', () => {
    const result = resolveDate('2026-10-30', WEDNESDAY);
    expect(iso(result!.date)).toBe('2026-10-30');
    expect(result!.date.getHours()).toBe(9);
    expect(result!.precision).toBe('day');
  });

  it('resolves today to end of business', () => {
    const result = resolveDate('today', WEDNESDAY);
    expect(iso(result!.date)).toBe('2026-09-23');
    expect(result!.date.getHours()).toBe(17);
  });

  it('resolves end of day', () => {
    expect(iso(resolveDate('end of day', WEDNESDAY)!.date)).toBe('2026-09-23');
  });

  it('resolves tomorrow', () => {
    expect(iso(resolveDate('tomorrow', WEDNESDAY)!.date)).toBe('2026-09-24');
  });

  it('resolves the day after tomorrow', () => {
    expect(iso(resolveDate('day after tomorrow', WEDNESDAY)!.date)).toBe('2026-09-25');
  });

  it('resolves a weekday later this week', () => {
    // Wednesday -> Friday is two days on.
    expect(iso(resolveDate('Friday', WEDNESDAY)!.date)).toBe('2026-09-25');
  });

  it('resolves a weekday that has already passed to next week', () => {
    // Wednesday -> Monday must roll forward.
    expect(iso(resolveDate('Monday', WEDNESDAY)!.date)).toBe('2026-09-28');
  });

  it('treats the same weekday as a week away, never today', () => {
    expect(iso(resolveDate('Wednesday', WEDNESDAY)!.date)).toBe('2026-09-30');
  });

  it('handles the "on Tuesday" phrasing', () => {
    expect(iso(resolveDate('on Tuesday', WEDNESDAY)!.date)).toBe('2026-09-29');
  });

  it('handles abbreviated weekdays', () => {
    expect(iso(resolveDate('fri', WEDNESDAY)!.date)).toBe('2026-09-25');
  });

  it('pushes "next Friday" past this coming Friday', () => {
    const thisFriday = resolveDate('Friday', WEDNESDAY)!.date;
    const nextFriday = resolveDate('next Friday', WEDNESDAY)!.date;
    expect(nextFriday.getTime()).toBeGreaterThan(thisFriday.getTime());
  });

  it('resolves a numeric day offset', () => {
    expect(iso(resolveDate('in 3 days', WEDNESDAY)!.date)).toBe('2026-09-26');
  });

  it('resolves a spelled-out day offset', () => {
    expect(iso(resolveDate('in three days', WEDNESDAY)!.date)).toBe('2026-09-26');
  });

  it('resolves "in a couple of days" and marks it approximate', () => {
    const result = resolveDate('in a couple of days', WEDNESDAY)!;
    expect(iso(result.date)).toBe('2026-09-25');
    expect(result.precision).toBe('approximate');
  });

  it('resolves a week offset', () => {
    expect(iso(resolveDate('in 2 weeks', WEDNESDAY)!.date)).toBe('2026-10-07');
  });

  it('resolves a month offset', () => {
    expect(iso(resolveDate('in 1 month', WEDNESDAY)!.date)).toBe('2026-10-23');
  });

  it('resolves end of week to Friday close of business', () => {
    const result = resolveDate('end of week', WEDNESDAY)!;
    expect(iso(result.date)).toBe('2026-09-25');
    expect(result.date.getHours()).toBe(17);
  });

  it('resolves end of next week a week later', () => {
    expect(iso(resolveDate('end of next week', WEDNESDAY)!.date)).toBe('2026-10-02');
  });

  it('resolves next week to the coming Monday', () => {
    expect(iso(resolveDate('next week', WEDNESDAY)!.date)).toBe('2026-09-28');
  });

  it('resolves next month to the first of that month', () => {
    const result = resolveDate('next month', WEDNESDAY)!;
    expect(result.date.getMonth()).toBe(9);
    expect(result.date.getDate()).toBe(1);
  });

  it('ignores trailing punctuation', () => {
    expect(iso(resolveDate('Friday.', WEDNESDAY)!.date)).toBe('2026-09-25');
  });

  it('is case insensitive', () => {
    expect(iso(resolveDate('TOMORROW', WEDNESDAY)!.date)).toBe('2026-09-24');
  });

  it('returns null for a phrase with no time in it', () => {
    expect(resolveDate('when they get budget approval', WEDNESDAY)).toBeNull();
  });

  it('returns null for an unparseable date string', () => {
    expect(resolveDate('2026-13-45', WEDNESDAY)).toBeNull();
  });
});

describe('isPlausibleDeadline', () => {
  it('accepts a date a month out', () => {
    expect(isPlausibleDeadline(new Date(2026, 9, 23), WEDNESDAY)).toBe(true);
  });

  it('accepts a recently passed date', () => {
    expect(isPlausibleDeadline(new Date(2026, 7, 23), WEDNESDAY)).toBe(true);
  });

  it('rejects a date years in the past', () => {
    expect(isPlausibleDeadline(new Date(2021, 0, 1), WEDNESDAY)).toBe(false);
  });

  it('rejects a date far in the future', () => {
    expect(isPlausibleDeadline(new Date(2031, 0, 1), WEDNESDAY)).toBe(false);
  });
});

describe('repairYear', () => {
  it('leaves a plausible date alone', () => {
    const date = new Date(2026, 9, 30);
    expect(repairYear(date, WEDNESDAY).getTime()).toBe(date.getTime());
  });

  it('pulls a stale training-data year forward', () => {
    const stale = new Date(2023, 9, 30);
    const repaired = repairYear(stale, WEDNESDAY);
    expect(repaired.getFullYear()).toBe(2026);
    expect(repaired.getMonth()).toBe(9);
    expect(repaired.getDate()).toBe(30);
  });

  it('rolls into next year when this year has already passed', () => {
    // 14 February 2026 is behind us, so the next occurrence is 2027.
    const stale = new Date(2020, 1, 14);
    const repaired = repairYear(stale, WEDNESDAY);
    expect(repaired.getFullYear()).toBe(2027);
    expect(repaired.getMonth()).toBe(1);
    expect(repaired.getDate()).toBe(14);
  });

  it('projects any month and day onto a future year', () => {
    // Every month/day pair has a next occurrence, so repair always finds one
    // rather than handing back an implausible input untouched.
    const absurd = new Date(1900, 0, 1);
    const repaired = repairYear(absurd, WEDNESDAY);
    expect(repaired.getTime()).toBeGreaterThan(WEDNESDAY.getTime());
    expect(repaired.getMonth()).toBe(0);
    expect(repaired.getDate()).toBe(1);
  });

  it('prefers a future reading over a recently passed one', () => {
    const repaired = repairYear(new Date(2023, 1, 14), WEDNESDAY);
    expect(repaired.getTime()).toBeGreaterThan(WEDNESDAY.getTime());
  });
});
