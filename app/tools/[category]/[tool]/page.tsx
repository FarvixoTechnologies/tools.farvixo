import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Icon from '@/components/Icon';
import ToolCard from '@/components/ToolCard';
import Breadcrumb from '@/components/Breadcrumb';
import FaqSection from '@/components/FaqSection';
import ToolRunner from '@/components/tool/ToolRunner';
import ToolUsageStat from '@/components/tool/ToolUsageStat';
import FeatureStrip from '@/components/homepage/FeatureStrip';
import { ToolMidAd, ToolPreFooterAd, ToolSidebarAd, ToolSmartlink } from '@/components/ads/ToolPageAds';
import { getCategory, type Category } from '@/data/categories';
import { getTool, tools, type Tool } from '@/data/tools';
import { getToolSeo } from '@/data/seo-content';
import { toolMetadata, defaultToolFaq, defaultHowTo, toolJsonLd, getRelatedTools, type Faq, type HowToStep } from '@/lib/seo';

interface Props { params: Promise<{ category: string; tool: string }> }

export function generateStaticParams() {
  return tools.map((t) => ({ category: t.category, tool: t.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { tool: slug } = await params;
  const tool = getTool(slug);
  if (!tool) return {};
  const cat = getCategory(tool.category);
  // All per-tool overrides live in data/seo-content.ts — anything omitted there
  // falls back to the generated default, so every tool gets complete metadata.
  return toolMetadata(tool, cat, getToolSeo(slug));
}

/** FAQ for a tool: hand-tuned set from data/seo-content.ts, else generated default. */
function buildFaq(tool: Tool, cat?: Category): Faq[] {
  return getToolSeo(tool.slug)?.faq ?? defaultToolFaq(tool, cat);
}

/** HowTo steps: hand-tuned set from data/seo-content.ts, else generated default. */
function buildHowTo(tool: Tool, cat?: Category): HowToStep[] {
  return getToolSeo(tool.slug)?.howTo ?? defaultHowTo(tool, cat);
}

/** Trust-row highlight: hand-tuned from data/seo-content.ts, else generic default. */
function getTrustExtra(slug: string): string {
  return getToolSeo(slug)?.trustExtra ?? 'Runs in your browser';
}

export default async function ToolPage({ params }: Props) {
  const { tool: slug } = await params;
  const tool = getTool(slug);
  if (!tool) notFound();
  const cat = getCategory(tool.category);
  const related = getRelatedTools(tool, tools, 6);
  const seo = getToolSeo(slug);
  const faq = buildFaq(tool, cat);
  const howTo = buildHowTo(tool, cat);
  const trustExtra = getTrustExtra(slug);

  const jsonLd = toolJsonLd(tool, cat, faq, { howTo, description: seo?.description });

  return (
    <div className="container" style={{ paddingBottom: 64 }}>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <Breadcrumb
        items={[
          { name: 'Home', href: '/' },
          { name: cat?.name ?? 'Tools', href: `/tools/${tool.category}` },
          { name: tool.name },
        ]}
      />

      <div className="tool-header">
        <span className="tool-header-icon" style={{ background: `var(--${cat?.accent || 'brand-primary'})` }}>
          <Icon name={tool.icon} size={28} />
        </span>
        <div>
          <h1>{tool.name}</h1>
          <p>{tool.description}</p>
        </div>
      </div>
      <div className="trust-row">
        <ToolUsageStat slug={tool.slug} />
        <span>&middot;</span>
        <span>&#128274; 100% Secure &amp; Private</span>
        <span>&middot;</span>
        <span>&#9889; {trustExtra}</span>
      </div>

      <div className={`tool-page-layout${slug === 'html-viewer' ? ' tool-page-layout-wide' : ''}`}>
        <div className="tool-page-main">
          <div className="workspace glass">
            <ToolRunner tool={tool} />
          </div>
          {/* Ad 2 — below primary action (728×90 desktop) */}
          <ToolMidAd />
        </div>
        {/* Desktop right sidebar ad (300×250) — hidden for full-width IDE tools */}
        {slug !== 'html-viewer' && <ToolSidebarAd />}
      </div>

      <h2 className="hiw-title">How to use {tool.name}</h2>
      <section className="hiw">
        {howTo.map((s, i) => (
          <div key={s.name} id={`step-${i + 1}`} className="hiw-step glass">
            <span className="hiw-num">{i + 1}</span>
            <b>{s.name}</b>
            <p>{s.text}</p>
          </div>
        ))}
      </section>

      <FaqSection items={faq} />

      {related.length > 0 && (
        <section className="related">
          <div className="related-head">
            <h2>Related Tools</h2>
            <ToolSmartlink />
          </div>
          <div className="tool-grid">
            {related.map((t) => <ToolCard key={t.slug} tool={t} />)}
          </div>
        </section>
      )}

      {/* Ad 3 — before footer (desktop 300×250, mobile 320×50) */}
      <ToolPreFooterAd />

      <FeatureStrip />
    </div>
  );
}
