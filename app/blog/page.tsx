import Link from 'next/link';
import PageShell from '@/components/content/PageShell';
import { posts } from '@/data/blog';
import { pageMetadata, webPageJsonLd, blogUrl } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'Blog',
  description: 'Tips, guides and step-by-step tutorials from the Farvixo team — PDF, image, AI, SEO and government document how-tos to help you get more done, faster.',
  path: '/blog',
  ogBadge: 'BLOG',
});

const jsonLd = webPageJsonLd({
  type: 'Blog',
  name: 'Farvixo Tools Blog',
  description: 'Tips, guides and tutorials from the Farvixo team.',
  path: '/blog',
  extra: [
    {
      '@type': 'ItemList',
      itemListElement: posts.map((p, i) => ({
        '@type': 'ListItem',
        position: i + 1,
        url: blogUrl(p.slug),
        name: p.title,
      })),
    },
  ],
});

export default function BlogPage() {
  return (
    <PageShell title="Blog" subtitle="Tips, guides and tool tutorials" jsonLd={jsonLd}>
      <div className="blog-list">
        {posts.map((p) => (
          <article key={p.slug} className="blog-card glass">
            <span className="blog-cat">{p.category}</span>
            <h2><Link href={`/blog/${p.slug}`}>{p.title}</Link></h2>
            <time className="muted" dateTime={p.published}>{p.displayDate}</time>
          </article>
        ))}
      </div>
    </PageShell>
  );
}
