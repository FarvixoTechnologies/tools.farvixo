import type { MetadataRoute } from 'next';
import { categories } from '@/data/categories';
import { tools } from '@/data/tools';

const BASE = 'https://toolnestfm.com';
const NOW = new Date();

const staticPages: Array<{ path: string; priority: number; freq: MetadataRoute.Sitemap[number]['changeFrequency'] }> = [
  { path: '/tools', priority: 0.9, freq: 'daily' },
  { path: '/blog', priority: 0.7, freq: 'weekly' },
  { path: '/how-it-works', priority: 0.6, freq: 'monthly' },
  { path: '/about', priority: 0.5, freq: 'monthly' },
  { path: '/contact', priority: 0.5, freq: 'monthly' },
  { path: '/help', priority: 0.5, freq: 'monthly' },
  { path: '/status', priority: 0.4, freq: 'weekly' },
  { path: '/login', priority: 0.3, freq: 'yearly' },
  { path: '/signup', priority: 0.3, freq: 'yearly' },
  { path: '/privacy-policy', priority: 0.3, freq: 'yearly' },
  { path: '/terms-of-service', priority: 0.3, freq: 'yearly' },
  { path: '/cookie-policy', priority: 0.3, freq: 'yearly' },
  { path: '/refund-policy', priority: 0.3, freq: 'yearly' },
  { path: '/gdpr', priority: 0.3, freq: 'yearly' },
  { path: '/security', priority: 0.4, freq: 'yearly' },
  { path: '/sitemap', priority: 0.3, freq: 'monthly' },
];

const blogPosts = [
  'compress-pdf-without-quality-loss',
  'best-ai-writing-tools-2025',
  'passport-photo-requirements-india',
  'remove-background-free',
  'seo-checklist-2025',
];

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: BASE, lastModified: NOW, changeFrequency: 'daily', priority: 1 },
    ...staticPages.map((p) => ({ url: `${BASE}${p.path}`, lastModified: NOW, changeFrequency: p.freq, priority: p.priority })),
    ...categories.map((c) => ({ url: `${BASE}/tools/${c.slug}`, lastModified: NOW, changeFrequency: 'weekly' as const, priority: 0.8 })),
    ...tools.map((t) => ({
      url: `${BASE}/tools/${t.category}/${t.slug}`,
      lastModified: NOW,
      changeFrequency: 'weekly' as const,
      // Popular / AI / new tools rank slightly higher in the sitemap.
      priority: t.badge === 'popular' ? 0.9 : t.badge ? 0.8 : 0.7,
    })),
    ...blogPosts.map((slug) => ({ url: `${BASE}/blog/${slug}`, lastModified: NOW, changeFrequency: 'monthly' as const, priority: 0.6 })),
  ];
}
