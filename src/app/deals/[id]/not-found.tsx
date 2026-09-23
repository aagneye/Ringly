import Link from 'next/link';

/** Shown by notFound() when a deal id in the URL does not exist. */
export default function DealNotFound() {
  return (
    <div className="mt-12 flex flex-col items-center gap-3 text-center">
      <p className="text-sm text-ink-400">That deal does not exist, or was removed.</p>
      <Link href="/pipeline" className="text-sm text-accent-400 underline">
        Back to the pipeline
      </Link>
    </div>
  );
}
