import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Voice memos are uploaded as multipart bodies; raise the server action /
  // route body ceiling so a 90 second recording is never rejected.
  experimental: {
    serverActions: {
      bodySizeLimit: '10mb',
    },
  },
  // The recorder needs a secure context and microphone permission. These
  // headers keep the PWA installable without loosening the mic policy.
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'microphone=(self)' },
        ],
      },
    ];
  },
};

export default nextConfig;
