import { describe, it, expect } from 'vitest';
import { tools, type Tool } from '@/data/tools';
import { categories, getCategory } from '@/data/categories';
import { toolSeoContent, getToolSeo } from '@/data/seo-content';
import {
  toolMetadata,
  toolJsonLd,
  categoryMetadata,
  categoryJsonLd,
  defaultToolFaq,
  defaultHowTo,
  getRelatedTools,
  languageAlternates,
  toolUrl,
} from '@/lib/seo';

/* Helpers mirroring the tool page's resolution order. */
function faqFor(t: Tool) {
  const cat = getCategory(t.category);
  return getToolSeo(t.slug)?.faq ?? defaultToolFaq(t, cat);
}
function howToFor(t: Tool) {
  const cat = getCategory(t.category);
  return getToolSeo(t.slug)?.howTo ?? defaultHowTo(t, cat);
}
function graphOf(t: Tool): any[] {
  const cat = getCategory(t.category);
  const jsonLd = toolJsonLd(t, cat, faqFor(t), { howTo: howToFor(t), description: getToolSeo(t.slug)?.description }) as any;
  return jsonLd['@graph'];
}
const nodeOf = (t: Tool, type: string) => graphOf(t).find((n) => n['@type'] === type);

describe('tool metadata — every tool', () => {
  it.each(tools.map((t) => [t.slug, t] as const))('%s has valid metadata', (_slug, t) => {
    const cat = getCategory(t.category);
    const m = toolMetadata(t, cat, getToolSeo(t.slug)) as any;
    const title: string = m.title.absolute; // set via { absolute } to avoid template double-suffix
    expect(typeof title).toBe('string');
    expect(title.length).toBeGreaterThan(10);
    expect(title.endsWith('Farvixo Tools')).toBe(true);
    expect(typeof m.description).toBe('string');
    expect(m.description.length).toBeGreaterThan(50);
    expect(m.description.length).toBeLessThanOrEqual(260); // length ideals are advisory; Google truncates
    expect(m.alternates.canonical).toBe(toolUrl(t));
    expect(m.alternates.languages['x-default']).toBe(toolUrl(t));
    expect(Array.isArray(m.keywords)).toBe(true);
    expect(m.openGraph.images[0].url).toContain('/api/og');
    expect(m.twitter.card).toBe('summary_large_image');
  });
});

describe('tool JSON-LD structured data — every tool', () => {
  it.each(tools.map((t) => [t.slug, t] as const))('%s emits a valid @graph', (_slug, t) => {
    // Serialisable (no cycles / undefined keys that break JSON.stringify).
    expect(() => JSON.stringify(toolJsonLd(t, getCategory(t.category), faqFor(t), { howTo: howToFor(t) }))).not.toThrow();

    const app = nodeOf(t, 'SoftwareApplication');
    expect(app).toBeTruthy();
    expect(app.name).toBe(t.name);
    expect(app.offers.price).toBe('0');
    expect(app.isAccessibleForFree).toBe(true);

    const howto = nodeOf(t, 'HowTo');
    expect(howto).toBeTruthy();
    expect(howto.step.length).toBeGreaterThanOrEqual(2);
    howto.step.forEach((s: any, i: number) => {
      expect(s['@type']).toBe('HowToStep');
      expect(s.position).toBe(i + 1);
      expect(s.name && s.text).toBeTruthy();
    });

    const faq = nodeOf(t, 'FAQPage');
    expect(faq.mainEntity.length).toBeGreaterThanOrEqual(3);
    faq.mainEntity.forEach((q: any) => {
      expect(q['@type']).toBe('Question');
      expect(q.acceptedAnswer.text.length).toBeGreaterThan(0);
    });

    const bc = nodeOf(t, 'BreadcrumbList');
    expect(bc.itemListElement).toHaveLength(3);
    bc.itemListElement.forEach((li: any, i: number) => expect(li.position).toBe(i + 1));
  });
});

describe('category metadata + JSON-LD — every category', () => {
  it.each(categories.map((c) => [c.slug, c] as const))('%s is valid', (_slug, c) => {
    const m = categoryMetadata(c, 10) as any;
    expect(m.title.absolute).toContain(c.shortName);
    expect(m.alternates.languages['x-default']).toBe(m.alternates.canonical);

    const g = (categoryJsonLd(c, tools.filter((t) => t.category === c.slug)) as any)['@graph'];
    expect(g.find((n: any) => n['@type'] === 'CollectionPage')).toBeTruthy();
    const list = g.find((n: any) => n['@type'] === 'ItemList');
    expect(list.numberOfItems).toBe(tools.filter((t) => t.category === c.slug).length);
    expect(g.find((n: any) => n['@type'] === 'BreadcrumbList')).toBeTruthy();
  });
});

describe('related-tools engine', () => {
  it('returns up to N, never includes self, is deterministic', () => {
    for (const t of tools.slice(0, 40)) {
      const r1 = getRelatedTools(t, tools, 6);
      const r2 = getRelatedTools(t, tools, 6);
      expect(r1.length).toBeLessThanOrEqual(6);
      expect(r1.every((x) => x.slug !== t.slug)).toBe(true);
      expect(r1.map((x) => x.slug)).toEqual(r2.map((x) => x.slug)); // deterministic
    }
  });
  it('prefers same-category tools when enough exist', () => {
    const pdf = tools.find((t) => t.slug === 'merge-pdf')!;
    const related = getRelatedTools(pdf, tools, 6);
    const sameCat = related.filter((t) => t.category === 'pdf').length;
    expect(sameCat).toBeGreaterThanOrEqual(3);
  });
});

describe('seo-content overrides integrity', () => {
  it('every override key maps to a real tool', () => {
    const slugs = new Set(tools.map((t) => t.slug));
    for (const slug of Object.keys(toolSeoContent)) expect(slugs.has(slug)).toBe(true);
  });
  it('override faq/howTo entries are well-formed', () => {
    for (const [slug, seo] of Object.entries(toolSeoContent)) {
      seo.faq?.forEach((f) => {
        expect(f.q.length, `${slug} q`).toBeGreaterThan(0);
        expect(f.a.length, `${slug} a`).toBeGreaterThan(0);
      });
      seo.howTo?.forEach((s) => {
        expect(s.name.length, `${slug} step name`).toBeGreaterThan(0);
        expect(s.text.length, `${slug} step text`).toBeGreaterThan(0);
      });
      if (seo.title) expect(seo.title.length).toBeLessThanOrEqual(120);
    }
  });
});

describe('hreflang readiness', () => {
  it('always includes x-default', () => {
    const langs = languageAlternates('https://tools.farvixo.com/tools/pdf/merge-pdf');
    expect(langs['x-default']).toBeTruthy();
    expect(langs.en).toBeTruthy();
  });
});
