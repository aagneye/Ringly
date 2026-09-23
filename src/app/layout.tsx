import type { Metadata, Viewport } from 'next';
import './globals.css';
import { NavBar } from '@/components/nav-bar';

export const metadata: Metadata = {
  title: 'Ringly — your chief of staff',
  description:
    'Talk for sixty seconds after a client call. Ringly decides what to do and does it. Powered by NVIDIA Nemotron on Nebius Token Factory.',
  manifest: '/manifest.webmanifest',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'Ringly',
  },
};

export const viewport: Viewport = {
  themeColor: '#0a0b0e',
  width: 'device-width',
  initialScale: 1,
  // The recorder button is large and fixed; zooming is still allowed for
  // accessibility, but the default scale must not shift when the mic opens.
  maximumScale: 5,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-dvh bg-ink-950 text-ink-50">
        <div className="mx-auto flex min-h-dvh w-full max-w-6xl flex-col">
          <NavBar />
          <main className="flex-1 px-4 pb-32 pt-4 sm:px-6">{children}</main>
        </div>
      </body>
    </html>
  );
}
