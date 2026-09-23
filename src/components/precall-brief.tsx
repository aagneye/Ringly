'use client';

import { useCallback, useEffect, useState } from 'react';
import type { PrecallResult } from '@/lib/agent/precall';

/**
 * The brief you read walking into a call.
 *
 * "You promised" is first and visually loudest, because a forgotten promise is
 * the single worst way to start a client call and everything else on this screen
 * is context by comparison. An unfulfilled promise is marked in red — that is the
 * one thing worth interrupting someone over.
 */

interface PrecallBriefProps {
  dealId: string;
  /** Fetch on mount, used when arriving from a "brief me now" link. */
  autoLoad?: boolean;
}

export function PrecallBrief({ dealId, autoLoad = false }: PrecallBriefProps) {
  const [brief, setBrief] = useState<PrecallResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`/api/deals/${dealId}/brief`);
      const body = (await response.json()) as PrecallResult & { error?: string };
      if (!response.ok) throw new Error(body.error ?? `Request failed (${response.status})`);
      setBrief(body);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not build the brief.');
    } finally {
      setLoading(false);
    }
  }, [dealId]);

  useEffect(() => {
    // Fetching on mount is exactly what this effect is for — synchronising
    // with the server, an external system. The rule flags load()'s first line
    // (setLoading(true)) as a synchronous setState inside an effect, but
    // there is no network call that can avoid starting in that state.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (autoLoad) void load();
  }, [autoLoad, load]);

  if (!brief && !loading && !error) {
    return (
      <button
        type="button"
        onClick={() => void load()}
        className="w-full rounded-(--radius-card) border border-dashed border-accent-500/40 bg-accent-500/5 p-4 text-left transition-colors hover:bg-accent-500/10"
      >
        <p className="text-sm font-medium text-accent-300">Brief me before this call</p>
        <p className="mt-0.5 text-xs text-ink-400">
          What they care about, what you promised, and what to ask.
        </p>
      </button>
    );
  }

  if (loading) {
    return (
      <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-5">
        <p className="mb-3 text-xs uppercase tracking-wide text-ink-400">Building your brief…</p>
        {[0, 1, 2].map((row) => (
          <div key={row} className="ringly-shimmer mb-2 h-3 w-full rounded" />
        ))}
      </section>
    );
  }

  if (error) {
    return (
      <section className="rounded-(--radius-card) border border-danger-500/30 bg-ink-900 p-4">
        <p className="text-sm text-danger-500">{error}</p>
        <button
          type="button"
          onClick={() => void load()}
          className="mt-2 rounded-full border border-ink-700 px-3 py-1 text-xs text-ink-200 hover:bg-ink-800"
        >
          Try again
        </button>
      </section>
    );
  }

  if (!brief) return null;

  const unfulfilled = brief.you_promised.filter((promise) => !promise.appears_done);

  return (
    <section
      aria-label="Pre-call brief"
      className="rounded-(--radius-card) border border-accent-500/30 bg-ink-900 p-5"
    >
      <div className="mb-4 flex items-baseline justify-between gap-2">
        <h2 className="text-[15px] font-semibold">
          Before you call {brief.contactName.split(' ')[0]}
        </h2>
        <button
          type="button"
          onClick={() => void load()}
          className="shrink-0 text-xs text-ink-400 underline hover:text-ink-200"
        >
          Refresh
        </button>
      </div>

      {brief.firstConversation && (
        <p className="mb-4 rounded-lg bg-ink-850 p-3 text-sm text-ink-300">
          This is your first recorded conversation with them, so there is no history to draw on yet.
        </p>
      )}

      {brief.you_promised.length > 0 && (
        <div className="mb-4">
          <h3 className="mb-2 text-xs font-medium uppercase tracking-wide text-ink-400">
            You promised
          </h3>
          <ul className="flex flex-col gap-1.5">
            {brief.you_promised.map((promise, index) => (
              <li
                key={index}
                className={`flex items-start gap-2 rounded-lg p-2.5 text-sm ${
                  promise.appears_done
                    ? 'bg-ink-850 text-ink-300'
                    : 'bg-danger-500/10 text-ink-100'
                }`}
              >
                <span
                  aria-hidden
                  className={`mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full ${
                    promise.appears_done ? 'bg-good-500' : 'bg-danger-500'
                  }`}
                />
                <span>
                  {promise.promise}
                  {!promise.appears_done && (
                    <span className="ml-1.5 text-xs text-danger-500">still open</span>
                  )}
                </span>
              </li>
            ))}
          </ul>
          {unfulfilled.length > 0 && (
            <p className="mt-2 text-xs text-danger-500">
              Lead with {unfulfilled.length === 1 ? 'this' : 'these'}.
            </p>
          )}
        </div>
      )}

      <div className="mb-4">
        <h3 className="mb-1.5 text-xs font-medium uppercase tracking-wide text-ink-400">
          Where we are
        </h3>
        <p className="text-sm leading-relaxed text-ink-200">{brief.where_we_are}</p>
      </div>

      {brief.they_care_about.length > 0 && (
        <div className="mb-4">
          <h3 className="mb-1.5 text-xs font-medium uppercase tracking-wide text-ink-400">
            They care about
          </h3>
          <ul className="flex flex-col gap-1">
            {brief.they_care_about.map((item, index) => (
              <li key={index} className="text-sm leading-relaxed text-ink-200">
                — {item}
              </li>
            ))}
          </ul>
        </div>
      )}

      {brief.ask_about.length > 0 && (
        <div>
          <h3 className="mb-1.5 text-xs font-medium uppercase tracking-wide text-ink-400">
            Worth asking
          </h3>
          <ul className="flex flex-col gap-1.5">
            {brief.ask_about.map((question, index) => (
              <li
                key={index}
                className="rounded-lg border border-ink-800 bg-ink-850 p-2.5 text-sm leading-relaxed text-ink-200"
              >
                {question}
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
