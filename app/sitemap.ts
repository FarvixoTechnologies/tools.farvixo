import type { MetadataRoute } from 'next';
import { categories } from '@/data/categories';
import { tools } from '@/data/tools';

const BASE = 'https://toolnestfm.com';

const staticPages = [
  '/tools',
  '/about',
  '/contact',
  '/help',
  '/how-it-works',
  '/blog',
  '/status',
  '/login',
  '/signup',
  '/privacy-policy',
  '/terms-of-service',
  '/cookie-policy',
  '/refund-policy',
  '/gdpr',
  '/security',
  '/sitemap',
];

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: BASE, changeFrequency: 'daily', priority: 1 },
    ...staticPages.map((path) => ({ url: `${BASE}${path}`, changeFrequency: 'weekly' as const, priority: 0.7 })),
    ...categories.map((c) => ({ url: `${BASE}/tools/${c.slug}`, changeFrequency: 'weekly' as const, priority: 0.8 })),
    ...tools.map((t) => ({ url: `${BASE}/tools/${t.category}/${t.slug}`, changeFrequency: 'monthly' as const, priority: 0.7 })),
    { url: `${BASE}/blog/compress-pdf-without-quality-loss`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${BASE}/blog/best-ai-writing-tools-2025`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${BASE}/blog/passport-photo-requirements-india`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${BASE}/blog/remove-background-free`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${BASE}/blog/seo-checklist-2025`, changeFrequency: 'monthly', priority: 0.6 },
  ];
}
