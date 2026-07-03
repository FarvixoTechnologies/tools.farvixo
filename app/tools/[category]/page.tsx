import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import Icon from '@/components/Icon';
import ToolCard from '@/components/ToolCard';
import { categories, getCategory } from '@/data/categories';
import { getToolsByCategory } from '@/data/tools';

interface Props { params: Promise<{ category: string }> }

export function generateStaticParams() {
  return categories.map((c) => ({ category: c.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { category } = await params;
  const cat = getCategory(category);
  if (!cat) return {};
  return {
    title: `${cat.name} — Free Online Tools | ToolNest`,
    description: `${cat.description} Free, fast, and private — all in your browser.`,
  };
}

export default async function CategoryPage({ params }: Props) {
  const { category } = await params;
  const cat = getCategory(category);
  if (!cat) notFound();
  const catTools = getToolsByCategory(cat.slug);
  const related = categories.filter((c) => c.slug !== cat.slug).slice(0, 5);

  return (
    <div className="container" style={{ paddingBottom: 64 }}>
      <nav className="breadcrumb" aria-label="Breadcrumb">
        <Link href="/">Home</Link> / <Link href="/tools">All Tools</Link> / <span>{cat.name}</span>
      </nav>

      <div className="cat-hero" style={{ paddingTop: 12 }}>
        <div className="cat-hero-inner">
          <span className="cat-hero-icon" style={{ background: `var(--${cat.accent})` }}><Icon name={cat.icon} size={30} /></span>
          <div>
            <h1>{cat.name} <span style={{ color: 'var(--brand-primary-hover)' }}>({catTools.length})</span></h1>
            <p>{cat.description}</p>
          </div>
        </div>
      </div>

      <div className="tool-grid" style={{ marginBottom: 48 }}>
        {catTools.map((t) => <ToolCard key={t.slug} tool={t} />)}
      </div>

      <div className="glass" style={{ padding: 24, marginBottom: 40 }}>
        <h2 style={{ fontSize: 18, marginBottom: 10 }}>Why use ToolNest&apos;s {cat.name}?</h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: 14, lineHeight: 1.7 }}>
          ToolNest&apos;s {cat.name.toLowerCase()} run directly in your browser wherever possible, which means your files
          never leave your device — instant processing, zero uploads, complete privacy. Every tool shares the same
          clean interface, works on mobile and desktop, and is completely free with no watermarks and no sign-up
          required. Whether you need a quick one-off conversion or process files every day, ToolNest gives you
          professional-grade results in seconds.
        </p>
      </div>

      <section>
        <h2 style={{ fontSize: 18, marginBottom: 14 }}>Explore more categories</h2>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
          {related.map((c) => (
            <Link key={c.slug} href={`/tools/${c.slug}`} className="chip" style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <Icon name={c.icon} size={13} /> {c.name}
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}
