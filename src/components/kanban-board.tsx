'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { DealCard, StageHeader } from './deal-card';
import type { Board, BoardDeal } from '@/lib/repo/queries';
import type { DealStage } from '@/lib/db/schema/enums';

/**
 * The pipeline board.
 *
 * Drag and drop is built on the native HTML5 API rather than a library. It is
 * fewer dependencies, it works with a keyboard through the fallback select on
 * each card's page, and the interaction is simple enough that the accessibility
 * story of a custom pointer implementation would be worse.
 *
 * The move is applied optimistically and rolled back on failure, because a card
 * that snaps back after 400ms of server latency feels broken even when the write
 * succeeded.
 */

interface KanbanBoardProps {
  board: Board;
  now: string;
  timezone: string;
}

export function KanbanBoard({ board, now, timezone }: KanbanBoardProps) {
  const router = useRouter();
  const nowDate = new Date(now);

  const [columns, setColumns] = useState(board.columns);
  const [dragging, setDragging] = useState<string | null>(null);
  const [hoverStage, setHoverStage] = useState<DealStage | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function moveDeal(dealId: string, toStage: DealStage) {
    const snapshot = columns;

    let moved: BoardDeal | undefined;
    for (const column of columns) {
      const found = column.deals.find((deal) => deal.id === dealId);
      if (found) moved = found;
    }
    if (!moved || moved.stage === toStage) return;

    setColumns((current) =>
      current.map((column) => {
        if (column.stage === moved!.stage) {
          return { ...column, deals: column.deals.filter((deal) => deal.id !== dealId) };
        }
        if (column.stage === toStage) {
          return { ...column, deals: [{ ...moved!, stage: toStage }, ...column.deals] };
        }
        return column;
      }),
    );

    try {
      const response = await fetch(`/api/deals/${dealId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ stage: toStage }),
      });
      if (!response.ok) throw new Error(await readError(response));
      router.refresh();
    } catch (caught) {
      setColumns(snapshot);
      setError(caught instanceof Error ? caught.message : 'Could not move that deal.');
    }
  }

  if (board.total === 0) {
    return <EmptyBoard />;
  }

  return (
    <div className="flex flex-col gap-3">
      {error && (
        <p role="alert" className="rounded-lg bg-danger-500/10 p-3 text-sm text-danger-500">
          {error}
        </p>
      )}

      <div className="ringly-scroll flex gap-3 overflow-x-auto pb-4">
        {columns.map((column) => (
          <div
            key={column.stage}
            onDragOver={(event) => {
              event.preventDefault();
              setHoverStage(column.stage);
            }}
            onDragLeave={() => setHoverStage((current) => (current === column.stage ? null : current))}
            onDrop={(event) => {
              event.preventDefault();
              const dealId = event.dataTransfer.getData('text/plain');
              setHoverStage(null);
              setDragging(null);
              if (dealId) void moveDeal(dealId, column.stage);
            }}
            className={`flex w-[260px] shrink-0 flex-col rounded-(--radius-card) p-2 transition-colors ${
              hoverStage === column.stage ? 'bg-accent-500/5 ring-1 ring-accent-500/30' : ''
            }`}
          >
            <StageHeader stage={column.stage} count={column.deals.length} />

            <div className="flex flex-col gap-2">
              {column.deals.map((deal) => (
                <DealCard
                  key={deal.id}
                  deal={deal}
                  now={nowDate}
                  timezone={timezone}
                  onDragStart={setDragging}
                  dragging={dragging === deal.id}
                />
              ))}

              {column.deals.length === 0 && (
                <p className="rounded-lg border border-dashed border-ink-800 p-3 text-center text-xs text-ink-600">
                  Nothing here
                </p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function EmptyBoard() {
  return (
    <div className="rounded-(--radius-card) border border-dashed border-ink-800 p-10 text-center">
      <p className="text-sm text-ink-300">No deals yet.</p>
      <p className="mt-1 text-sm text-ink-400">
        Record a memo about a client call and Ringly will create the first one.
      </p>
    </div>
  );
}

async function readError(response: Response): Promise<string> {
  try {
    const body = (await response.json()) as { error?: string };
    return body.error ?? `Request failed (${response.status})`;
  } catch {
    return `Request failed (${response.status})`;
  }
}
