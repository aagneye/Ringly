import { defineConfig } from 'drizzle-kit';
import { config } from 'dotenv';

// Drizzle Kit runs outside Next.js, so it does not get .env.local for free.
config({ path: '.env.local' });
config({ path: '.env' });

export default defineConfig({
  schema: './src/lib/db/schema/index.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? '',
  },
  verbose: true,
  strict: true,
});
