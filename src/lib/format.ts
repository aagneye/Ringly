/**
 * Display formatting, centralised.
 *
 * Every timestamp reaching a user or a prompt passes through here, so the
 * configured timezone is honoured in one place rather than being forgotten in
 * one component out of twelve. An invalid IANA zone in config degrades to a
 * readable string instead of throwing inside a render.
 */

/** YYYY-MM-DD in the given zone, used as the briefing cache key. */
export function formatDateKey(date: Date, timeZone: string): string {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      timeZone,
    }).format(date);
    return parts;
  } catch {
    return date.toISOString().slice(0, 10);
  }
}

/** "14:30" */
export function formatClock(date: Date, timeZone: string): string {
  try {
    return new Intl.DateTimeFormat('en-GB', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
      timeZone,
    }).format(date);
  } catch {
    return date.toISOString().slice(11, 16);
  }
}

/** "Wednesday 23 September" */
export function formatLongDate(date: Date, timeZone: string): string {
  try {
    return new Intl.DateTimeFormat('en-GB', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      timeZone,
    }).format(date);
  } catch {
    return date.toDateString();
  }
}

/**
 * "today", "yesterday", "tomorrow", or a long date.
 *
 * Relative wording is what makes a briefing sound spoken rather than printed,
 * but only within a couple of days — "in 34 days" is less useful than the date.
 */
export function formatRelativeDay(date: Date, now: Date, timeZone: string): string {
  const dayDelta = calendarDayDelta(date, now, timeZone);

  if (dayDelta === 0) return 'today';
  if (dayDelta === 1) return 'tomorrow';
  if (dayDelta === -1) return 'yesterday';
  if (dayDelta > 1 && dayDelta <= 6) {
    try {
      return new Intl.DateTimeFormat('en-GB', { weekday: 'long', timeZone }).format(date);
    } catch {
      return formatLongDate(date, timeZone);
    }
  }
  if (dayDelta < -1 && dayDelta >= -6) return `${Math.abs(dayDelta)} days ago`;

  return formatLongDate(date, timeZone);
}

/** Whole calendar days between two instants, in the given zone. */
export function calendarDayDelta(date: Date, now: Date, timeZone: string): number {
  const a = formatDateKey(date, timeZone);
  const b = formatDateKey(now, timeZone);
  const dateMs = Date.parse(`${a}T00:00:00Z`);
  const nowMs = Date.parse(`${b}T00:00:00Z`);
  if (Number.isNaN(dateMs) || Number.isNaN(nowMs)) return 0;
  return Math.round((dateMs - nowMs) / 86_400_000);
}

/** "9 days ago", "in 3 days", "today" — for the ear, not a table. */
export function formatAgo(date: Date, now: Date, timeZone: string): string {
  const delta = calendarDayDelta(date, now, timeZone);
  if (delta === 0) return 'today';
  if (delta === 1) return 'tomorrow';
  if (delta === -1) return 'yesterday';
  if (delta > 0) return `in ${delta} days`;
  return `${Math.abs(delta)} days ago`;
}

/** "1m 23s" or "45s", for a recording length. */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return '0s';
  const whole = Math.round(seconds);
  if (whole < 60) return `${whole}s`;
  const minutes = Math.floor(whole / 60);
  const remainder = whole % 60;
  return remainder === 0 ? `${minutes}m` : `${minutes}m ${remainder}s`;
}

/** Trim to a length on a word boundary, adding an ellipsis. */
export function truncateWords(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  const cut = text.slice(0, maxChars);
  const lastSpace = cut.lastIndexOf(' ');
  return `${lastSpace > maxChars * 0.6 ? cut.slice(0, lastSpace) : cut}…`;
}

/** Sentence-case a machine token: "proposal" stays, "won" becomes "Won". */
export function titleCase(text: string): string {
  if (!text) return text;
  return text.charAt(0).toUpperCase() + text.slice(1);
}
