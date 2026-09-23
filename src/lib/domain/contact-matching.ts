/**
 * Resolving a spoken name to a stored contact.
 *
 * A voice memo gives you "spoke to priya at northwind" — no ID, inconsistent
 * casing, and a transcriber that may render "Northwind" as "North Wind". If
 * matching fails the memory silently forks into two half-contacts, which
 * defeats the entire point of the product, so this module is deliberately
 * conservative and heavily tested.
 */

/** Words that carry no identifying signal in a company name. */
const COMPANY_NOISE = new Set([
  'inc',
  'inc.',
  'llc',
  'ltd',
  'ltd.',
  'limited',
  'corp',
  'corp.',
  'corporation',
  'co',
  'co.',
  'company',
  'gmbh',
  'plc',
  'pvt',
  'private',
  'the',
  'group',
  'holdings',
  'technologies',
  'technology',
  'labs',
  'lab',
  'solutions',
  'systems',
  'services',
  'software',
]);

/** Lowercase, strip accents and punctuation, collapse whitespace. */
export function normaliseName(input: string): string {
  return input
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Normalise a company name and drop legal suffixes and filler words, so
 * "The Northwind Group Ltd." and "northwind" compare equal.
 */
export function normaliseCompany(input: string): string {
  const base = normaliseName(input);
  if (!base) return '';

  const kept = base.split(' ').filter((word) => !COMPANY_NOISE.has(word));
  // If every token was noise, fall back to the normalised original rather than
  // returning an empty key that would match every other all-noise company.
  return (kept.length > 0 ? kept : base.split(' ')).join('');
}

/** First name only, for greeting and for loose matching. */
export function firstName(input: string): string {
  const normalised = normaliseName(input);
  return normalised.split(' ')[0] ?? '';
}

/**
 * Levenshtein distance, capped for early exit.
 *
 * Used to absorb transcription slips like "Priya" versus "Prea". Capping keeps
 * it linear in practice and stops a long string pair from dominating a request.
 */
export function editDistance(a: string, b: string, cap = 3): number {
  if (a === b) return 0;
  if (Math.abs(a.length - b.length) > cap) return cap + 1;

  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);

  for (let i = 1; i <= a.length; i += 1) {
    const current: number[] = [i];
    let rowMin = i;

    for (let j = 1; j <= b.length; j += 1) {
      const substitution = (previous[j - 1] ?? 0) + (a[i - 1] === b[j - 1] ? 0 : 1);
      const insertion = (current[j - 1] ?? 0) + 1;
      const deletion = (previous[j] ?? 0) + 1;
      const value = Math.min(substitution, insertion, deletion);
      current[j] = value;
      if (value < rowMin) rowMin = value;
    }

    if (rowMin > cap) return cap + 1;
    previous = current;
  }

  return previous[b.length] ?? cap + 1;
}

export interface MatchCandidate {
  id: string;
  normalisedName: string;
  normalisedCompany: string | null;
}

export interface MatchResult {
  id: string;
  confidence: 'exact' | 'company' | 'fuzzy';
}

/**
 * Pick the stored contact a spoken name refers to.
 *
 * Ordered by how much evidence each rule requires, strongest first. A fuzzy
 * name match is only trusted when the company also agrees, because merging two
 * different clients is far more damaging than creating a duplicate the user can
 * see and fix.
 */
export function matchContact(
  spokenName: string,
  spokenCompany: string | null,
  candidates: readonly MatchCandidate[],
): MatchResult | null {
  const name = normaliseName(spokenName);
  if (!name) return null;

  const company = spokenCompany ? normaliseCompany(spokenCompany) : null;

  const exact = candidates.find((c) => c.normalisedName === name);
  if (exact) return { id: exact.id, confidence: 'exact' };

  if (company) {
    const sameCompany = candidates.filter((c) => c.normalisedCompany === company);

    const firstNameMatch = sameCompany.find(
      (c) => (c.normalisedName.split(' ')[0] ?? '') === (name.split(' ')[0] ?? ''),
    );
    if (firstNameMatch) return { id: firstNameMatch.id, confidence: 'company' };

    const fuzzyInCompany = sameCompany.find((c) => editDistance(c.normalisedName, name, 2) <= 2);
    if (fuzzyInCompany) return { id: fuzzyInCompany.id, confidence: 'fuzzy' };
  }

  // No company to corroborate: only accept a unique first-name match, so that
  // two contacts both called "Sam" never silently collapse into one.
  const spokenFirst = name.split(' ')[0] ?? '';
  const firstNameMatches = candidates.filter(
    (c) => (c.normalisedName.split(' ')[0] ?? '') === spokenFirst,
  );
  if (firstNameMatches.length === 1 && firstNameMatches[0]) {
    return { id: firstNameMatches[0].id, confidence: 'fuzzy' };
  }

  return null;
}
