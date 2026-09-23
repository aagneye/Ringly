import { getEnv } from '@/lib/env';

/**
 * Tavily search, used to enrich a contact's company with sourced facts.
 *
 * Optional by design: no key means enrichment is skipped and the rest of the
 * product is unaffected. A demo must never fail because an auxiliary service is
 * unconfigured.
 */

const TAVILY_ENDPOINT = 'https://api.tavily.com/search';

export interface SearchHit {
  title: string;
  url: string;
  content: string;
  score: number;
}

export class TavilyNotConfiguredError extends Error {
  constructor() {
    super('TAVILY_API_KEY is not set, so company enrichment is unavailable.');
    this.name = 'TavilyNotConfiguredError';
  }
}

export interface SearchOptions {
  query: string;
  maxResults?: number;
  /** Narrows to recent news, which is what makes a fact worth mentioning. */
  topic?: 'general' | 'news';
  days?: number;
}

/** Run a search and return ranked hits. Throws if unconfigured. */
export async function search(options: SearchOptions): Promise<SearchHit[]> {
  const { TAVILY_API_KEY } = getEnv();
  if (!TAVILY_API_KEY) throw new TavilyNotConfiguredError();

  const response = await fetch(TAVILY_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${TAVILY_API_KEY}`,
    },
    body: JSON.stringify({
      query: options.query,
      max_results: options.maxResults ?? 5,
      topic: options.topic ?? 'general',
      ...(options.days ? { days: options.days } : {}),
      search_depth: 'basic',
    }),
    // A slow search must not hold up the agent run behind it.
    signal: AbortSignal.timeout(12_000),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => response.statusText);
    throw new Error(`Tavily search failed (${response.status}): ${detail.slice(0, 200)}`);
  }

  const payload: unknown = await response.json();
  return normaliseHits(payload);
}

/** Defensively read the hit list, tolerating field changes in the response. */
export function normaliseHits(payload: unknown): SearchHit[] {
  if (!payload || typeof payload !== 'object') return [];
  const results = (payload as { results?: unknown }).results;
  if (!Array.isArray(results)) return [];

  return results.flatMap((entry): SearchHit[] => {
    if (!entry || typeof entry !== 'object') return [];
    const typed = entry as {
      title?: unknown;
      url?: unknown;
      content?: unknown;
      score?: unknown;
    };
    if (typeof typed.url !== 'string' || typeof typed.content !== 'string') return [];
    return [
      {
        title: typeof typed.title === 'string' ? typed.title : typed.url,
        url: typed.url,
        content: typed.content,
        score: typeof typed.score === 'number' ? typed.score : 0,
      },
    ];
  });
}
