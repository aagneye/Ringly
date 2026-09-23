'use client';

import { useState } from 'react';
import Link from 'next/link';
import { useSpeech } from './briefing-panel';

/**
 * "What's happening with Priya?"
 *
 * The answer is spoken automatically when it arrives, because the question is
 * usually asked while doing something else. Text is shown at the same time, so
 * nothing is lost if audio is unavailable or the user is somewhere quiet.
 *
 * When the model reports it lacked information, that is surfaced plainly rather
 * than styled as an error — "your notes do not mention her budget" is a correct
 * and useful answer, not a failure.
 */

interface AskResponse {
  answer: string;
  referencedDealIds: string[];
  insufficientInformation: boolean;
}

const SUGGESTIONS = [
  "What's my riskiest deal?",
  'Who have I not spoken to in a while?',
  'What did I promise this week?',
];

export function AskBox() {
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState<AskResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { speak, stop, speaking, supported } = useSpeech();

  async function submit(text: string) {
    const trimmed = text.trim();
    if (!trimmed || loading) return;

    setLoading(true);
    setError(null);
    setAnswer(null);
    stop();

    try {
      const response = await fetch('/api/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: trimmed }),
      });

      const body = (await response.json()) as AskResponse & { error?: string };
      if (!response.ok) throw new Error(body.error ?? `Request failed (${response.status})`);

      setAnswer(body);
      if (supported) speak(body.answer);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not answer that.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <section
      aria-label="Ask Ringly"
      className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-5"
    >
      <h2 className="text-[15px] font-semibold">Ask Ringly</h2>
      <p className="mt-0.5 text-sm text-ink-400">
        Anything from your notes. It answers from what was actually said.
      </p>

      <form
        onSubmit={(event) => {
          event.preventDefault();
          void submit(question);
        }}
        className="mt-3 flex gap-2"
      >
        <label htmlFor="ask-input" className="sr-only">
          Your question
        </label>
        <input
          id="ask-input"
          value={question}
          onChange={(event) => setQuestion(event.target.value)}
          placeholder="What's the status on Priya?"
          className="min-w-0 flex-1 rounded-full border border-ink-700 bg-ink-850 px-4 py-2 text-sm text-ink-50 placeholder:text-ink-600 focus:border-accent-500 focus:outline-none"
        />
        <button
          type="submit"
          disabled={loading || question.trim().length === 0}
          className="shrink-0 rounded-full bg-accent-500 px-4 py-2 text-sm font-medium text-ink-950 disabled:opacity-40"
        >
          {loading ? '…' : 'Ask'}
        </button>
      </form>

      {!answer && !loading && (
        <ul className="mt-3 flex flex-wrap gap-2">
          {SUGGESTIONS.map((suggestion) => (
            <li key={suggestion}>
              <button
                type="button"
                onClick={() => {
                  setQuestion(suggestion);
                  void submit(suggestion);
                }}
                className="rounded-full border border-ink-700 px-3 py-1 text-xs text-ink-400 hover:border-ink-600 hover:text-ink-200"
              >
                {suggestion}
              </button>
            </li>
          ))}
        </ul>
      )}

      {loading && (
        <div className="mt-4">
          <div className="ringly-shimmer h-3 w-full rounded" />
          <div className="ringly-shimmer mt-2 h-3 w-3/4 rounded" />
        </div>
      )}

      {error && (
        <p role="alert" className="mt-3 text-sm text-danger-500">
          {error}
        </p>
      )}

      {answer && (
        <div className="mt-4 rounded-lg border border-ink-800 bg-ink-850 p-3">
          <p className="text-sm leading-relaxed text-ink-100">{answer.answer}</p>

          <div className="mt-2 flex items-center justify-between gap-2">
            <div className="flex flex-wrap gap-2">
              {answer.referencedDealIds.map((dealId) => (
                <Link
                  key={dealId}
                  href={`/deals/${dealId}`}
                  className="text-xs text-accent-400 underline"
                >
                  Open deal
                </Link>
              ))}
            </div>

            {supported && (
              <button
                type="button"
                onClick={() => (speaking ? stop() : speak(answer.answer))}
                className="shrink-0 text-xs text-ink-400 underline hover:text-ink-200"
              >
                {speaking ? 'Stop' : 'Read aloud'}
              </button>
            )}
          </div>

          {answer.insufficientInformation && (
            <p className="mt-2 border-t border-ink-800 pt-2 text-xs text-ink-400">
              Your notes did not have enough to answer fully. Record a memo after your next call.
            </p>
          )}
        </div>
      )}
    </section>
  );
}
