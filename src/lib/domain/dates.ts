/**
 * Turning spoken time into a timestamp.
 *
 * People do not say "2026-10-02" into a voice memo. They say "Friday", "end of
 * next week", "in a couple of days". The extraction model is asked for an ISO
 * date, but it frequently returns the phrase it heard instead, or invents a
 * date in the wrong year — so every date coming out of a model is funnelled
 * through here.
 *
 * Pure, with `now` always injected, so behaviour on a Sunday or across a
 * year boundary is a test rather than a hope.
 */

const MS_PER_DAY = 86_400_000;

const WEEKDAYS: Record<string, number> = {
  sunday: 0,
  sun: 0,
  monday: 1,
  mon: 1,
  tuesday: 2,
  tue: 2,
  tues: 2,
  wednesday: 3,
  wed: 3,
  thursday: 4,
  thu: 4,
  thurs: 4,
  friday: 5,
  fri: 5,
  saturday: 6,
  sat: 6,
};

const NUMBER_WORDS: Record<string, number> = {
  a: 1,
  an: 1,
  one: 1,
  a_couple: 2,
  couple: 2,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  nine: 9,
  ten: 10,
  few: 3,
};

/** Set a date to 09:00 local, the default hour for a business commitment. */
function atBusinessMorning(date: Date): Date {
  const result = new Date(date);
  result.setHours(9, 0, 0, 0);
  return result;
}

/** Set a date to 17:00 local, used for "by end of day" style phrasing. */
function atBusinessClose(date: Date): Date {
  const result = new Date(date);
  result.setHours(17, 0, 0, 0);
  return result;
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * MS_PER_DAY);
}

/**
 * Next occurrence of a weekday.
 *
 * "Friday" said on a Friday means next Friday, not today — if someone had meant
 * today they would have said "today". Treating it as today produces a deadline
 * that is already expiring, which is the more damaging error.
 */
function nextWeekday(now: Date, target: number, forceNextWeek = false): Date {
  const current = now.getDay();
  let delta = (target - current + 7) % 7;
  if (delta === 0) delta = 7;
  if (forceNextWeek && delta <= current) delta += 7;
  return atBusinessMorning(addDays(now, delta));
}

export interface ResolvedDate {
  date: Date;
  /** How the value was arrived at, so the UI can hedge when it guessed. */
  precision: 'exact' | 'day' | 'approximate';
  /** The input that produced this, echoed for display. */
  matched: string;
}

/**
 * Resolve an ISO date or a natural-language phrase into a timestamp.
 * Returns null when nothing time-like is present.
 */
