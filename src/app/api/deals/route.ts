import { NextResponse } from 'next/server';
import { loadBoard } from '@/lib/repo/queries';
import { handleApiError } from '@/lib/api';

/** Kanban board data, with health and drift signals already computed. */
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const board = await loadBoard(new Date());
    return NextResponse.json(board);
  } catch (error) {
    return handleApiError(error);
  }
}
