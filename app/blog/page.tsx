import type { Metadata } from 'next';
import Link from 'next/link';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Blog | Farvixo Tools',
  description: 'Tips, guides and productivity articles from the Farvixo team.',
};

const posts = [
  { slug: 'compress-pdf-without-quality-loss', title: 'How to Compress a PDF Without Losing Quality', category: 'PDF', date: 'Jun 15, 2025' },
  { slug: 'best-ai-writing-tools-2025', title: '10 Best AI Writing Tools in 2025', category: 'AI', date: 'Jun 8, 2025' },
  { slug: 'passport-photo-requirements-india', title: 'Passport Photo Requirements for India (2025 Guide)', category: 'Government', date: 'May 28, 2025' },
  { slug: 'remove-background-free', title: 'Remove Image Backgrounds for Free — Complete Guide', category: 'Image', date: 'May 20, 2025' },
  { slug: 'seo-checklist-2025', title: 'On-Page SEO Checklist for 2025', category: 'SEO', date: 'May 12, 2025' },
];

export default function BlogPage() {
  return (
    <PageShell title="Blog" subtitle="Tips, guides and tool tutorials">
      <div className="blog-list">
        {posts.map((p) => (
          <article key={p.slug} className="blog-card glass">
            <span className="blog-cat">{p.category}</span>
            <h2><Link href={`/blog/${p.slug}`}>{p.title}</Link></h2>
            <time className="muted">{p.date}</time>
          </article>
        ))}
      </div>
    </PageShell>
  );
}
