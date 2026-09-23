'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const LINKS = [
  { href: '/', label: 'Today' },
  { href: '/pipeline', label: 'Pipeline' },
  { href: '/models', label: 'Models' },
] as const;

/**
 * Three destinations, deliberately.
 *
 * Today is where the product lives; Pipeline is the board; Models exists for the
 * judges and for anyone curious which tier did what. A settings page was cut —
 * there is nothing to configure that belongs in the UI rather than in .env.
 */
export function NavBar() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-30 border-b border-ink-800 bg-ink-950/85 backdrop-blur">
      <div className="flex items-center justify-between px-4 py-3 sm:px-6">
        <Link href="/" className="flex items-center gap-2" aria-label="Ringly home">
          <span
            aria-hidden
            className="grid h-7 w-7 place-items-center rounded-full border border-accent-500/50"
          >
            <span className="h-3 w-1.5 rounded-full bg-accent-500" />
          </span>
          <span className="text-[15px] font-semibold tracking-tight">Ringly</span>
        </Link>

        <nav aria-label="Main">
          <ul className="flex items-center gap-1">
            {LINKS.map((link) => {
              const active =
                link.href === '/' ? pathname === '/' : pathname.startsWith(link.href);
              return (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    aria-current={active ? 'page' : undefined}
                    className={`rounded-full px-3 py-1.5 text-sm transition-colors ${
                      active
                        ? 'bg-ink-800 text-ink-50'
                        : 'text-ink-400 hover:bg-ink-850 hover:text-ink-200'
                    }`}
                  >
                    {link.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>
      </div>
    </header>
  );
}
