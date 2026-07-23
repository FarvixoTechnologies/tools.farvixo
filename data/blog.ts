import type { BlogPostMeta } from '@/lib/seo';

/**
 * Single source of truth for blog posts — consumed by both the blog index
 * (`app/blog/page.tsx`) and individual posts (`app/blog/[slug]/page.tsx`), so
 * the list is never duplicated. `BlogPost` extends the SEO `BlogPostMeta` shape
 * that `articleMetadata` / `articleJsonLd` consume, plus the page body.
 */
export interface BlogPost extends BlogPostMeta {
  /** Human-readable date shown on the page (ISO `published` drives schema). */
  displayDate: string;
  body: string[];
}

export const posts: BlogPost[] = [
  {
    slug: 'compress-pdf-without-quality-loss',
    title: 'How to Compress a PDF Without Losing Quality',
    category: 'PDF',
    published: '2025-06-15',
    displayDate: 'June 15, 2025',
    author: 'Farvixo Technologies',
    excerpt: 'Reduce PDF file size for email and uploads while keeping text crisp — free, in your browser, with preset targets for Aadhaar and passport documents.',
    keywords: ['compress pdf', 'reduce pdf size', 'pdf compressor', 'aadhaar pdf size'],
    body: [
      "Large PDF files slow down email, uploads and storage. Farvixo's PDF Compressor reduces file size while preserving readability.",
      'Upload your PDF, adjust the quality slider (higher = better quality, larger file), and click Compress. Processing runs entirely in your browser.',
      'For government uploads (Aadhaar, passport), use our Aadhaar PDF Compressor with preset size targets.',
    ],
  },
  {
    slug: 'best-ai-writing-tools-2025',
    title: '10 Best AI Writing Tools in 2025',
    category: 'AI',
    published: '2025-06-08',
    displayDate: 'June 8, 2025',
    author: 'Farvixo Technologies',
    excerpt: 'The AI writing tools worth using in 2025 — and how Farvixo bundles AI Writer, Email Writer and SEO Writer into one platform with shared context.',
    keywords: ['ai writing tools', 'ai writer', 'best ai tools 2025'],
    body: [
      'AI writing tools have become essential for content creators, marketers and students. Farvixo Tools bundles AI Writer, Email Writer, SEO Writer and more in one platform.',
      'Unlike standalone apps, Farvixo Tools gives you one AI brain across every tool — your context follows you from writing to PDF export.',
    ],
  },
  {
    slug: 'passport-photo-requirements-india',
    title: 'Passport Photo Requirements for India (2025 Guide)',
    category: 'Government',
    published: '2025-05-28',
    displayDate: 'May 28, 2025',
    author: 'Farvixo Technologies',
    excerpt: 'Exact Indian passport photo specs — 35×45 mm, white background, under 200KB — and how to meet them free with the Farvixo Passport Photo Maker.',
    keywords: ['passport photo india', 'passport photo size', 'passport photo maker'],
    body: [
      'Indian passport photos must be 35×45 mm (413×531 px at 300 DPI), white background, face centered, file size under 200KB.',
      "Use Farvixo's Passport Photo Maker with the India preset — it crops, resizes and compresses automatically.",
    ],
  },
  {
    slug: 'remove-background-free',
    title: 'Remove Image Backgrounds for Free — Complete Guide',
    category: 'Image',
    published: '2025-05-20',
    displayDate: 'May 20, 2025',
    author: 'Farvixo Technologies',
    excerpt: 'Remove image backgrounds free with an AI model that runs in your browser — no uploads — plus tips for clean product photos and custom scenes.',
    keywords: ['remove background', 'background remover', 'transparent png'],
    body: [
      "Farvixo's Background Remover uses an AI model running in your browser via WASM. No upload to external servers.",
      'For product photos, pair it with Background Changer to place items on custom colors or scenes.',
    ],
  },
  {
    slug: 'seo-checklist-2025',
    title: 'On-Page SEO Checklist for 2025',
    category: 'SEO',
    published: '2025-05-12',
    displayDate: 'May 12, 2025',
    author: 'Farvixo Technologies',
    excerpt: 'A practical on-page SEO checklist for 2025 — title tags, meta descriptions, headings and JSON-LD — with the free Farvixo tools to get each right.',
    keywords: ['on-page seo', 'seo checklist 2025', 'meta tags', 'schema markup'],
    body: [
      'Start with a unique title tag (≤60 chars), meta description (≤155 chars), and one H1 per page.',
      "Use Farvixo's SEO Analyzer to audit any URL, Meta Tag Generator for snippets, and Schema Markup Generator for JSON-LD.",
    ],
  },
];

export function getPost(slug: string): BlogPost | undefined {
  return posts.find((p) => p.slug === slug);
}

/** Related posts: same category first, then most-recent others; excludes self. */
export function getRelatedPosts(post: BlogPost, limit = 3): BlogPost[] {
  const others = posts.filter((p) => p.slug !== post.slug);
  const sameCat = others.filter((p) => p.category === post.category);
  const rest = others.filter((p) => p.category !== post.category);
  return [...sameCat, ...rest].slice(0, limit);
}
