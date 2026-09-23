import OpenAI from 'openai';
import { getEnv } from '@/lib/env';

/**
 * Nebius Token Factory speaks the OpenAI wire protocol, so the official SDK
 * works unchanged once the base URL is repointed. Keeping the client behind a
 * factory means the key is read lazily — importing this module in a test or in
 * a page that never calls a model does not require credentials.
 */

export class MissingNebiusKeyError extends Error {
  constructor() {
    super(
      'NEBIUS_API_KEY is not set. Add it to .env.local — get a key at https://tokenfactory.nebius.com',
    );
    this.name = 'MissingNebiusKeyError';
  }
}

let cached: OpenAI | null = null;

/** Return a configured client, or throw a clearly-worded error if unkeyed. */
export function getNebiusClient(): OpenAI {
  if (cached) return cached;

  const env = getEnv();
  if (!env.NEBIUS_API_KEY) {
    throw new MissingNebiusKeyError();
  }

  cached = new OpenAI({
    baseURL: env.NEBIUS_BASE_URL,
    apiKey: env.NEBIUS_API_KEY,
    // Voice memos arrive in bursts and Ultra can take a while on the nightly
    // review, so allow a generous ceiling rather than the SDK default.
    timeout: 120_000,
    maxRetries: 2,
  });

  return cached;
}

/** Drop the memoised client. Test-only helper. */
export function resetNebiusClient(): void {
  cached = null;
}
