import { describe, it, expect } from 'vitest';
import { extractJsonBlock, parseJsonLoose } from '@/lib/nebius/json';

describe('extractJsonBlock', () => {
  it('returns clean JSON unchanged', () => {
    expect(extractJsonBlock('{"a":1}')).toBe('{"a":1}');
  });

  it('unwraps a fenced json block', () => {
    const raw = 'Sure! Here is the data:\n```json\n{"contact_name":"Priya"}\n```';
    expect(parseJsonLoose(raw)).toEqual({ contact_name: 'Priya' });
  });

  it('unwraps a fence with no language tag', () => {
    expect(parseJsonLoose('```\n{"stage":"proposal"}\n```')).toEqual({ stage: 'proposal' });
  });

  it('drops a reasoning think block before the answer', () => {
    const raw = '<think>The memo mentions a deadline.</think>\n{"deadline":"2026-10-30"}';
    expect(parseJsonLoose(raw)).toEqual({ deadline: '2026-10-30' });
  });

  it('recovers an object buried in trailing prose', () => {
    const raw = 'Here you go: {"budget":"12k"} — let me know if you need more.';
    expect(parseJsonLoose(raw)).toEqual({ budget: '12k' });
  });

  it('recovers a top-level array', () => {
    expect(parseJsonLoose('The actions are [{"tool":"set_reminder"}] as listed.')).toEqual([
      { tool: 'set_reminder' },
    ]);
  });

  it('ignores braces inside string literals', () => {
    const raw = '{"note":"he said {maybe} next week"}';
    expect(parseJsonLoose(raw)).toEqual({ note: 'he said {maybe} next week' });
  });

  it('handles escaped quotes inside strings', () => {
    const raw = '{"quote":"she said \\"yes\\" firmly"}';
    expect(parseJsonLoose(raw)).toEqual({ quote: 'she said "yes" firmly' });
  });

  it('handles nested objects', () => {
    const raw = 'Result:\n{"deal":{"stage":"won","value":{"amount":500}}}\nDone.';
    expect(parseJsonLoose(raw)).toEqual({ deal: { stage: 'won', value: { amount: 500 } } });
  });

  it('returns null for prose with no JSON', () => {
    expect(extractJsonBlock('I could not find any deal information.')).toBeNull();
    expect(parseJsonLoose('I could not find any deal information.')).toBeNull();
  });

  it('returns null for an empty string', () => {
    expect(extractJsonBlock('')).toBeNull();
  });

  it('returns null for an unterminated object', () => {
    expect(parseJsonLoose('{"contact_name":"Priya"')).toBeNull();
  });
});
