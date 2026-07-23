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

export interface HowToStep {
  name: string;
  text: string;
}

/**
 * Per-tool SEO overrides, resolved from the data layer (`data/seo-content.ts`).
 * Every field is optional — anything omitted falls back to the generated default,
 * so a tool with no override still ships a complete, valid metadata + schema set.
 */
export interface ToolSeoOverride {
  title?: string;
  description?: string;
  keywords?: string[];
  ogSubtitle?: string;
  faq?: Faq[];
  howTo?: HowToStep[];
  trustExtra?: string;
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

/**
 * Locales the site is (or will be) served in. English only today; add entries
 * here once locale-prefixed routes exist and every page automatically emits the
 * matching hreflang alternates. `x-default` is added by `languageAlternates`.
 */
export const LOCALES = ['en'] as const;
export type Locale = (typeof LOCALES)[number];

/**
 * hreflang alternates for a canonical URL — multi-language SEO readiness.
 * Today every locale maps to the same URL (single-language site); when locale
 * routes land, change the mapping to `${SITE.url}/${loc}/...` and nothing else
 * needs to change. Returns a Next `alternates.languages` object incl. x-default.
 */
export function languageAlternates(canonical: string): Record<string, string> {
  const langs: Record<string, string> = { 'x-default': canonical };
  for (const loc of LOCALES) langs[loc] = canonical;
  return langs;
}

/**
 * Reusable BreadcrumbList JSON-LD node. Centralising this keeps every page's
 * breadcrumb schema identical and lets the visual <Breadcrumb> component stay
 * presentation-only (no duplicate structured data).
 */
export function breadcrumbJsonLd(items: Array<{ name: string; url: string }>): object {
  return {
    '@type': 'BreadcrumbList',
    itemListElement: items.map((it, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: it.name,
      item: it.url,
    })),
  };
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

/**
 * Full rich metadata for ANY tool — the default for all 140+ tools.
 * Pass a `seo` override (from `data/seo-content.ts`) to supply a hand-tuned
 * title, description, keyword set or OG subtitle for a specific tool.
 */
export function toolMetadata(tool: Tool, cat?: Category, seo?: ToolSeoOverride): Metadata {
  const title = seo?.title ?? toolTitle(tool, cat);
  const description = seo?.description ?? toolDescription(tool);
  const url = toolUrl(tool);
  const img = ogImage({ title: tool.name, subtitle: seo?.ogSubtitle ?? cat?.name ?? SITE.tagline, badge: badgeLabel(tool) });
  return {
    // `absolute` prevents the root layout's "%s | Farvixo Tools" template from
    // double-appending the brand (title already ends in "| Farvixo Tools").
    title: { absolute: title },
    description,
    keywords: seo?.keywords ?? toolKeywords(tool, cat),
    alternates: { canonical: url, languages: languageAlternates(url) },
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

/**
 * Category-aware default HowTo steps (feeds the HowTo rich-result schema and the
 * on-page "How It Works" section) for tools without a hand-written set.
 */
export function defaultHowTo(tool: Tool, _cat?: Category): HowToStep[] {
  const n = tool.name;
  const hasFile = Boolean(tool.accept);
  return [
    {
      name: hasFile ? 'Upload your file' : 'Enter your input',
      text: hasFile
        ? `Drag & drop your file into ${n} or click to browse. Nothing is uploaded to a server — everything stays on your device.`
        : `Type or paste your input into ${n}. Everything stays on your device.`,
    },
    {
      name: 'Choose your options',
      text: `Pick your settings and click the action button. ${n} processes everything instantly and locally in your browser.`,
    },
    {
      name: 'Download the result',
      text: hasFile
        ? `Download your result instantly. Run ${n} again as many times as you like — free forever, no watermark.`
        : `Copy or download your result immediately. Use ${n} as many times as you like — free forever.`,
    },
  ];
}

/** SoftwareApplication + HowTo + FAQPage + BreadcrumbList graph for a tool page. */
export function toolJsonLd(
  tool: Tool,
  cat: Category | undefined,
  faq: Faq[],
  opts?: { howTo?: HowToStep[]; description?: string },
): object {
  const url = toolUrl(tool);
  const description = opts?.description ?? toolDescription(tool);
  const howTo = opts?.howTo ?? [];
  const graph: object[] = [
    {
      '@type': 'SoftwareApplication',
      '@id': `${url}#app`,
      name: tool.name,
      url,
      applicationCategory: 'UtilitiesApplication',
      operatingSystem: 'Web',
      description,
      image: ogImage({ title: tool.name, subtitle: cat?.name ?? SITE.tagline, badge: badgeLabel(tool) }),
      inLanguage: 'en',
      isAccessibleForFree: true,
      keywords: toolKeywords(tool, cat).join(', '),
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
      provider: { '@type': 'Organization', name: SITE.name, url: SITE.url },
    },
  ];

  if (howTo.length > 0) {
    graph.push({
      '@type': 'HowTo',
      '@id': `${url}#howto`,
      name: `How to use ${tool.name}`,
      description,
      totalTime: 'PT1M',
      step: howTo.map((s, i) => ({
        '@type': 'HowToStep',
        position: i + 1,
        name: s.name,
        text: s.text,
        url: `${url}#step-${i + 1}`,
      })),
    });
  }

  graph.push(
    {
      '@type': 'FAQPage',
      '@id': `${url}#faq`,
      mainEntity: faq.map((f) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a },
      })),
    },
    breadcrumbJsonLd([
      { name: 'Home', url: SITE.url },
      { name: cat?.name ?? 'Tools', url: cat ? categoryUrl(cat) : `${SITE.url}/tools` },
      { name: tool.name, url },
    ]),
  );

