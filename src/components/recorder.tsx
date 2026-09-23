'use client';

import { useState } from 'react';
import { useRecorder } from './use-recorder';
import { formatDuration } from '@/lib/format';

/**
 * The record button.
 *
 * One tap to start, one to stop. No pause, no re-take, no trim — a memo is
 * disposable and re-recording is faster than editing.
 *
 * The typed-note path is given equal visual weight rather than hidden behind a
 * menu. It is the honest fallback when a microphone is unavailable, and it is
 * also how the agent loop gets demonstrated on a machine with no audio device.
 */

export interface MemoSubmission {
  audio?: { blob: Blob; mimeType: string; durationSeconds: number };
  transcript?: string;
}

interface RecorderProps {
  onSubmit: (submission: MemoSubmission) => void;
  busy: boolean;
  disabled?: boolean;
}

const MAX_SECONDS = 120;

export function Recorder({ onSubmit, busy, disabled = false }: RecorderProps) {
  const recorder = useRecorder(MAX_SECONDS);
  const [mode, setMode] = useState<'voice' | 'text'>('voice');
  const [draft, setDraft] = useState('');

  const recording = recorder.state === 'recording';
  const preparing = recorder.state === 'requesting' || recorder.state === 'stopping';
  const locked = busy || disabled;

  async function handleToggle() {
    if (recording) {
      const result = await recorder.stop();
      if (result) {
        onSubmit({ audio: result });
      }
      return;
    }
    await recorder.start();
  }

  function handleTextSubmit(event: React.FormEvent) {
    event.preventDefault();
    const trimmed = draft.trim();
    if (!trimmed || locked) return;
    onSubmit({ transcript: trimmed });
    setDraft('');
  }

  return (
    <section
      aria-label="Record a memo"
      className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-5"
    >
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h2 className="text-[15px] font-semibold">After a call</h2>
          <p className="mt-0.5 text-sm text-ink-400">
            Talk for a minute. Ringly decides what to do and does it.
          </p>
        </div>

        <div
          role="tablist"
          aria-label="Input method"
          className="flex rounded-full border border-ink-700 p-0.5"
        >
          {(['voice', 'text'] as const).map((option) => (
            <button
              key={option}
              role="tab"
              type="button"
              aria-selected={mode === option}
              onClick={() => {
                if (recording) recorder.cancel();
                setMode(option);
              }}
              className={`rounded-full px-3 py-1 text-xs capitalize transition-colors ${
                mode === option ? 'bg-ink-700 text-ink-50' : 'text-ink-400 hover:text-ink-200'
              }`}
            >
              {option}
            </button>
          ))}
        </div>
      </div>

      {mode === 'voice' ? (
        <div className="flex flex-col items-center gap-4 py-2">
          {!recorder.supported && (
            <p className="text-center text-sm text-warn-500">
              This browser cannot record audio. Switch to Text above.
            </p>
          )}

          <div className="relative grid place-items-center">
            {recording && (
              <span
                aria-hidden
                className="ringly-pulse absolute h-20 w-20 rounded-full bg-accent-500/30"
              />
            )}
            <button
              type="button"
              onClick={handleToggle}
              disabled={locked || preparing || !recorder.supported}
              aria-label={recording ? 'Stop recording and send' : 'Start recording'}
              className={`relative grid h-20 w-20 place-items-center rounded-full border transition-all disabled:opacity-40 ${
                recording
                  ? 'border-danger-500 bg-danger-500/15'
                  : 'border-accent-500 bg-accent-500/10 hover:bg-accent-500/20'
              }`}
            >
              {recording ? (
                <span className="h-6 w-6 rounded-sm bg-danger-500" aria-hidden />
              ) : (
                <MicIcon />
              )}
            </button>
          </div>

          <div className="h-10 text-center">
            {busy ? (
              <p className="text-sm text-accent-300">Thinking…</p>
            ) : recording ? (
              <>
                <p aria-live="polite" className="font-mono text-sm text-ink-200">
                  {formatDuration(recorder.elapsed)}
                </p>
                <LevelBar level={recorder.level} />
              </>
            ) : preparing ? (
              <p className="text-sm text-ink-400">One moment…</p>
            ) : (
              <p className="text-sm text-ink-400">Tap to record</p>
            )}
          </div>

          {recorder.error && (
            <p role="alert" className="max-w-sm text-center text-sm text-danger-500">
              {recorder.error}
            </p>
          )}

          {recording && (
            <button
              type="button"
              onClick={recorder.cancel}
              className="text-xs text-ink-400 underline hover:text-ink-200"
            >
              Discard
            </button>
          )}
        </div>
      ) : (
        <form onSubmit={handleTextSubmit} className="flex flex-col gap-3">
          <label htmlFor="memo-text" className="sr-only">
            Type your note
          </label>
          <textarea
            id="memo-text"
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
            rows={4}
            placeholder="Spoke to Priya at Northwind. She wants pricing before her board meeting on Friday, and she's worried about how long onboarding takes."
            className="w-full resize-y rounded-lg border border-ink-700 bg-ink-850 p-3 text-sm text-ink-50 placeholder:text-ink-600 focus:border-accent-500 focus:outline-none"
          />
          <button
            type="submit"
            disabled={locked || draft.trim().length === 0}
            className="self-end rounded-full bg-accent-500 px-5 py-2 text-sm font-medium text-ink-950 transition-opacity disabled:opacity-40"
          >
            {busy ? 'Thinking…' : 'Send to Ringly'}
          </button>
        </form>
      )}
    </section>
  );
}

function LevelBar({ level }: { level: number }) {
  return (
    <div
      aria-hidden
      className="mx-auto mt-2 h-1 w-32 overflow-hidden rounded-full bg-ink-800"
    >
      <div
        className="h-full rounded-full bg-accent-500 transition-[width] duration-75"
        style={{ width: `${Math.max(4, level * 100)}%` }}
      />
    </div>
  );
}

function MicIcon() {
  return (
    <svg
      width="26"
      height="26"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      className="text-accent-400"
      aria-hidden
    >
      <rect x="9" y="3" width="6" height="11" rx="3" />
      <path d="M5 11a7 7 0 0 0 14 0" />
      <line x1="12" y1="18" x2="12" y2="21" />
    </svg>
  );
}
