import { KanbanBoard } from '@/components/kanban-board';
import { NightlyReviewButton } from '@/components/nightly-review-button';
import { loadBoard } from '@/lib/repo/queries';
import { getEnv, hasDatabase } from '@/lib/env';

/** The board. Health and drift are computed server-side on every load. */
export const dynamic = 'force-dynamic';

export default async function PipelinePage() {
  const env = getEnv();

  if (!hasDatabase()) {
    return (
      <p className="mt-8 rounded-(--radius-card) border border-warn-500/30 bg-warn-500/5 p-4 text-sm text-ink-300">
        Set DATABASE_URL and run <code className="font-mono">npm run db:push</code> to see your
        pipeline.
      </p>
    );
  }

  const now = new Date();
  const board = await loadBoard(now);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Pipeline</h1>
          <p className="mt-0.5 text-sm text-ink-400">
            {board.total} {board.total === 1 ? 'deal' : 'deals'}. Drag a card to move it.
          </p>
        </div>
        <NightlyReviewButton />
      </div>

      <KanbanBoard board={board} now={now.toISOString()} timezone={env.RINGLY_TIMEZONE} />
    </div>
  );
}
