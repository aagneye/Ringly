import { TodayView } from '@/components/today-view';
import { loadDueReminders, loadTodaysEvents, loadPendingDrafts } from '@/lib/repo/queries';
import { getEnv, hasNebiusCredentials, hasDatabase } from '@/lib/env';

/**
 * Today, server-rendered.
 *
 * Reminders, meetings and drafts are cheap database reads, so they arrive with
 * first paint. The briefing is fetched by the client afterwards, because an Ultra
 * call at request time would leave the user looking at nothing for several
 * seconds.
 */
export const dynamic = 'force-dynamic';

export default async function TodayPage() {
  const env = getEnv();
  const configured = { nebius: hasNebiusCredentials(), database: hasDatabase() };
  const now = new Date();

  if (!configured.database) {
    return (
      <TodayView
        initialReminders={[]}
        initialEvents={[]}
        initialDrafts={[]}
        now={now.toISOString()}
        timezone={env.RINGLY_TIMEZONE}
        userName={env.RINGLY_USER_NAME}
        configured={configured}
      />
    );
  }

  const [reminders, events, drafts] = await Promise.all([
    loadDueReminders(now),
    loadTodaysEvents(now),
    loadPendingDrafts(),
  ]);

  return (
    <TodayView
      initialReminders={reminders.map((reminder) => ({
        ...reminder,
        dueAt: reminder.dueAt.toISOString(),
      }))}
      initialEvents={events.map((event) => ({
        ...event,
        startsAt: event.startsAt.toISOString(),
        endsAt: event.endsAt.toISOString(),
      }))}
      initialDrafts={drafts.map((draft) => ({
        ...draft,
        createdAt: draft.createdAt.toISOString(),
      }))}
      now={now.toISOString()}
      timezone={env.RINGLY_TIMEZONE}
      userName={env.RINGLY_USER_NAME}
      configured={configured}
    />
  );
}