  return { '@context': 'https://schema.org', '@graph': graph };
}

/** Rich metadata for a category landing page. */
export function categoryMetadata(cat: Category, count: number): Metadata {
  const title = `${cat.name} — ${count}+ Free Online ${cat.shortName} Tools | Farvixo Tools`;
  const description = truncate(`${cat.description} ${count}+ free ${cat.shortName.toLowerCase()} tools — fast, private and browser-based. No sign-up, no watermark.`);
  const url = categoryUrl(cat);
  const img = ogImage({ title: cat.name, subtitle: `${count}+ free tools`, badge: cat.shortName });
  return {
    // `absolute` — title already carries the brand; avoid template double-suffix.
    title: { absolute: title },
    description,
    keywords: [
      cat.name.toLowerCase(), `${cat.shortName.toLowerCase()} tools`, `free ${cat.shortName.toLowerCase()} tools`,
      `online ${cat.shortName.toLowerCase()} tools`, 'free online tools', 'farvixo', 'farvixo tools',
    ],
    alternates: { canonical: url, languages: languageAlternates(url) },
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
      breadcrumbJsonLd([
        { name: 'Home', url: SITE.url },
        { name: 'All Tools', url: `${SITE.url}/tools` },
        { name: cat.name, url },
      ]),
    ],
  };
}

/**
 * Relevance-scored related-tools engine. Ranks by shared keywords, same
 * category, name-token overlap and badge/popularity, then falls back to
 * cross-category tools so every page fills all `limit` slots. Deterministic
 * (stable tie-break on id) so static builds are reproducible.
 */
export function getRelatedTools(tool: Tool, all: Tool[], limit = 6): Tool[] {
  const kw = new Set((tool.keywords ?? []).map((k) => k.toLowerCase()));
  const nameTokens = new Set(tool.name.toLowerCase().split(/\W+/).filter((t) => t.length > 3));

  const scored = all
    .filter((t) => t.slug !== tool.slug)
    .map((t) => {
      let score = 0;
      if (t.category === tool.category) score += 5;
      for (const k of (t.keywords ?? [])) if (kw.has(k.toLowerCase())) score += 3;
      for (const tok of t.name.toLowerCase().split(/\W+/)) if (tok.length > 3 && nameTokens.has(tok)) score += 1;
      if (t.badge === 'popular') score += 2;
      else if (t.badge) score += 1;
      return { t, score };
    })
    .sort((a, b) => b.score - a.score || a.t.id - b.t.id);

  return scored.slice(0, limit).map((s) => s.t);
}

/* ─────────────────────────────────────────────────────────────────────────
 * Static / content page helpers — one code path for every non-tool page
 * (home, about, contact, blog, legal, help…). All reuse SITE, ogImage,
 * languageAlternates and breadcrumbJsonLd above, so there is no duplication.
 * ───────────────────────────────────────────────────────────────────────── */

export function pageUrl(path: string): string {
  return path === '/' ? SITE.url : `${SITE.url}${path.startsWith('/') ? path : `/${path}`}`;
}

/** Append the brand once — skips pages whose title already says "Farvixo". */
export function brandTitle(title: string): string {
  return /farvixo/i.test(title) ? title : `${title} | ${SITE.name}`;
}

export interface PageMetaInput {
  /** Brand-less, concise title (≤~45 chars keeps the branded title ≤60). */
  title: string;
  description: string;
  /** Route path, e.g. '/about' (or '/' for home). */
  path: string;
  keywords?: string[];
  ogSubtitle?: string;
  ogBadge?: string;
  /** Set false for thin/util pages you don't want indexed. Default true. */
  index?: boolean;
}

