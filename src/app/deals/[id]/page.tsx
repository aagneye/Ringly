import Link from 'next/link';
import { notFound } from 'next/navigation';
import { PrecallBrief } from '@/components/precall-brief';
import { DraftCard } from '@/components/draft-review';
import { DealTimeline } from '@/components/deal-timeline';
import { loadDealDetail } from '@/lib/repo/queries';
import { getEnv } from '@/lib/env';
import { formatAgo, formatLongDate, titleCase } from '@/lib/format';

/** One deal: the brief, the record, the drafts and the full history. */
export const dynamic = 'force-dynamic';

export default async function DealPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ brief?: string }>;
}) {
  const { id } = await params;
  const { brief } = await searchParams;
  const env = getEnv();
  const now = new Date();

  const detail = await loadDealDetail(id, now);
  if (!detail) notFound();

  const { deal, health, signals, notes, drafts, reminders, events, actions, facts } = detail;
  const pendingDrafts = drafts.filter((draft) => draft.status === 'draft');

  return (
    <div className="flex flex-col gap-4">
      <div>
        <Link href="/pipeline" className="text-xs text-ink-400 underline hover:text-ink-200">
          ← Pipeline
        </Link>

        <div className="mt-2 flex flex-wrap items-baseline justify-between gap-2">
          <h1 className="text-xl font-semibold tracking-tight">{deal.contactName}</h1>
          <span className="rounded-full bg-ink-800 px-2.5 py-1 text-xs text-ink-300">
            {titleCase(deal.stage)}
          </span>
        </div>

        <p className="mt-0.5 text-sm text-ink-400">
          {deal.company ?? 'No company on file'}
          {deal.role ? ` · ${deal.role}` : ''}
          {deal.lastContactAt
            ? ` · spoke ${formatAgo(deal.lastContactAt, now, env.RINGLY_TIMEZONE)}`
            : ' · never spoken'}
        </p>
      </div>

      <PrecallBrief dealId={id} autoLoad={brief === '1'} />

      {signals.length > 0 && (
        <section className="rounded-(--radius-card) border border-warn-500/30 bg-warn-500/5 p-4">
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-warn-500">
            Needs attention · health {health}
          </h2>
          <ul className="flex flex-col gap-1">
            {signals.map((signal, index) => (
              <li key={index} className="text-sm text-ink-200">
                {signal.explanation}
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="grid gap-3 rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4 sm:grid-cols-2">
        <Field label="Next action" value={deal.nextAction} />
        <Field
          label="Deadline"
          value={deal.deadline ? formatLongDate(deal.deadline, env.RINGLY_TIMEZONE) : null}
        />
        <Field label="Budget" value={deal.budget} />
        <Field label="Sentiment" value={deal.sentiment ? titleCase(deal.sentiment) : null} />
        {deal.concerns && (
          <div className="sm:col-span-2">
            <Field label="Concerns" value={deal.concerns} />
          </div>
        )}
      </section>

      {facts.length > 0 && (
        <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-4">
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-ink-400">
            About {deal.company}
          </h2>
          <ul className="flex flex-col gap-2">
            {facts.map((fact) => (
              <li key={fact.id} className="text-sm text-ink-200">
                {fact.fact}
                <a
                  href={fact.sourceUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="ml-1.5 text-xs text-accent-400 underline"
                >
                  source
                </a>
              </li>
            ))}
          </ul>
        </section>
      )}

      {pendingDrafts.length > 0 && (
        <section className="rounded-(--radius-card) border border-warn-500/30 bg-ink-900 p-4">
          <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-warn-500">
            Waiting for you
          </h2>
          <ul className="flex flex-col gap-3">
            {pendingDrafts.map((draft) => (
              <DraftCard
                key={draft.id}
                draft={{
                  id: draft.id,
                  subject: draft.subject,
                  body: draft.body,
                  reasoning: draft.reasoning,
                  createdAt: draft.createdAt.toISOString(),
                  dealId: deal.id,
                  dealTitle: deal.title,
                  contactName: deal.contactName,
                  contactEmail: deal.email,
                }}
              />
            ))}
          </ul>
        </section>
      )}

      <DealTimeline
        notes={notes.map((note) => ({
          id: note.id,
          rawTranscript: note.rawTranscript,
          gist: note.gist,
          createdAt: note.createdAt.toISOString(),
          durationSeconds: note.durationSeconds,
          source: note.source,
        }))}
        actions={actions.map((action) => ({
          id: action.id,
          tool: action.tool,
          summary: action.summary,
          status: action.status,
          source: action.source,
          createdAt: action.createdAt.toISOString(),
        }))}
        reminders={reminders.map((reminder) => ({
          id: reminder.id,
          message: reminder.message,
          dueAt: reminder.dueAt.toISOString(),
          status: reminder.status,
          createdBy: reminder.createdBy,
        }))}
        events={events.map((event) => ({
          id: event.id,
          title: event.title,
          startsAt: event.startsAt.toISOString(),
          location: event.location,
          createdBy: event.createdBy,
        }))}
        now={now.toISOString()}
        timezone={env.RINGLY_TIMEZONE}
      />
    </div>
  );
}

function Field({ label, value }: { label: string; value: string | null }) {
  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-ink-400">{label}</p>
      <p className="mt-0.5 text-sm text-ink-100">{value ?? <span className="text-ink-600">—</span>}</p>
    </div>
  );
}
