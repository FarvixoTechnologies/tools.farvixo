import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import PageShell from '@/components/content/PageShell';
import { posts, getPost, getRelatedPosts } from '@/data/blog';
import { articleMetadata, articleJsonLd } from '@/lib/seo';

interface Props { params: Promise<{ slug: string }> }

export async function generateStaticParams() {
  return posts.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = getPost(slug);
  if (!post) return {};
  return articleMetadata(post);
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params;
  const post = getPost(slug);
  if (!post) notFound();

  const related = getRelatedPosts(post, 3);

  return (
    <PageShell
      title={post.title}
      subtitle={`${post.category} · ${post.displayDate}`}
      breadcrumb={[
        { name: 'Home', href: '/' },
        { name: 'Blog', href: '/blog' },
        { name: post.title },
      ]}
      jsonLd={articleJsonLd(post)}
    >
      {post.body.map((p, i) => <p key={i}>{p}</p>)}

      {related.length > 0 && (
        <section className="mt-6">
          <h2>Related articles</h2>
          <ul>
            {related.map((r) => (
              <li key={r.slug}><Link href={`/blog/${r.slug}`}>{r.title}</Link> · <span className="muted">{r.category}</span></li>
            ))}
          </ul>
        </section>
      )}

      <p className="mt-6"><Link href="/blog">← Back to Blog</Link> · <Link href="/tools">Try our tools</Link></p>
    </PageShell>
  );
}
