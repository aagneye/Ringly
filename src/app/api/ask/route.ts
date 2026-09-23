import { NextResponse } from 'next/server';
import { askRingly } from '@/lib/agent/ask';
import { handleApiError, jsonError, readJsonBody } from '@/lib/api';

/** "What's happening with Priya?" answered from the note history. */
export const runtime = 'nodejs';
export const maxDuration = 90;

const MAX_QUESTION_CHARS = 500;

export async function POST(request: Request) {
  try {
    const body = await readJsonBody<{ question?: unknown }>(request);
    const question = typeof body?.question === 'string' ? body.question.trim() : '';

    if (!question) {
      return jsonError('Ask a question first.', 400, 'missing_question');
    }

    if (question.length > MAX_QUESTION_CHARS) {
      return jsonError('That question is too long.', 413, 'question_too_large');
    }

    const result = await askRingly(question, new Date());
    return NextResponse.json(result);
  } catch (error) {
    return handleApiError(error);
  }
}
