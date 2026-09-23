import { describe, it, expect } from 'vitest';
import { buildIcs, escapeIcsText, formatIcsTimestamp, foldIcsLine } from '@/lib/ics';

const NOW = new Date('2026-09-23T12:00:00Z');

describe('escapeIcsText', () => {
  it('escapes commas, which would otherwise split the property', () => {
    expect(escapeIcsText('Pricing, onboarding')).toBe('Pricing\\, onboarding');
  });

  it('escapes semicolons', () => {
    expect(escapeIcsText('a;b')).toBe('a\\;b');
  });

  it('escapes backslashes first so escapes are not double-processed', () => {
    expect(escapeIcsText('a\\b')).toBe('a\\\\b');
  });

  it('converts newlines to the literal escape', () => {
    expect(escapeIcsText('line one\nline two')).toBe('line one\\nline two');
  });

  it('converts CRLF newlines too', () => {
    expect(escapeIcsText('a\r\nb')).toBe('a\\nb');
  });

  it('leaves plain text alone', () => {
    expect(escapeIcsText('Call with Priya')).toBe('Call with Priya');
  });
});

describe('formatIcsTimestamp', () => {
  it('produces basic-format UTC', () => {
    expect(formatIcsTimestamp(NOW)).toBe('20260923T120000Z');
  });

  it('zero-pads single digit components', () => {
    expect(formatIcsTimestamp(new Date('2026-01-05T04:07:09Z'))).toBe('20260105T040709Z');
  });

  it('normalises a non-UTC instant to UTC', () => {
    expect(formatIcsTimestamp(new Date('2026-09-23T23:30:00+05:30'))).toBe('20260923T180000Z');
  });
});

describe('foldIcsLine', () => {
  it('leaves a short line alone', () => {
    expect(foldIcsLine('SUMMARY:Call')).toBe('SUMMARY:Call');
  });

  it('leaves a line of exactly 75 characters alone', () => {
    const line = 'A'.repeat(75);
    expect(foldIcsLine(line)).toBe(line);
  });

  it('folds a long line with a leading space on continuations', () => {
    const folded = foldIcsLine('A'.repeat(200));
    const parts = folded.split('\r\n');
    expect(parts.length).toBeGreaterThan(1);
    expect(parts[0]).toHaveLength(75);
    for (const part of parts.slice(1)) {
      expect(part.startsWith(' ')).toBe(true);
    }
  });

  it('preserves every character across the fold', () => {
    const original = 'B'.repeat(300);
    const rejoined = foldIcsLine(original).split('\r\n').join('').replace(/^ | /g, '');
    expect(rejoined.replace(/ /g, '')).toBe(original);
  });
});

describe('buildIcs', () => {
  const event = {
    uid: 'event-1',
    title: 'Pricing walkthrough with Priya',
    startsAt: new Date('2026-09-25T09:00:00Z'),
    endsAt: new Date('2026-09-25T09:30:00Z'),
    description: 'She wants the revised sheet before the board meeting.',
    location: 'Google Meet',
  };

  it('opens and closes the calendar correctly', () => {
    const ics = buildIcs(event, NOW);
    expect(ics.startsWith('BEGIN:VCALENDAR')).toBe(true);
    expect(ics.trimEnd().endsWith('END:VCALENDAR')).toBe(true);
  });

  it('includes exactly one event block', () => {
    const ics = buildIcs(event, NOW);
    expect(ics.match(/BEGIN:VEVENT/g)).toHaveLength(1);
    expect(ics.match(/END:VEVENT/g)).toHaveLength(1);
  });

  it('uses CRLF line endings as the spec requires', () => {
    expect(buildIcs(event, NOW)).toContain('\r\n');
  });

  it('writes the start and end timestamps', () => {
    const ics = buildIcs(event, NOW);
    expect(ics).toContain('DTSTART:20260925T090000Z');
    expect(ics).toContain('DTEND:20260925T093000Z');
  });

  it('namespaces the uid', () => {
    expect(buildIcs(event, NOW)).toContain('UID:event-1@ringly');
  });

  it('includes the location and description when present', () => {
    const ics = buildIcs(event, NOW);
    expect(ics).toContain('LOCATION:Google Meet');
    expect(ics).toContain('DESCRIPTION:She wants');
  });

  it('omits optional fields when absent', () => {
    const ics = buildIcs({ ...event, description: null, location: null }, NOW);
    expect(ics).not.toContain('DESCRIPTION:');
    expect(ics).not.toContain('LOCATION:');
  });

  it('escapes a comma in the title', () => {
    const ics = buildIcs({ ...event, title: 'Pricing, then onboarding' }, NOW);
    expect(ics).toContain('SUMMARY:Pricing\\, then onboarding');
  });
});
