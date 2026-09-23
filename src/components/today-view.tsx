'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Recorder, type MemoSubmission } from '@/components/recorder';
import { ActionResult } from '@/components/action-result';
import { ModelTraceStrip } from '@/components/model-trace';
import { BriefingPanel } from '@/components/briefing-panel';
import { AskBox } from '@/components/ask-box';
import { TodayPanels, type TodayReminder, type TodayEvent } from '@/components/today-panels';
import { DraftReview, type PendingDraft } from '@/components/draft-review';
import type { MemoResult } from '@/lib/agent/process-memo';
import type { BriefingResult } from '@/lib/agent/briefing';

/**
 * The home screen, and the whole demo in one page.
 *
 * Ordered by when things happen in a day rather than by importance: briefing
 * first thing, then today's calls and what's due, then the record button for
 * after a call, then asking Ringly anything. That ordering is what makes it feel
 * like something living alongside the user rather than a dashboard.
 *
 * The briefing is fetched client-side rather than rendered on the server. It is
 * the slowest call in the product, and blocking first paint on an Ultra
 * generation would make the app feel broken on arrival.
 */

interface TodayViewProps {
  initialReminders: TodayReminder[];
  initialEvents: TodayEvent[];
  initialDrafts: PendingDraft[];
  now: string;
  timezone: string;
  userName: string;
  configured: { nebius: boolean; database: boolean };
}

export function TodayView({
  initialReminders,
  initialEvents,
  initialDrafts,
  now,
  timezone,
  userName,
  configured,
}: TodayViewProps) {
  const router = useRouter();

  const [briefing, setBriefing] = useState<BriefingResult | null>(null);
  const [briefingLoading, setBriefingLoading] = useState(false);
  const [briefingError, setBriefingError] = useState<string | null>(null);

  const [result, setResult] = useState<MemoResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [memoError, setMemoError] = useState<string | null>(null);

  const loadBriefing = useCallback(
    async (force = false) => {
      if (!configured.nebius || !configured.database) return;

      setBriefingLoading(true);
      setBriefingError(null);
      try {
        const response = await fetch(`/api/briefing${force ? '?force=1' : ''}`);
        const body = (await response.json()) as BriefingResult & { error?: string };
        if (!response.ok) throw new Error(body.error ?? `Request failed (${response.status})`);
        setBriefing(body);
      } catch (caught) {
        setBriefingError(caught instanceof Error ? caught.message : 'Could not load the briefing.');
      } finally {
        setBriefingLoading(false);
      }
    },
    [configured.database, configured.nebius],
  );

  useEffect(() => {
    void loadBriefing(false);
  }, [loadBriefing]);

  async function submitMemo(submission: MemoSubmission) {
    setBusy(true);
    setMemoError(null);
    setResult(null);

    try {
      let response: Response;

      if (submission.audio) {
        const form = new FormData();
        const extension = submission.audio.mimeType.includes('mp4') ? 'mp4' : 'webm';
        form.append('audio', submission.audio.blob, `memo.${extension}`);
        form.append('durationSeconds', String(submission.audio.durationSeconds));
        response = await fetch('/api/notes', { method: 'POST', body: form });
      } else {
        response = await fetch('/api/notes', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ transcript: submission.transcript }),
        });
      }

      const body = (await response.json()) as MemoResult & { error?: string; hint?: string };
      if (!response.ok) {
        throw new Error([body.error, body.hint].filter(Boolean).join(' '));
      }

      setResult(body);
      router.refresh();
    } catch (caught) {
      setMemoError(caught instanceof Error ? caught.message : 'Could not process that memo.');
    } finally {
      setBusy(false);
    }
  }

  if (!configured.database) {
    return <SetupNotice missing="database" />;
  }

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-xl font-semibold tracking-tight">
          {greeting()}, {userName}
        </h1>
        <p className="mt-0.5 text-sm text-ink-400">
          {new Date(now).toLocaleDateString('en-GB', {
            weekday: 'long',
            day: 'numeric',
            month: 'long',
            timeZone: timezone,
          })}
        </p>
      </div>

      {!configured.nebius && <SetupNotice missing="nebius" inline />}

      <BriefingPanel
        briefing={briefing}
        loading={briefingLoading}
        error={briefingError}
        onRegenerate={() => void loadBriefing(true)}
      />

      <TodayPanels
        reminders={initialReminders}
        events={initialEvents}
        now={now}
        timezone={timezone}
      />

      <DraftReview drafts={initialDrafts} />

      <Recorder onSubmit={submitMemo} busy={busy} disabled={!configured.nebius} />

      {memoError && (
        <p role="alert" className="rounded-lg bg-danger-500/10 p-3 text-sm text-danger-500">
          {memoError}
        </p>
      )}

      {result && (
        <>
          <ActionResult
            transcript={result.transcript}
            actions={result.report.actions}
            awaitingApproval={result.report.awaitingApproval}
            failed={result.report.failed}
            noActionReason={result.noActionReason}
            contactName={result.target.contactName}
            dealId={result.target.dealId}
            createdContact={result.target.createdContact}
            onDismiss={() => setResult(null)}
          />
          <ModelTraceStrip traces={result.traces.traces} />
        </>
      )}

      <AskBox />
    </div>
  );
}

function greeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

function SetupNotice({
  missing,
  inline = false,
}: {
  missing: 'database' | 'nebius';
  inline?: boolean;
}) {
  const copy =
    missing === 'database'
      ? {
          title: 'Connect a database',
          body: 'Create a free Postgres database at neon.tech, put the connection string in DATABASE_URL, then run npm run db:push.',
        }
      : {
          title: 'Add your Nebius key',
          body: 'Get a key at tokenfactory.nebius.com and set NEBIUS_API_KEY. Until then the board works but Ringly cannot think.',
        };

  return (
    <section
      className={`rounded-(--radius-card) border border-warn-500/30 bg-warn-500/5 p-4 ${
        inline ? '' : 'mt-8'
      }`}
    >
      <h2 className="text-sm font-semibold text-warn-500">{copy.title}</h2>
      <p className="mt-1 text-sm text-ink-300">{copy.body}</p>
    </section>
  );
}
