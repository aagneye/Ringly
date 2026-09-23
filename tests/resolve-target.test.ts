import { describe, it, expect } from 'vitest';
import { defaultDealTitle } from '@/lib/repo/resolve-target';

describe('defaultDealTitle', () => {
  it('combines company and name when both are known', () => {
    expect(defaultDealTitle('Priya Sharma', 'Northwind')).toBe('Northwind — Priya Sharma');
  });

  it('falls back to the name alone with no company', () => {
    expect(defaultDealTitle('Priya Sharma', null)).toBe('Priya Sharma');
  });

  it('handles an empty company string as no company', () => {
    expect(defaultDealTitle('Priya Sharma', '')).toBe('Priya Sharma');
  });
});
