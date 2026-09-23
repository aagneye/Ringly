import type { MetadataRoute } from 'next';

/**
 * Keep search engines out.
 *
 * This is a hackathon demo with a judge's URL, not a product with an audience
 * to acquire. Indexing would only invite crawler traffic against Nemotron
 * calls that cost real tokens.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', disallow: '/' },
  };
}
