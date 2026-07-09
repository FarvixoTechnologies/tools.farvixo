import type { Metadata } from 'next';
import type { Tool } from '@/data/tools';
import type { Category } from '@/data/categories';

/** Single source of truth for site-wide SEO constants. */
export const SITE = {
  url: 'https://tools.farvixo.com',
  name: 'Farvixo Tools',
  tagline: 'Build Beyond.',
  twitter: '@farvixo',
  locale: 'en_US',
} as const;

export interface Faq {
  q: string;
  a: string;
}

function truncate(text: string, max = 158): string {
  if (text.length <= max) return text;
  return text.slice(0, max - 1).replace(/\s+\S*$/, '').trim() + '…';
}

function badgeLabel(tool: Pick<Tool, 'badge'>): string {
  if (tool.badge === 'ai') return 'AI';
  if (tool.badge === 'new') return 'NEW';
  if (tool.badge === 'popular') return 'POPULAR';
  return '';
}

export function toolUrl(tool: Pick<Tool, 'category' | 'slug'>): string {
  return `${SITE.url}/tools/${tool.category}/${tool.slug}`;
}

export function categoryUrl(cat: Pick<Category, 'slug'>): string {
  return `${SITE.url}/tools/${cat.slug}`;
}

/** Branded 1200x630 preview generated on the fly by /api/og. */
export function ogImage(params: { title: string; subtitle?: string; badge?: string }): string {
  const q = new URLSearchParams({ title: params.title });
  if (params.subtitle) q.set('subtitle', params.subtitle);
  if (params.badge) q.set('badge', params.badge);
  return `${SITE.url}/api/og?${q.toString()}`;
}

/** De-duplicated keyword set derived from the tool + its category. */
export function toolKeywords(tool: Tool, cat?: Category): string[] {
  const kw = new Set<string>();
  const n = tool.name.toLowerCase();
  (tool.keywords ?? []).forEach((k) => kw.add(k.toLowerCase()));
  kw.add(n);
  kw.add(`free ${n}`);
  kw.add(`${n} online`);
  kw.add(`${n} free`);
  if (cat) {
    kw.add(cat.name.toLowerCase());
    kw.add(`${cat.shortName.toLowerCase()} tools`);
    kw.add(`online ${cat.shortName.toLowerCase()} tools`);
  }
  kw.add('free online tools');
  kw.add('farvixo');
  kw.add('farvixo tools');
  return [...kw].slice(0, 25);
}

export function toolTitle(tool: Tool, cat?: Category): string {
  return `${tool.name} — Free Online ${cat?.shortName ?? 'Web'} Tool | Farvixo Tools`;
}

export function toolDescription(tool: Tool): string {
  const core = tool.description.replace(/\s*[—–-]\s*(100% private|free.*|no api key.*|no signup.*)$/i, '').trim();
  return truncate(`${core}. Free, fast & 100% private — runs in your browser. No sign-up, no watermark, unlimited use.`);
}

/** Full rich metadata for ANY tool — used as the default for all 139+ tools. */
export function toolMetadata(tool: Tool, cat?: Category): Metadata {
  const title = toolTitle(tool, cat);
  const description = toolDescription(tool);
  const url = toolUrl(tool);
  const img = ogImage({ title: tool.name, subtitle: cat?.name ?? SITE.tagline, badge: badgeLabel(tool) });
  return {
    title,
    description,
    keywords: toolKeywords(tool, cat),
    alternates: { canonical: url },
    openGraph: {
      type: 'website',
      url,
      siteName: SITE.name,
      title,
      description,
      locale: SITE.locale,
      images: [{ url: img, width: 1200, height: 630, alt: `${tool.name} — Farvixo Tools` }],
    },
    twitter: { card: 'summary_large_image', title, description, images: [img], creator: SITE.twitter },
    robots: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 },
  };
}

