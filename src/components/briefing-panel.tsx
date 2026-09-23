'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import type { BriefingResult } from '@/lib/agent/briefing';

/**
 * The morning briefing, read aloud.
 *
 * Speech uses the browser's built-in synthesis rather than a hosted TTS service.
 * It is free, it needs no key, it works offline, and for a 60-word briefing the
 * quality difference does not justify another dependency that can fail during a
 * demo. Text is always shown as well, so nothing depends on audio working.
 */

interface BriefingPanelProps {
  briefing: BriefingResult | null;
  loading: boolean;
  error: string | null;
  onRegenerate: () => void;
}

const KIND_LABEL: Record<string, string> = {
  meeting: 'Meeting',
  reminder: 'Due',
  draft: 'Draft',
  drift: 'Drifting',
};

export function BriefingPanel({ briefing, loading, error, onRegenerate }: BriefingPanelProps) {
  const { speaking, supported, speak, stop } = useSpeech();
  const spokenRef = useRef<string | null>(null);

  // Stop speaking if the component unmounts mid-sentence.
  useEffect(() => stop, [stop]);

  if (loading) {
    return (
      <section className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-5">
        <div className="ringly-shimmer mb-3 h-4 w-40 rounded" />
        <div className="ringly-shimmer h-3 w-full rounded" />
        <div className="ringly-shimmer mt-2 h-3 w-4/5 rounded" />
      </section>
    );
  }

  if (error) {
    return (
      <section className="rounded-(--radius-card) border border-danger-500/30 bg-ink-900 p-5">
        <h2 className="text-[15px] font-semibold">Briefing unavailable</h2>
        <p className="mt-1 text-sm text-ink-300">{error}</p>
        <button
          type="button"
          onClick={onRegenerate}
          className="mt-3 rounded-full border border-ink-700 px-3 py-1.5 text-xs text-ink-200 hover:bg-ink-800"
        >
          Try again
        </button>
      </section>
    );
  }

  if (!briefing) return null;

  return (
    <section
      aria-label="Morning briefing"
      className="rounded-(--radius-card) border border-ink-800 bg-ink-900 p-5"
    >
      <div className="mb-3 flex items-start justify-between gap-3">
        <h2 className="text-[15px] font-semibold leading-snug">{briefing.headline}</h2>

        <div className="flex shrink-0 items-center gap-1">
          {supported && (
            <button
              type="button"
              onClick={() => {
                if (speaking) {
                  stop();
                  return;
                }
                spokenRef.current = briefing.spokenText;
                speak(briefing.spokenText);
              }}
              aria-label={speaking ? 'Stop reading' : 'Read the briefing aloud'}
              className="rounded-full border border-ink-700 p-1.5 text-ink-300 hover:bg-ink-800 hover:text-ink-50"
            >
              {speaking ? <StopIcon /> : <SpeakerIcon />}
            </button>
          )}
          <button
            type="button"
            onClick={onRegenerate}
            aria-label="Regenerate the briefing"
            className="rounded-full border border-ink-700 p-1.5 text-ink-300 hover:bg-ink-800 hover:text-ink-50"
          >
            <RefreshIcon />
          </button>
        </div>
      </div>

      <p className="text-sm leading-relaxed text-ink-200">{briefing.spokenText}</p>

      {briefing.items.length > 0 && (
        <ul className="mt-4 flex flex-col gap-2">
          {briefing.items.map((item, index) => (
            <li
              key={`${item.title}-${index}`}
              className="rounded-lg border border-ink-800 bg-ink-850 p-3"
            >
              <div className="flex items-baseline justify-between gap-2">
                <p className="text-sm font-medium text-ink-50">{item.title}</p>
                <span className="shrink-0 text-[10px] uppercase tracking-wide text-ink-400">
                  {KIND_LABEL[item.kind] ?? item.kind}
                </span>
              </div>
              <p className="mt-1 text-xs leading-snug text-ink-300">{item.detail}</p>
              {item.deal_id && (
                <Link
                  href={`/deals/${item.deal_id}`}
                  className="mt-1.5 inline-block text-xs text-accent-400 underline"
                >
                  Open deal
                </Link>
              )}
            </li>
          ))}
        </ul>
      )}

      {briefing.cached && (
        <p className="mt-3 text-[11px] text-ink-600">
          Generated earlier today. Refresh to regenerate on Nemotron Ultra.
        </p>
      )}
    </section>
  );
}

/** Thin wrapper over the Web Speech API, with a support probe. */
export function useSpeech() {
  const [speaking, setSpeaking] = useState(false);
  const [supported, setSupported] = useState(false);

  useEffect(() => {
    setSupported(typeof window !== 'undefined' && 'speechSynthesis' in window);
  }, []);

  const stop = useCallback(() => {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    setSpeaking(false);
  }, []);

  const speak = useCallback(
    (text: string) => {
      if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;
      window.speechSynthesis.cancel();

      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = 1.03;
      utterance.pitch = 1;
      utterance.onend = () => setSpeaking(false);
      utterance.onerror = () => setSpeaking(false);

      setSpeaking(true);
      window.speechSynthesis.speak(utterance);
    },
    [],
  );

  return { speaking, supported, speak, stop };
}

function SpeakerIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden>
      <path d="M11 5L6 9H3v6h3l5 4V5z" strokeLinejoin="round" />
      <path d="M16 9a4 4 0 0 1 0 6" strokeLinecap="round" />
    </svg>
  );
}

function StopIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <rect x="6" y="6" width="12" height="12" rx="2" />
    </svg>
  );
}

function RefreshIcon() {
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden>
      <path d="M21 12a9 9 0 1 1-3-6.7" strokeLinecap="round" />
      <path d="M21 4v5h-5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
