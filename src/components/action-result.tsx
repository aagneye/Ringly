'use client';

import Link from 'next/link';
import type { ExecutedAction } from '@/lib/agent/runner';
import { humanise } from '@/lib/agent/runner';

/**
 * The payoff screen: "here is what I just did".
 *
 * It renders the audit records, not a model-written summary, so it is
 * structurally incapable of claiming something that did not happen. Failures are
 * shown rather than hidden — an agent that quietly drops a third of its work is
 * worse than one that says "I could not read that date".
 */

interface ActionResultProps {
  transcript: string;
  actions: ExecutedAction[];
  awaitingApproval: ExecutedAction[];
  failed: ExecutedAction[];
  noActionReason: string | null;
  contactName: string;
  dealId: string;
  createdContact: boolean;
  onDismiss: () => void;
}

export function ActionResult({
  transcript,
  actions,
  awaitingApproval,
  failed,
  noActionReason,
  contactName,
  dealId,
  createdContact,
  onDismiss,
}: ActionResultProps) {
  const applied = actions.filter((action) => action.status === 'applied');

  return (
    <section
      aria-label="What Ringly did"
      className="rounded-(--radius-card) border border-accent-500/30 bg-ink-900 p-5"
    >
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <h2 className="text-[15px] font-semibold">
            {applied.length === 0 && awaitingApproval.length === 0
              ? 'Logged it'
              : `Done — ${applied.length + awaitingApproval.length} ${
                  applied.length + awaitingApproval.length === 1 ? 'thing' : 'things'
                }`}
          </h2>
          <p className="mt-0.5 text-sm text-ink-400">
            {createdContact ? `New contact: ${contactName}` : contactName}
            {' · '}
            <Link href={`/deals/${dealId}`} className="text-accent-400 underline">
              open the deal
            </Link>
          </p>
        </div>
        <button
          type="button"
          onClick={onDismiss}
          aria-label="Dismiss"
          className="rounded-full p-1 text-ink-400 hover:bg-ink-800 hover:text-ink-200"
        >
          <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden>
            <path
              d="M4 4l8 8M12 4l-8 8"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
            />
          </svg>
        </button>
      </div>

      {applied.length > 0 && (
        <ul className="mb-4 flex flex-col gap-2">
          {applied.map((action, index) => (
            <li key={`${action.tool}-${index}`} className="flex items-start gap-2.5 text-sm">
              <CheckIcon />
              <span className="text-ink-200">{action.summary}</span>
            </li>
          ))}
        </ul>
      )}

      {awaitingApproval.length > 0 && (
        <div className="mb-4 rounded-lg border border-warn-500/30 bg-warn-500/5 p-3">
          <p className="mb-2 text-xs font-medium uppercase tracking-wide text-warn-500">
            Waiting for you
          </p>
          <ul className="flex flex-col gap-2">
            {awaitingApproval.map((action, index) => (
              <li key={`${action.tool}-${index}`} className="text-sm text-ink-200">
                {action.summary}
              </li>
            ))}
          </ul>
          <Link
            href={`/deals/${dealId}`}
            className="mt-2 inline-block text-xs text-accent-400 underline"
          >
            Review it
          </Link>
        </div>
      )}

      {failed.length > 0 && (
        <div className="mb-4 rounded-lg border border-danger-500/30 bg-danger-500/5 p-3">
          <p className="mb-2 text-xs font-medium uppercase tracking-wide text-danger-500">
            Could not do
          </p>
          <ul className="flex flex-col gap-1.5">
            {failed.map((action, index) => (
              <li key={`${action.tool}-${index}`} className="text-sm text-ink-300">
                {action.summary}
                {action.error && (
                  <span className="block text-xs text-ink-400">{action.error}</span>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}

      {noActionReason && (
        <p className="mb-4 text-sm text-ink-300">
          Nothing needed doing. {noActionReason}
        </p>
      )}

      <details className="group">
        <summary className="cursor-pointer text-xs text-ink-400 hover:text-ink-200">
          What Ringly heard
        </summary>
        <p className="mt-2 rounded-lg bg-ink-850 p-3 text-sm leading-relaxed text-ink-300">
          {transcript}
        </p>
      </details>
    </section>
  );
}

function CheckIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      className="mt-0.5 shrink-0 text-good-500"
      aria-hidden
    >
      <path
        d="M3 8.5l3.2 3.2L13 5"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** Small inline badge used elsewhere to name a tool. */
export function ToolBadge({ tool }: { tool: string }) {
  return (
    <span className="rounded bg-ink-800 px-1.5 py-0.5 font-mono text-[10px] text-ink-300">
      {humanise(tool)}
    </span>
  );
}