/** Full metadata for any static page — canonical, hreflang, OG, Twitter. */
export function pageMetadata(input: PageMetaInput): Metadata {
  const url = pageUrl(input.path);
  const title = brandTitle(input.title);
  const img = ogImage({ title: input.title, subtitle: input.ogSubtitle ?? SITE.tagline, badge: input.ogBadge });
  return {
    title: { absolute: title },
    description: input.description,
    ...(input.keywords ? { keywords: input.keywords } : {}),
    alternates: { canonical: url, languages: languageAlternates(url) },
    openGraph: {
      type: 'website', url, siteName: SITE.name, title, description: input.description, locale: SITE.locale,
      images: [{ url: img, width: 1200, height: 630, alt: title }],
    },
    twitter: { card: 'summary_large_image', title, description: input.description, images: [img], creator: SITE.twitter },
    robots: input.index === false
      ? { index: false, follow: true }
      : { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 },
  };
}

/** WebPage-family JSON-LD graph (WebPage/AboutPage/ContactPage/CollectionPage…). */
export function webPageJsonLd(opts: {
  type?: string;
  name: string;
  description: string;
  path: string;
  breadcrumb?: Array<{ name: string; url: string }>;
  extra?: object[];
}): object {
  const url = pageUrl(opts.path);
  const graph: object[] = [
    {
      '@type': opts.type ?? 'WebPage',
      '@id': `${url}#page`,
      name: opts.name,
      url,
      description: opts.description,
      isPartOf: { '@type': 'WebSite', name: SITE.name, url: SITE.url },
    },
  ];
  // Auto-build a Home → page trail when the caller doesn't supply one.
  const crumbs = opts.breadcrumb ?? [{ name: 'Home', url: SITE.url }, { name: opts.name, url }];
  graph.push(breadcrumbJsonLd(crumbs));
  if (opts.extra) graph.push(...opts.extra);
  return { '@context': 'https://schema.org', '@graph': graph };
}

/** Standalone FAQPage node — for the homepage / help FAQ (not tool pages). */
export function faqJsonLd(faq: Faq[]): object {
  return {
    '@type': 'FAQPage',
    mainEntity: faq.map((f) => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  };
}

/* ── Blog ─────────────────────────────────────────────────────────────── */

export interface BlogPostMeta {
  slug: string;
  title: string;
  category: string;
  excerpt: string;
  /** ISO 8601, e.g. '2025-06-15'. */
  published: string;
  updated?: string;
  author?: string;
  keywords?: string[];
}

export function blogUrl(slug: string): string {
  return `${SITE.url}/blog/${slug}`;
}

/** Metadata for a single blog post — Article OG + canonical + hreflang. */
export function articleMetadata(post: BlogPostMeta): Metadata {
  const url = blogUrl(post.slug);
  const title = brandTitle(post.title);
  const img = ogImage({ title: post.title, subtitle: `${post.category} · Farvixo Blog`, badge: post.category });
  return {
    title: { absolute: title },
    description: post.excerpt,
    ...(post.keywords ? { keywords: post.keywords } : {}),
    alternates: { canonical: url, languages: languageAlternates(url) },
    openGraph: {
      type: 'article', url, siteName: SITE.name, title, description: post.excerpt, locale: SITE.locale,
      publishedTime: post.published, modifiedTime: post.updated ?? post.published,
      authors: [post.author ?? 'Farvixo Technologies'],
      images: [{ url: img, width: 1200, height: 630, alt: post.title }],
    },
    twitter: { card: 'summary_large_image', title, description: post.excerpt, images: [img], creator: SITE.twitter },
  };
}

/** BlogPosting + BreadcrumbList graph for a single blog post. */
export function articleJsonLd(post: BlogPostMeta): object {
  const url = blogUrl(post.slug);
  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'BlogPosting',
        '@id': `${url}#article`,
        headline: post.title,
        description: post.excerpt,
        datePublished: post.published,
        dateModified: post.updated ?? post.published,
        author: { '@type': 'Organization', name: post.author ?? 'Farvixo Technologies', url: SITE.url },
        publisher: {
          '@type': 'Organization',
          name: SITE.name,
          url: SITE.url,
          logo: { '@type': 'ImageObject', url: `${SITE.url}/farvixo-logo.svg` },
        },
        image: ogImage({ title: post.title, subtitle: `${post.category} · Farvixo Blog`, badge: post.category }),
        mainEntityOfPage: url,
        articleSection: post.category,
        inLanguage: 'en',
        url,
      },
      breadcrumbJsonLd([
        { name: 'Home', url: SITE.url },
        { name: 'Blog', url: `${SITE.url}/blog` },
        { name: post.title, url },
      ]),
    ],
  };
}
