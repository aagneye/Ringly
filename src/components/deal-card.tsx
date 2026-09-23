'use client';

import Link from 'next/link';
import type { BoardDeal } from '@/lib/repo/queries';
import { formatAgo, titleCase, truncateWords } from '@/lib/format';

/**
 * One card on the board.
 *
 * Health is a single bar rather than a number or a badge. A salesperson scanning
 * twelve cards needs to spot the sick one in a glance, and a colour gradient does
 * that faster than reading "62". The precise reason is one tap away on the deal
 * page, which is the right place for detail.
 */

interface DealCardProps {
  deal: BoardDeal;
  now: Date;
  timezone: string;
  onDragStart?: (dealId: string) => void;
  dragging?: boolean;
}

export function DealCard({ deal, now, timezone, onDragStart, dragging = false }: DealCardProps) {
  const worstSignal = deal.signals[0];

  return (
    <Link
      href={`/deals/${deal.id}`}
      draggable={Boolean(onDragStart)}
      onDragStart={(event) => {
        if (!onDragStart) return;
        event.dataTransfer.setData('text/plain', deal.id);
        event.dataTransfer.effectAllowed = 'move';
        onDragStart(deal.id);
      }}
      className={`block rounded-(--radius-card) border border-ink-800 bg-ink-900 p-3 transition-colors hover:border-ink-600 ${
        dragging ? 'opacity-40' : ''
      }`}
    >
      <div className="mb-2 flex items-start justify-between gap-2">
        <div className="min-w-0">
          <p className="truncate text-sm font-medium text-ink-50">{deal.contactName}</p>
          {deal.company && (
            <p className="truncate text-xs text-ink-400">{deal.company}</p>
          )}
        </div>
        {deal.pendingDraftCount > 0 && (
          <span
            title={`${deal.pendingDraftCount} draft waiting for approval`}
            className="shrink-0 rounded-full bg-warn-500/15 px-1.5 py-0.5 text-[10px] text-warn-500"
          >
            {deal.pendingDraftCount} draft
          </span>
        )}
      </div>

      <HealthBar health={deal.health} />

      {deal.nextAction && (
        <p className="mt-2 text-xs leading-snug text-ink-300">
          {truncateWords(deal.nextAction, 70)}
        </p>
      )}

      <div className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-[11px] text-ink-400">
        {deal.deadline && (
          <span className={isOverdue(deal.deadline, now) ? 'text-danger-500' : ''}>
            due {formatAgo(deal.deadline, now, timezone)}
          </span>
        )}
        {deal.lastContactAt ? (
          <span>spoke {formatAgo(deal.lastContactAt, now, timezone)}</span>
        ) : (
          <span className="text-warn-500">never spoken</span>
        )}
        {deal.budget && <span>{deal.budget}</span>}
        {deal.noteCount > 0 && (
          <span>
            {deal.noteCount} {deal.noteCount === 1 ? 'note' : 'notes'}
          </span>
        )}
      </div>

      {worstSignal && (
        <p className="mt-2 border-t border-ink-800 pt-2 text-[11px] leading-snug text-warn-500">
          {truncateWords(worstSignal.explanation, 110)}
        </p>
      )}
    </Link>
  );
}

function HealthBar({ health }: { health: number }) {
  const colour =
    health >= 70 ? 'bg-good-500' : health >= 40 ? 'bg-warn-500' : 'bg-danger-500';

  return (
    <div
      role="meter"
      aria-valuenow={health}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label="Deal health"
      className="h-1 overflow-hidden rounded-full bg-ink-800"
    >
      <div className={`h-full rounded-full ${colour}`} style={{ width: `${health}%` }} />
    </div>
  );
}

function isOverdue(deadline: Date, now: Date): boolean {
  return deadline.getTime() < now.getTime();
}

/** Column heading with a count, used by the board. */
export function StageHeader({ stage, count }: { stage: string; count: number }) {
  return (
    <div className="mb-2 flex items-center justify-between px-1">
      <h3 className="text-xs font-medium uppercase tracking-wide text-ink-400">
        {titleCase(stage)}
      </h3>
      <span className="font-mono text-xs text-ink-600">{count}</span>
    </div>
  );
}
