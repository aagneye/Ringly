'use client';

import { useState } from 'react';
import { formatAgo, formatDuration, formatLongDate } from '@/lib/format';

/**
 * The full history of one deal, in one list.
 *
 * Agent actions and manual edits are interleaved rather than separated into "what
 * Ringly did" and "what you did". A single chronology is the only honest way to
 * present a shared record — and it is how the user actually thinks about it:
 * things happened, in an order.
 */

interface TimelineNote {
  id: string;
  rawTranscript: string;
  gist: string | null;
  createdAt: string;
  durationSeconds: number | null;
  source: string;
}

interface TimelineAction {
  id: string;
  tool: string;
  summary: string;
  status: string;
  source: string;
  createdAt: string;
}

interface TimelineReminder {
  id: string;
  message: string;
  dueAt: string;
  status: string;
  createdBy: string;
}

interface TimelineEvent {
  id: string;
  title: string;
  startsAt: string;
  location: string | null;
  createdBy: string;
}

interface DealTimelineProps {
  notes: TimelineNote[];
  actions: TimelineAction[];
  reminders: TimelineReminder[];
  events: TimelineEvent[];
  now: string;
  timezone: string;
}

type Tab = 'history' | 'notes' | 'reminders' | 'calendar';

export function DealTimeline({
  notes,
  actions,
  reminders,
  events,
  now,
  timezone,
}: DealTimelineProps) {
  const [tab, setTab] = useState<Tab>('history');
  const nowDate = new Date(now);

  const tabs: { key: Tab; label: string; count: number }[] = [
    { key: 'history', label: 'History', count: actions.length },
    { key: 'notes', label: 'Notes', count: notes.length },
    { key: 'reminders', label: 'Reminders', count: reminders.length },
    { key: 'calendar', label: 'Calendar', count: events.length },
  ];

  return (
    <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4">
      <div role="tablist" aria-label="Deal history" className="mb-4 flex flex-wrap gap-1">
        {tabs.map((entry) => (
          <button
            key={entry.key}
            role="tab"
            type="button"
            aria-selected={tab === entry.key}
            onClick={() => setTab(entry.key)}
            className={`rounded-full px-3 py-1.5 text-xs transition-colors ${
              tab === entry.key
                ? 'bg-ink-700 text-ink-50'
                : 'text-ink-400 hover:bg-ink-850 hover:text-ink-200'
            }`}
          >
            {entry.label}
            {entry.count > 0 && <span className="ml-1.5 text-ink-500">{entry.count}</span>}
          </button>
        ))}
      </div>

      {tab === 'history' && (
        <TimelineList
          items={actions}
          empty="Nothing has happened on this deal yet."
          render={(action) => (
            <li key={action.id} className="border-l-2 border-ink-800 pl-3">
              <p className="text-sm text-ink-100">{action.summary}</p>
              <p className="mt-0.5 text-xs text-ink-400">
                {formatAgo(new Date(action.createdAt), nowDate, timezone)}
                {' · '}
                {sourceLabel(action.source)}
                {action.status === 'failed' && (
                  <span className="ml-1.5 text-danger-500">failed</span>
                )}
                {action.status === 'awaiting_approval' && (
                  <span className="ml-1.5 text-warn-500">awaiting you</span>
                )}
              </p>
            </li>
          )}
        />
      )}

      {tab === 'notes' && (
        <TimelineList
          items={notes}
          empty="No calls recorded yet."
          render={(note) => (
            <li key={note.id} className="rounded-lg border border-ink-800 bg-ink-850 p-3">
              <div className="flex items-baseline justify-between gap-2">
                <p className="text-xs text-ink-400">
                  {formatAgo(new Date(note.createdAt), nowDate, timezone)}
                  {' · '}
                  {note.source === 'voice' ? 'voice' : 'typed'}
                  {note.durationSeconds ? ` · ${formatDuration(note.durationSeconds)}` : ''}
                </p>
              </div>
              {note.gist && <p className="mt-1 text-sm text-ink-100">{note.gist}</p>}
              <details className="mt-1.5">
                <summary className="cursor-pointer text-xs text-ink-400 hover:text-ink-200">
                  Full transcript
                </summary>
                <p className="mt-1.5 text-sm leading-relaxed text-ink-300">{note.rawTranscript}</p>
              </details>
            </li>
          )}
        />
      )}

      {tab === 'reminders' && (
        <TimelineList
          items={reminders}
          empty="No reminders on this deal."
          render={(reminder) => (
            <li
              key={reminder.id}
              className="flex items-start justify-between gap-3 border-l-2 border-ink-800 pl-3"
            >
              <div className="min-w-0">
                <p
                  className={`text-sm ${
                    reminder.status === 'done' ? 'text-ink-500 line-through' : 'text-ink-100'
                  }`}
                >
                  {reminder.message}
                </p>
                <p className="mt-0.5 text-xs text-ink-400">
                  due {formatAgo(new Date(reminder.dueAt), nowDate, timezone)}
                  {reminder.createdBy === 'nightly_review' && (
                    <span className="ml-1.5 text-accent-400">Ringly noticed this</span>
                  )}
                </p>
              </div>
              <span className="shrink-0 text-xs text-ink-500">{reminder.status}</span>
            </li>
          )}
        />
      )}

      {tab === 'calendar' && (
        <TimelineList
          items={events}
          empty="Nothing scheduled."
          render={(event) => (
            <li key={event.id} className="border-l-2 border-ink-800 pl-3">
              <div className="flex items-baseline justify-between gap-2">
                <p className="text-sm text-ink-100">{event.title}</p>
                <a
                  href={`/api/events/${event.id}/ics`}
                  className="shrink-0 text-xs text-accent-400 underline"
                >
                  Add to calendar
                </a>
              </div>
              <p className="mt-0.5 text-xs text-ink-400">
                {formatLongDate(new Date(event.startsAt), timezone)}
                {event.location ? ` · ${event.location}` : ''}
                {event.createdBy === 'memo' && (
                  <span className="ml-1.5 text-accent-400">scheduled from a memo</span>
                )}
              </p>
            </li>
          )}
        />
      )}
    </section>
  );
}

function TimelineList<T>({
  items,
  empty,
  render,
}: {
  items: T[];
  empty: string;
  render: (item: T) => React.ReactNode;
}) {
  if (items.length === 0) {
    return <p className="text-sm text-ink-600">{empty}</p>;
  }
  return <ul className="flex flex-col gap-3">{items.map(render)}</ul>;
}

function sourceLabel(source: string): string {
  switch (source) {
    case 'memo':
      return 'from your memo';
    case 'nightly_review':
      return 'Ringly, overnight';
    case 'manual':
      return 'you';
    case 'question':
      return 'from a question';
    default:
      return source;
  }
}
