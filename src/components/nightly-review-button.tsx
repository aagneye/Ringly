'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import type { ReviewResult } from '@/lib/agent/review';

/**
 * Running the nightly review by hand.
 *
 * In production a scheduler calls this at 2am. The button exists because a demo
 * cannot wait until 2am, and because watching the agent decide unprompted is the
 * most convincing thirty seconds of the product. It is honest about what it is —
 * the same code the scheduler runs.
 */
export function NightlyReviewButton() {
  const router = useRouter();
  const [result, setResult] = useState<ReviewResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const response = await fetch('/api/review', { method: 'POST' });
      const body = (await response.json()) as ReviewResult & { error?: string; hint?: string };
      if (!response.ok) {
        throw new Error([body.error, body.hint].filter(Boolean).join(' '));
      }
      setResult(body);
      router.refresh();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not run the review.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col items-start gap-2">
      <button
        type="button"
        onClick={() => void run()}
        disabled={busy}
        className="rounded-full border border-accent-500/50 bg-accent-500/10 px-4 py-2 text-xs font-medium text-accent-300 transition-colors hover:bg-accent-500/20 disabled:opacity-40"
      >
        {busy ? 'Reviewing the pipeline…' : 'Run the nightly review now'}
      </button>

      {error && (
        <p role="alert" className="max-w-sm text-xs text-danger-500">
          {error}
        </p>
      )}

      {result && (
        <div className="max-w-md rounded-lg border border-ink-800 bg-ink-900 p-3">
          <p className="text-xs text-ink-400">
            Considered {result.candidatesConsidered}{' '}
            {result.candidatesConsidered === 1 ? 'deal' : 'deals'} on Nemotron Ultra.
          </p>

          {result.actions.length > 0 ? (
            <ul className="mt-2 flex flex-col gap-1">
              {result.actions.map((action, index) => (
                <li key={index} className="text-sm text-ink-200">
                  {action.summary}
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-2 text-sm text-ink-300">
              {result.noActionReason ?? 'Nothing warranted action.'}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
