import { z } from 'zod';

/**
 * Environment contract for Ringly.
 *
 * Nothing here is required at import time. The app is deliberately runnable
 * with an empty .env so the UI, the database layer and the whole test suite
 * can be developed before a Nebius key exists. Each subsystem asks for the
 * variable it needs at the moment it needs it, and degrades with a clear
 * message instead of crashing the process on boot.
 */
const envSchema = z.object({
  NEBIUS_API_KEY: z.string().min(1).optional(),
  NEBIUS_BASE_URL: z.string().url().default('https://api.tokenfactory.nebius.com/v1/'),
  DATABASE_URL: z.string().min(1).optional(),
  TAVILY_API_KEY: z.string().min(1).optional(),
  RINGLY_USER_NAME: z.string().default('there'),
  RINGLY_USER_EMAIL: z.string().default(''),
  RINGLY_TIMEZONE: z.string().default('Asia/Kolkata'),
  CRON_SECRET: z.string().min(1).optional(),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
});

export type Env = z.infer<typeof envSchema>;

let cached: Env | null = null;

/** Parse and memoise process.env. Throws only if a present value is malformed. */
export function getEnv(): Env {
  if (cached) return cached;

  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((issue) => `  ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }

  cached = parsed.data;
  return cached;
}

/** Reset the memoised env. Test-only helper. */
export function resetEnvCache(): void {
  cached = null;
}

/** True when a Nebius key is present, so callers can pick a degraded path. */
export function hasNebiusCredentials(): boolean {
  return Boolean(getEnv().NEBIUS_API_KEY);
}

/** True when a Postgres connection string is present. */
export function hasDatabase(): boolean {
  return Boolean(getEnv().DATABASE_URL);
}

/** True when Tavily enrichment is available. */
export function hasTavily(): boolean {
  return Boolean(getEnv().TAVILY_API_KEY);
}
