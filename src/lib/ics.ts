/**
 * Exporting an event as an .ics file.
 *
 * The escape hatch for the deliberate decision not to integrate Google Calendar.
 * A downloadable .ics opens in whatever calendar the user already uses, needs no
 * OAuth consent screen, cannot break during a live demo, and works on a phone.
 * It is the 90% of the value for 2% of the risk.
 *
 * Pure string building, so the output format is testable without a filesystem.
 */

export interface IcsEvent {
  uid: string;
  title: string;
  startsAt: Date;
  endsAt: Date;
  description?: string | null;
  location?: string | null;
}

/**
 * Escape a value for an ics text field.
 *
 * RFC 5545 requires backslashes, semicolons, commas and newlines to be escaped.
 * Getting this wrong silently corrupts the rest of the file, because a raw comma
 * splits the property into a list.
 */
export function escapeIcsText(value: string): string {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n');
}

/** UTC timestamp in the basic format ics requires: 20260923T120000Z */
export function formatIcsTimestamp(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0');
  return (
    `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}` +
    `T${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}Z`
  );
}

/**
 * Fold a line to 75 octets, as the spec requires.
 *
 * Long descriptions from a memo routinely exceed it, and some calendar clients
 * reject an unfolded file outright rather than degrading.
 */
export function foldIcsLine(line: string): string {
  if (line.length <= 75) return line;

  const parts: string[] = [line.slice(0, 75)];
  let rest = line.slice(75);

  while (rest.length > 74) {
    parts.push(` ${rest.slice(0, 74)}`);
    rest = rest.slice(74);
  }
  if (rest.length > 0) parts.push(` ${rest}`);

  return parts.join('\r\n');
}

/** Build a complete single-event calendar file. */
export function buildIcs(event: IcsEvent, now = new Date()): string {
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Ringly//Ringly 0.1//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${event.uid}@ringly`,
    `DTSTAMP:${formatIcsTimestamp(now)}`,
    `DTSTART:${formatIcsTimestamp(event.startsAt)}`,
    `DTEND:${formatIcsTimestamp(event.endsAt)}`,
    `SUMMARY:${escapeIcsText(event.title)}`,
  ];

  if (event.description) {
    lines.push(`DESCRIPTION:${escapeIcsText(event.description)}`);
  }
  if (event.location) {
    lines.push(`LOCATION:${escapeIcsText(event.location)}`);
  }

  lines.push('END:VEVENT', 'END:VCALENDAR');

  // CRLF line endings are mandatory, not stylistic.
  return lines.map(foldIcsLine).join('\r\n');
}
