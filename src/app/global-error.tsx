'use client';

/**
 * The last line of defence.
 *
 * Next.js renders this when a server or client component throws somewhere below
 * the root layout. Without it a runtime error is a blank white screen, which is
 * the worst possible thing to happen mid-demo — this at least tells a judge the
 * app is aware something broke, and offers a way back.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body className="grid min-h-dvh place-items-center bg-ink-950 px-6 text-ink-50">
        <div className="max-w-sm text-center">
          <p className="text-sm font-medium text-danger-500">Something went wrong.</p>
          <p className="mt-2 text-sm text-ink-400">
            {process.env.NODE_ENV === 'development' ? error.message : "Ringly hit a snag. Give it another try."}
          </p>
          <button
            type="button"
            onClick={reset}
            className="mt-4 rounded-full bg-accent-500 px-4 py-2 text-sm font-medium text-ink-950"
          >
            Try again
          </button>
        </div>
      </body>
    </html>
  );
}
