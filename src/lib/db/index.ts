import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import { getEnv } from '@/lib/env';
import * as schema from './schema';

/**
 * Neon over HTTP rather than a pooled TCP connection.
 *
 * Every route in this app is a short-lived serverless invocation, so a
 * connection pool would be torn down before it paid for itself. The HTTP driver
 * makes each query a stateless request, which is the right shape here and
 * removes connection-limit failures under the burst of parallel reads the
 * dashboard issues on first paint.
 */

export class MissingDatabaseUrlError extends Error {
  constructor() {
    super(
      'DATABASE_URL is not set. Create a free Postgres database at https://neon.tech and add the connection string to .env.local',
    );
    this.name = 'MissingDatabaseUrlError';
  }
}

type Database = ReturnType<typeof createDatabase>;

function createDatabase(url: string) {
  return drizzle(neon(url), { schema });
}

let cached: Database | null = null;

/** Return the shared Drizzle instance, or throw with setup instructions. */
export function getDb(): Database {
  if (cached) return cached;

  const { DATABASE_URL } = getEnv();
  if (!DATABASE_URL) throw new MissingDatabaseUrlError();

  cached = createDatabase(DATABASE_URL);
  return cached;
}

/** Drop the memoised connection. Test-only helper. */
export function resetDb(): void {
  cached = null;
}

export { schema };
