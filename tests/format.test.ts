import { describe, it, expect } from 'vitest';
import {
  formatDateKey,
  formatClock,
  formatRelativeDay,
  calendarDayDelta,
  formatAgo,
  formatDuration,
  truncateWords,
  titleCase,
} from '@/lib/format';

const UTC = 'UTC';
const NOW = new Date('2026-09-23T12:00:00Z');

describe('formatDateKey', () => {
  it('produces an ISO day key', () => {
    expect(formatDateKey(NOW, UTC)).toBe('2026-09-23');
  });

  it('respects the timezone across a day boundary', () => {
    // 23:30 UTC is already the 24th in Kolkata (+05:30).
    const late = new Date('2026-09-23T23:30:00Z');
    expect(formatDateKey(late, 'Asia/Kolkata')).toBe('2026-09-24');
  });

  it('falls back gracefully on an invalid timezone', () => {
    expect(formatDateKey(NOW, 'Not/AZone')).toBe('2026-09-23');
  });
});

describe('formatClock', () => {
  it('formats 24 hour time', () => {
    expect(formatClock(NOW, UTC)).toBe('12:00');
  });

  it('shifts with the timezone', () => {
    expect(formatClock(NOW, 'Asia/Kolkata')).toBe('17:30');
  });

  it('falls back on an invalid timezone', () => {
    expect(formatClock(NOW, 'Not/AZone')).toBe('12:00');
  });
});

describe('calendarDayDelta', () => {
  it('is zero for the same day', () => {
    expect(calendarDayDelta(new Date('2026-09-23T01:00:00Z'), NOW, UTC)).toBe(0);
  });

  it('is one for tomorrow', () => {
    expect(calendarDayDelta(new Date('2026-09-24T01:00:00Z'), NOW, UTC)).toBe(1);
  });

  it('is negative for the past', () => {
    expect(calendarDayDelta(new Date('2026-09-20T23:00:00Z'), NOW, UTC)).toBe(-3);
  });
});

describe('formatRelativeDay', () => {
  it('says today', () => {
    expect(formatRelativeDay(NOW, NOW, UTC)).toBe('today');
  });

  it('says tomorrow', () => {
    expect(formatRelativeDay(new Date('2026-09-24T09:00:00Z'), NOW, UTC)).toBe('tomorrow');
  });

  it('says yesterday', () => {
    expect(formatRelativeDay(new Date('2026-09-22T09:00:00Z'), NOW, UTC)).toBe('yesterday');
  });

  it('names the weekday within the coming week', () => {
    expect(formatRelativeDay(new Date('2026-09-25T09:00:00Z'), NOW, UTC)).toBe('Friday');
  });

  it('counts days for the recent past', () => {
    expect(formatRelativeDay(new Date('2026-09-19T09:00:00Z'), NOW, UTC)).toBe('4 days ago');
  });

  it('falls back to a full date when far away', () => {
    expect(formatRelativeDay(new Date('2026-12-25T09:00:00Z'), NOW, UTC)).toContain('December');
  });
});

describe('formatAgo', () => {
  it('says today for the same day', () => {
    expect(formatAgo(NOW, NOW, UTC)).toBe('today');
  });

  it('counts forward', () => {
    expect(formatAgo(new Date('2026-09-30T09:00:00Z'), NOW, UTC)).toBe('in 7 days');
  });

  it('counts backward', () => {
    expect(formatAgo(new Date('2026-09-14T09:00:00Z'), NOW, UTC)).toBe('9 days ago');
  });
});

describe('formatDuration', () => {
  it('formats seconds under a minute', () => {
    expect(formatDuration(45)).toBe('45s');
  });

  it('formats a whole minute without seconds', () => {
    expect(formatDuration(120)).toBe('2m');
  });

  it('formats minutes and seconds', () => {
    expect(formatDuration(83)).toBe('1m 23s');
  });

  it('rounds fractional seconds', () => {
    expect(formatDuration(59.6)).toBe('1m');
  });

  it('handles zero and negatives defensively', () => {
    expect(formatDuration(0)).toBe('0s');
    expect(formatDuration(-5)).toBe('0s');
    expect(formatDuration(Number.NaN)).toBe('0s');
  });
});

describe('truncateWords', () => {
  it('leaves short text alone', () => {
    expect(truncateWords('short', 20)).toBe('short');
  });

  it('cuts on a word boundary', () => {
    expect(truncateWords('the quick brown fox jumps over', 19)).toBe('the quick brown…');
  });

  it('hard cuts when there is no usable space', () => {
    expect(truncateWords('aaaaaaaaaaaaaaaaaaaaaa', 10)).toBe('aaaaaaaaaa…');
  });
});

describe('titleCase', () => {
  it('capitalises the first letter', () => {
    expect(titleCase('proposal')).toBe('Proposal');
  });

  it('leaves an empty string alone', () => {
    expect(titleCase('')).toBe('');
  });

  it('does not lowercase the rest', () => {
    expect(titleCase('wON')).toBe('WON');
  });
});
