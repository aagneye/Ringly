'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';

/**
 * Reviewing an email the agent wrote.
 *
 * Editable before approval, because a draft the user cannot adjust is a draft
 * they will not trust. Approving opens their own mail client via a mailto link
 * rather than sending on their behalf: Ringly never holds mailbox credentials,
 * and the last look at an outgoing message stays with the human.
 */

export interface PendingDraft {
  id: string;
  subject: string;
  body: string;
  reasoning: string | null;
  createdAt: string;
  dealId: string;
  dealTitle: string;
  contactName: string;
  contactEmail: string | null;
}

interface DraftReviewProps {
  drafts: PendingDraft[];
}

export function DraftReview({ drafts }: DraftReviewProps) {
  if (drafts.length === 0) return null;

  return (
    <section
      aria-label="Drafts waiting for approval"
      className="rounded-(--radius-card) border border-warn-500/30 bg-ink-900 p-4"
    >
      <h2 className="mb-3 text-xs font-medium uppercase tracking-wide text-warn-500">
        {drafts.length} {drafts.length === 1 ? 'draft waiting' : 'drafts waiting'}
      </h2>

      <ul className="flex flex-col gap-3">
        {drafts.map((draft) => (
          <DraftCard key={draft.id} draft={draft} />
        ))}
      </ul>
    </section>
  );
}

export function DraftCard({ draft }: { draft: PendingDraft }) {
  const router = useRouter();
  const [subject, setSubject] = useState(draft.subject);
  const [body, setBody] = useState(draft.body);
  const [editing, setEditing] = useState(false);
  const [busy, setBusy] = useState(false);
  const [resolved, setResolved] = useState<'approved' | 'discarded' | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function resolve(action: 'approve' | 'discard') {
    setBusy(true);
    setError(null);
    try {
      const response = await fetch(`/api/drafts/${draft.id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, subject, body }),
      });
      if (!response.ok) {
        const payload = (await response.json().catch(() => ({}))) as { error?: string };
        throw new Error(payload.error ?? `Request failed (${response.status})`);
      }

      setResolved(action === 'approve' ? 'approved' : 'discarded');

      if (action === 'approve') {
        const to = draft.contactEmail ?? '';
        window.location.href = `mailto:${encodeURIComponent(to)}?subject=${encodeURIComponent(
          subject,
        )}&body=${encodeURIComponent(body)}`;
      }

      router.refresh();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not update that draft.');
    } finally {
      setBusy(false);
    }
  }

  if (resolved) {
    return (
      <li className="rounded-lg border border-ink-800 bg-ink-850 p-3 text-sm text-ink-400">
        {resolved === 'approved'
          ? `Opened in your mail app. ${draft.contactEmail ? '' : 'No email address on file — paste the address in.'}`
          : 'Discarded.'}
      </li>
    );
  }

  return (
    <li className="rounded-lg border border-ink-800 bg-ink-850 p-3">
      <div className="mb-2 flex items-baseline justify-between gap-2">
        <p className="min-w-0 truncate text-sm font-medium text-ink-50">
          To {draft.contactName}
        </p>
        <Link href={`/deals/${draft.dealId}`} className="shrink-0 text-xs text-accent-400 underline">
          {draft.dealTitle}
        </Link>
      </div>

      {draft.reasoning && (
        <p className="mb-2 text-xs italic text-ink-400">Why: {draft.reasoning}</p>
      )}

      {editing ? (
        <div className="flex flex-col gap-2">
          <label className="sr-only" htmlFor={`subject-${draft.id}`}>
            Subject
          </label>
          <input
            id={`subject-${draft.id}`}
            value={subject}
            onChange={(event) => setSubject(event.target.value)}
            className="rounded border border-ink-700 bg-ink-900 px-2.5 py-1.5 text-sm text-ink-50 focus:border-accent-500 focus:outline-none"
          />
          <label className="sr-only" htmlFor={`body-${draft.id}`}>
            Body
          </label>
          <textarea
            id={`body-${draft.id}`}
            value={body}
            onChange={(event) => setBody(event.target.value)}
            rows={7}
            className="resize-y rounded border border-ink-700 bg-ink-900 px-2.5 py-1.5 text-sm leading-relaxed text-ink-50 focus:border-accent-500 focus:outline-none"
          />
        </div>
      ) : (
        <>
          <p className="text-sm font-medium text-ink-100">{subject}</p>
          <p className="mt-1.5 whitespace-pre-wrap text-sm leading-relaxed text-ink-300">{body}</p>
        </>
      )}

      {error && (
        <p role="alert" className="mt-2 text-xs text-danger-500">
          {error}
        </p>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => void resolve('approve')}
          disabled={busy}
          className="rounded-full bg-accent-500 px-4 py-1.5 text-xs font-medium text-ink-950 disabled:opacity-40"
        >
          Approve and open
        </button>
        <button
          type="button"
          onClick={() => setEditing((current) => !current)}
          disabled={busy}
          className="rounded-full border border-ink-700 px-3 py-1.5 text-xs text-ink-200 hover:bg-ink-800 disabled:opacity-40"
        >
          {editing ? 'Done editing' : 'Edit'}
        </button>
        <button
          type="button"
          onClick={() => void resolve('discard')}
          disabled={busy}
          className="text-xs text-ink-400 underline hover:text-ink-200 disabled:opacity-40"
        >
          Discard
        </button>
      </div>
    </li>
  );
}
