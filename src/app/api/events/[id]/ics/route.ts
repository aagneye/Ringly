import { eq } from 'drizzle-orm';
import { getDb } from '@/lib/db';
import { events } from '@/lib/db/schema/events';
import { contacts } from '@/lib/db/schema/contacts';
import { deals } from '@/lib/db/schema/deals';
import { buildIcs } from '@/lib/ics';
import { handleApiError, jsonError } from '@/lib/api';

/**
 * Download one event as .ics.
 *
 * The bridge to whatever calendar the user actually keeps, without asking for
 * access to it.
 */
export const runtime = 'nodejs';

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;

    const [row] = await getDb()
      .select({
        id: events.id,
        title: events.title,
        startsAt: events.startsAt,
        endsAt: events.endsAt,
        location: events.location,
        notes: events.notes,
        contactName: contacts.name,
        company: contacts.company,
      })
      .from(events)
      .innerJoin(deals, eq(events.dealId, deals.id))
      .innerJoin(contacts, eq(deals.contactId, contacts.id))
      .where(eq(events.id, id))
      .limit(1);

    if (!row) return jsonError('That event does not exist.', 404, 'event_not_found');

    const description = [
      row.notes,
      `With ${row.contactName}${row.company ? ` at ${row.company}` : ''}.`,
      'Scheduled by Ringly.',
    ]
      .filter(Boolean)
      .join('\n');

    const ics = buildIcs({
      uid: row.id,
      title: row.title,
      startsAt: row.startsAt,
      endsAt: row.endsAt,
      location: row.location,
      description,
    });

    return new Response(ics, {
      headers: {
        'Content-Type': 'text/calendar; charset=utf-8',
        'Content-Disposition': `attachment; filename="ringly-${row.id}.ics"`,
      },
    });
  } catch (error) {
    return handleApiError(error);
  }
}
