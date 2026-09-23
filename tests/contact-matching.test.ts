import { describe, it, expect } from 'vitest';
import {
  normaliseName,
  normaliseCompany,
  firstName,
  editDistance,
  matchContact,
  type MatchCandidate,
} from '@/lib/domain/contact-matching';

describe('normaliseName', () => {
  it('lowercases and collapses whitespace', () => {
    expect(normaliseName('  Priya   Sharma ')).toBe('priya sharma');
  });

  it('strips accents', () => {
    expect(normaliseName('José Álvarez')).toBe('jose alvarez');
  });

  it('strips punctuation', () => {
    expect(normaliseName("O'Brien-Smith")).toBe('o brien smith');
  });

  it('returns empty for punctuation only', () => {
    expect(normaliseName('---')).toBe('');
  });
});

describe('normaliseCompany', () => {
  it('drops legal suffixes and filler words', () => {
    expect(normaliseCompany('The Northwind Group Ltd.')).toBe('northwind');
  });

  it('treats variants as equal', () => {
    expect(normaliseCompany('Acme Technologies Inc')).toBe(normaliseCompany('acme'));
  });

  it('joins multi-word names so spacing slips do not matter', () => {
    expect(normaliseCompany('North Wind')).toBe('northwind');
    expect(normaliseCompany('Northwind')).toBe('northwind');
  });

  it('falls back to the original when every token is noise', () => {
    expect(normaliseCompany('The Group')).toBe('thegroup');
  });

  it('returns empty for an empty input', () => {
    expect(normaliseCompany('')).toBe('');
  });
});

describe('firstName', () => {
  it('takes the leading token', () => {
    expect(firstName('Priya Sharma')).toBe('priya');
  });

  it('handles a single name', () => {
    expect(firstName('Ahmed')).toBe('ahmed');
  });
});

describe('editDistance', () => {
  it('is zero for identical strings', () => {
    expect(editDistance('priya', 'priya')).toBe(0);
  });

  it('counts a single substitution', () => {
    expect(editDistance('priya', 'preya')).toBe(1);
  });

  it('counts a deletion', () => {
    expect(editDistance('priya', 'prya')).toBe(1);
  });

  it('exits early past the cap', () => {
    expect(editDistance('priya', 'christopher', 3)).toBeGreaterThan(3);
  });
});

describe('matchContact', () => {
  const candidates: MatchCandidate[] = [
    { id: 'c1', normalisedName: 'priya sharma', normalisedCompany: 'northwind' },
    { id: 'c2', normalisedName: 'ahmed khan', normalisedCompany: 'kessler' },
    { id: 'c3', normalisedName: 'sam torres', normalisedCompany: 'acme' },
    { id: 'c4', normalisedName: 'sam whitfield', normalisedCompany: 'vertex' },
  ];

  it('matches on an exact normalised name', () => {
    expect(matchContact('Priya Sharma', null, candidates)).toEqual({
      id: 'c1',
      confidence: 'exact',
    });
  });

  it('matches a first name when the company agrees', () => {
    expect(matchContact('Priya', 'The Northwind Group', candidates)).toEqual({
      id: 'c1',
      confidence: 'company',
    });
  });

  it('absorbs a transcription slip when the company agrees', () => {
    expect(matchContact('Preya Sharma', 'Northwind', candidates)).toEqual({
      id: 'c1',
      confidence: 'fuzzy',
    });
  });

  it('matches a unique first name with no company given', () => {
    expect(matchContact('Ahmed', null, candidates)).toEqual({ id: 'c2', confidence: 'fuzzy' });
  });

  it('refuses an ambiguous first name with no company', () => {
    expect(matchContact('Sam', null, candidates)).toBeNull();
  });

  it('disambiguates a duplicated first name using the company', () => {
    expect(matchContact('Sam', 'Vertex', candidates)).toEqual({ id: 'c4', confidence: 'company' });
  });

  it('returns null for an unknown contact', () => {
    expect(matchContact('Rajesh Patel', 'Globex', candidates)).toBeNull();
  });

  it('returns null for an empty name', () => {
    expect(matchContact('', 'Northwind', candidates)).toBeNull();
  });

  it('returns null against an empty candidate list', () => {
    expect(matchContact('Priya', 'Northwind', [])).toBeNull();
  });
});