/** Category-aware default FAQ (feeds the FAQPage rich-result schema) for tools without a hand-written set. */
export function defaultToolFaq(tool: Tool, cat?: Category): Faq[] {
  const n = tool.name;
  const hasFile = Boolean(tool.accept);
  const thing = hasFile ? 'files' : 'data';
  return [
    { q: `Is ${n} free to use?`, a: `Yes — ${n} on Farvixo Tools is completely free with no sign-up, no watermarks and no hidden limits. Use it as many times as you like.` },
    { q: `How do I use ${n}?`, a: `${hasFile ? `Upload your file, choose your options, and download the result instantly` : `Enter your input, pick any options, and get your result instantly`} — everything runs right in your browser.` },
    { q: `Is ${n} safe and private?`, a: `Yes. Wherever technically possible, ${n} processes everything locally in your browser, so your ${thing} never leave your device. No uploads, no data collection.` },
    { q: `Do I need to install anything to use ${n}?`, a: `No. ${n} works in any modern web browser on desktop, tablet and mobile — no downloads, no extensions and no account required.` },
    { q: `Does ${n} work on mobile?`, a: `Yes — ${n} is fully responsive and works on Android and iPhone exactly like it does on desktop.` },
    { q: hasFile ? `Is there a file size limit for ${n}?` : `Can I use ${n} as many times as I want?`, a: hasFile ? `Because processing happens locally, the practical limit is your device memory — files up to a few hundred MB usually work smoothly.` : `Yes — ${n} is unlimited and free forever. Run it as many times as you need.` },
  ];
}

/** SoftwareApplication + FAQPage + BreadcrumbList graph for a tool page. */
export function toolJsonLd(tool: Tool, cat: Category | undefined, faq: Faq[]): object {
  const url = toolUrl(tool);
  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'SoftwareApplication',
        '@id': `${url}#app`,
        name: tool.name,
        url,
        applicationCategory: 'UtilitiesApplication',
        operatingSystem: 'Web',
        description: toolDescription(tool),
        image: ogImage({ title: tool.name, subtitle: cat?.name ?? SITE.tagline, badge: badgeLabel(tool) }),
        inLanguage: 'en',
        isAccessibleForFree: true,
        keywords: toolKeywords(tool, cat).join(', '),
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
        provider: { '@type': 'Organization', name: SITE.name, url: SITE.url },
      },
      {
        '@type': 'FAQPage',
        '@id': `${url}#faq`,
        mainEntity: faq.map((f) => ({
          '@type': 'Question',
          name: f.q,
          acceptedAnswer: { '@type': 'Answer', text: f.a },
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Home', item: SITE.url },
          { '@type': 'ListItem', position: 2, name: cat?.name ?? 'Tools', item: cat ? categoryUrl(cat) : `${SITE.url}/tools` },
          { '@type': 'ListItem', position: 3, name: tool.name, item: url },
        ],
      },
    ],
  };
}

/** Rich metadata for a category landing page. */
export function categoryMetadata(cat: Category, count: number): Metadata {
  const title = `${cat.name} — ${count}+ Free Online ${cat.shortName} Tools | Farvixo Tools`;
  const description = truncate(`${cat.description} ${count}+ free ${cat.shortName.toLowerCase()} tools — fast, private and browser-based. No sign-up, no watermark.`);
  const url = categoryUrl(cat);
  const img = ogImage({ title: cat.name, subtitle: `${count}+ free tools`, badge: cat.shortName });
  return {
    title,
    description,
    keywords: [
      cat.name.toLowerCase(), `${cat.shortName.toLowerCase()} tools`, `free ${cat.shortName.toLowerCase()} tools`,
      `online ${cat.shortName.toLowerCase()} tools`, 'free online tools', 'farvixo', 'farvixo tools',
    ],
    alternates: { canonical: url },
    openGraph: {
      type: 'website', url, siteName: SITE.name, title, description, locale: SITE.locale,
      images: [{ url: img, width: 1200, height: 630, alt: `${cat.name} — Farvixo Tools` }],
    },
    twitter: { card: 'summary_large_image', title, description, images: [img], creator: SITE.twitter },
    robots: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 },
  };
}

/** CollectionPage + ItemList + BreadcrumbList graph for a category page. */
export function categoryJsonLd(cat: Category, catTools: Tool[]): object {
  const url = categoryUrl(cat);
  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'CollectionPage',
        '@id': `${url}#page`,
        name: `${cat.name} — Farvixo Tools`,
        url,
        description: cat.description,
        isPartOf: { '@type': 'WebSite', name: SITE.name, url: SITE.url },
      },
      {
        '@type': 'ItemList',
        '@id': `${url}#tools`,
        numberOfItems: catTools.length,
        itemListElement: catTools.map((t, i) => ({
          '@type': 'ListItem',
          position: i + 1,
          name: t.name,
          url: toolUrl(t),
        })),
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Home', item: SITE.url },
          { '@type': 'ListItem', position: 2, name: 'All Tools', item: `${SITE.url}/tools` },
          { '@type': 'ListItem', position: 3, name: cat.name, item: url },
        ],
      },
    ],
  };
}
