'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { formatClock, formatAgo } from '@/lib/format';

/**
 * The three lists that make up "today".
 *
 * Reminders created by the nightly review are labelled as such. That attribution
 * is not decoration: an item you do not remember creating is unsettling unless
 * something tells you where it came from, and "Ringly noticed this" turns a
 * mystery into a service.
 */

export interface TodayReminder {
  id: string;
  message: string;
  dueAt: string;
  createdBy: string;
  dealId: string;
  dealTitle: string;
  contactName: string;
}

export interface TodayEvent {
  id: string;
  title: string;
  startsAt: string;
  endsAt: string;
  location: string | null;
  dealId: string;
  contactName: string;
  company: string | null;
}

interface TodayPanelsProps {
  reminders: TodayReminder[];
  events: TodayEvent[];
  now: string;
  timezone: string;
}

export function TodayPanels({ reminders, events, now, timezone }: TodayPanelsProps) {
  const nowDate = new Date(now);

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <MeetingsPanel events={events} now={nowDate} timezone={timezone} />
      <RemindersPanel reminders={reminders} now={nowDate} timezone={timezone} />
    </div>
  );
}

function MeetingsPanel({
  events,
  now,
  timezone,
}: {
  events: TodayEvent[];
  now: Date;
  timezone: string;
}) {
  return (
    <section
      aria-label="Meetings today"
      className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4"
    >
      <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-ink-400">
        Today&apos;s calls
      </h2>

      {events.length === 0 ? (
        <p className="text-sm text-ink-600">No meetings scheduled.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {events.map((event) => {
            const start = new Date(event.startsAt);
            const soon = start.getTime() - now.getTime() < 60 * 60 * 1000 && start > now;

            return (
              <li
                key={event.id}
                className={`rounded-lg border p-3 ${
                  soon ? 'border-accent-500/40 bg-accent-500/5' : 'border-ink-800 bg-ink-850'
                }`}
              >
                <div className="flex items-baseline justify-between gap-2">
                  <p className="min-w-0 truncate text-sm font-medium text-ink-50">{event.title}</p>
                  <span className="shrink-0 font-mono text-xs text-ink-300">
                    {formatClock(start, timezone)}
                  </span>
                </div>
                <p className="mt-0.5 truncate text-xs text-ink-400">
                  {event.contactName}
                  {event.company ? ` · ${event.company}` : ''}
                </p>
                <Link
                  href={`/deals/${event.dealId}?brief=1`}
                  className="mt-1.5 inline-block text-xs text-accent-400 underline"
                >
                  {soon ? 'Brief me now' : 'Pre-call brief'}
                </Link>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

function RemindersPanel({
  reminders,
  now,
  timezone,
}: {
  reminders: TodayReminder[];
  now: Date;
  timezone: string;
}) {
  const router = useRouter();
  const [resolving, setResolving] = useState<string | null>(null);
  const [hidden, setHidden] = useState<Set<string>>(new Set());

  async function complete(id: string) {
    setResolving(id);
    try {
      const response = await fetch(`/api/reminders/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'done' }),
      });
      if (response.ok) {
        setHidden((current) => new Set(current).add(id));
        router.refresh();
      }
    } finally {
      setResolving(null);
    }
  }

  const visible = reminders.filter((reminder) => !hidden.has(reminder.id));

  return (
    <section
      aria-label="Reminders due"
      className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4"
    >
      <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-ink-400">Due</h2>

      {visible.length === 0 ? (
        <p className="text-sm text-ink-600">Nothing due.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {visible.map((reminder) => {
            const due = new Date(reminder.dueAt);
            const overdue = due.getTime() < now.getTime();

            return (
              <li
                key={reminder.id}
                className="flex items-start gap-2.5 rounded-lg border border-ink-800 bg-ink-850 p-3"
              >
                <button
                  type="button"
                  onClick={() => void complete(reminder.id)}
                  disabled={resolving === reminder.id}
                  aria-label={`Mark "${reminder.message}" as done`}
                  className="mt-0.5 grid h-4 w-4 shrink-0 place-items-center rounded border border-ink-600 hover:border-good-500 disabled:opacity-40"
                />

                <div className="min-w-0 flex-1">
                  <p className="text-sm leading-snug text-ink-100">{reminder.message}</p>
                  <p className="mt-0.5 text-xs text-ink-400">
                    <span className={overdue ? 'text-danger-500' : ''}>
                      {formatAgo(due, now, timezone)}
                    </span>
                    {' · '}
                    <Link href={`/deals/${reminder.dealId}`} className="underline">
                      {reminder.contactName}
                    </Link>
                    {reminder.createdBy === 'nightly_review' && (
                      <span className="ml-1.5 text-accent-400">Ringly noticed this</span>
                    )}
                  </p>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