export function resolveDate(input: string | null | undefined, now: Date): ResolvedDate | null {
  if (!input) return null;

  const raw = input.trim();
  if (!raw) return null;

  // A full ISO timestamp is taken at face value.
  const isoDateTime = raw.match(/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/);
  if (isoDateTime) {
    const parsed = new Date(raw);
    if (!Number.isNaN(parsed.getTime())) {
      return { date: parsed, precision: 'exact', matched: raw };
    }
  }

  // A bare ISO date gets a business-morning time. The round-trip check rejects
  // impossible dates like 2026-13-45, which the Date constructor would silently
  // roll over into a valid but wrong day.
  const isoDate = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (isoDate) {
    const [, year, month, day] = isoDate;
    const y = Number(year);
    const m = Number(month);
    const d = Number(day);
    const parsed = new Date(y, m - 1, d, 9, 0, 0, 0);
    const rolledOver =
      parsed.getFullYear() !== y || parsed.getMonth() !== m - 1 || parsed.getDate() !== d;
    if (!Number.isNaN(parsed.getTime()) && !rolledOver) {
      return { date: parsed, precision: 'day', matched: raw };
    }
    // A well-formed but impossible date is a model error, not a phrase to
    // reinterpret, so stop here rather than falling through to the word rules.
    return null;
  }

  const text = raw.toLowerCase().replace(/[.,!?]/g, ' ').replace(/\s+/g, ' ').trim();

  if (/^(today|end of (the )?day|eod|tonight|this evening)$/.test(text)) {
    return { date: atBusinessClose(now), precision: 'day', matched: raw };
  }

  if (/^tomorrow( morning)?$/.test(text)) {
    return { date: atBusinessMorning(addDays(now, 1)), precision: 'day', matched: raw };
  }

  if (text === 'tomorrow afternoon' || text === 'tomorrow evening') {
    return { date: atBusinessClose(addDays(now, 1)), precision: 'day', matched: raw };
  }

  if (/^day after tomorrow$/.test(text)) {
    return { date: atBusinessMorning(addDays(now, 2)), precision: 'day', matched: raw };
  }

  // "in three days", "in a couple of weeks", "in 2 months"
  const inUnits = text.match(
    /^in (?:about |around |roughly )?(\d+|a couple of|a few|a|an|one|two|three|four|five|six|seven|eight|nine|ten|few|couple)\s*(day|week|month)s?$/,
  );
  if (inUnits) {
    const [, quantityRaw, unit] = inUnits;
    const quantity = parseQuantity(quantityRaw ?? '');
    if (quantity !== null && unit) {
      const days = unit === 'day' ? quantity : unit === 'week' ? quantity * 7 : quantity * 30;
      const approximate = /about|around|roughly|a couple|a few|few|couple/.test(text);
      return {
        date: atBusinessMorning(addDays(now, days)),
        precision: approximate ? 'approximate' : 'day',
        matched: raw,
      };
    }
  }

  // "next week" / "end of next week" / "this week"
  if (/^end of (the )?week$/.test(text)) {
    return { date: atBusinessClose(nextWeekday(now, 5)), precision: 'day', matched: raw };
  }
  if (/^end of next week$/.test(text)) {
    return { date: atBusinessClose(addDays(nextWeekday(now, 5), 7)), precision: 'day', matched: raw };
  }
  if (/^next week$/.test(text)) {
    return { date: atBusinessMorning(nextWeekday(now, 1)), precision: 'approximate', matched: raw };
  }
  if (/^this week$/.test(text)) {
    return { date: atBusinessClose(nextWeekday(now, 5)), precision: 'approximate', matched: raw };
  }
  if (/^next month$/.test(text)) {
    const next = new Date(now);
    next.setMonth(next.getMonth() + 1, 1);
    return { date: atBusinessMorning(next), precision: 'approximate', matched: raw };
  }

  // "next Friday", "on Tuesday", "Friday"
  const weekdayMatch = text.match(
    /^(?:(next|this|on|by)\s+)?(sunday|sun|monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sat)$/,
  );
  if (weekdayMatch) {
    const [, qualifier, dayName] = weekdayMatch;
    const target = WEEKDAYS[dayName ?? ''];
    if (target !== undefined) {
      const forceNext = qualifier === 'next';
      return {
        date: nextWeekday(now, target, forceNext),
        precision: 'day',
        matched: raw,
      };
    }
  }

  return null;
}

function parseQuantity(token: string): number | null {
  const trimmed = token.trim();
  if (/^\d+$/.test(trimmed)) return Number(trimmed);
  const key = trimmed.replace(/^a couple of$/, 'couple').replace(/^a few$/, 'few');
  return NUMBER_WORDS[key] ?? null;
}

/**
 * Sanity-check a date a model produced.
 *
 * Extraction models reliably get the year wrong when the transcript only says
 * "October 30th" — they default to a year from training data. A follow-up
 * deadline more than 18 months out, or in the past, is almost always that bug
 * rather than a genuine long-dated commitment.
 */
export function isPlausibleDeadline(date: Date, now: Date): boolean {
  const days = (date.getTime() - now.getTime()) / MS_PER_DAY;
  return days >= -365 && days <= 548;
}

/**
 * Nudge a model-produced date into the nearest sensible year.
 *
 * "October 30" heard in September 2026 but returned as 2024-10-30 becomes
 * 2026-10-30 rather than being discarded, because the month and day were right.
 *
 * Future years are preferred over past ones. A commitment extracted from a call
 * that just happened is almost never backdated, so "February 14" in September
 * means next February, not the one seven months gone.
 */
export function repairYear(date: Date, now: Date): Date {
  const alreadyFuture = date.getTime() >= now.getTime();
  if (alreadyFuture && isPlausibleDeadline(date, now)) return date;

  const candidates = [now.getFullYear(), now.getFullYear() + 1].map((year) => {
    const candidate = new Date(date);
    candidate.setFullYear(year);
    return candidate;
  });

  const future = candidates.find(
    (candidate) => candidate.getTime() >= now.getTime() && isPlausibleDeadline(candidate, now),
  );
  if (future) return future;

  // Nothing ahead of us fits, so accept a recently-passed reading if one does.
  const plausible = candidates.find((candidate) => isPlausibleDeadline(candidate, now));
  return plausible ?? date;
}
