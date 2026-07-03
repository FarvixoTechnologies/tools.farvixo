import type { Metadata } from 'next';
import Link from 'next/link';
import Icon from '@/components/Icon';
import ToolCard from '@/components/ToolCard';
import { categories } from '@/data/categories';
import { getToolsByCategory, tools } from '@/data/tools';

export const metadata: Metadata = {
  title: 'All Tools (120+) — ToolNest',
  description: 'Browse all 120+ free online tools: PDF, Image, Video, Audio, AI, Developer, Text, SEO, Business, Security and more.',
};

export default function AllToolsPage() {
  return (
    <div className="container" style={{ paddingBottom: 64 }}>
      <div className="cat-hero">
        <div className="cat-hero-inner">
          <span className="cat-hero-icon" style={{ background: 'var(--brand-gradient)' }}><Icon name="grid" size={30} /></span>
          <div>
            <h1>All Tools <span className="gradient-text">({tools.length})</span></h1>
            <p>Every ToolNest tool, organized by category. Click any tool to use it instantly — free, fast and private.</p>
          </div>
        </div>
      </div>

      {categories.map((cat) => {
        const catTools = getToolsByCategory(cat.slug);
        return (
          <section key={cat.slug} className="section-pad" id={cat.slug}>
            <div className="explorer-head">
              <div>
                <h2 style={{ fontSize: 22, display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span className="tool-icon" style={{ width: 34, height: 34, borderRadius: 9, marginBottom: 0, background: `var(--${cat.accent})` }}>
                    <Icon name={cat.icon} size={17} />
                  </span>
                  {cat.name} <span style={{ color: 'var(--brand-primary-hover)' }}>({catTools.length})</span>
                </h2>
                <p className="explorer-sub">{cat.description}</p>
              </div>
              <Link href={`/tools/${cat.slug}`} className="btn btn-ghost btn-sm">View category <Icon name="arrow-right" size={13} /></Link>
            </div>
            <div className="tool-grid">
              {catTools.map((t) => <ToolCard key={t.slug} tool={t} />)}
            </div>
          </section>
        );
      })}
    </div>
  );
}
