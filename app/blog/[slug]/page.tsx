import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import PageShell from '@/components/content/PageShell';

const posts: Record<string, { title: string; category: string; date: string; body: string[] }> = {
  'compress-pdf-without-quality-loss': {
    title: 'How to Compress a PDF Without Losing Quality',
    category: 'PDF',
    date: 'June 15, 2025',
    body: [
      'Large PDF files slow down email, uploads and storage. ToolNest\'s PDF Compressor reduces file size while preserving readability.',
      'Upload your PDF, adjust the quality slider (higher = better quality, larger file), and click Compress. Processing runs entirely in your browser.',
      'For government uploads (Aadhaar, passport), use our Aadhaar PDF Compressor with preset size targets.',
    ],
  },
  'best-ai-writing-tools-2025': {
    title: '10 Best AI Writing Tools in 2025',
    category: 'AI',
    date: 'June 8, 2025',
    body: [
      'AI writing tools have become essential for content creators, marketers and students. ToolNest bundles AI Writer, Email Writer, SEO Writer and more in one platform.',
      'Unlike standalone apps, ToolNest gives you one AI brain across every tool — your context follows you from writing to PDF export.',
    ],
  },
  'passport-photo-requirements-india': {
    title: 'Passport Photo Requirements for India (2025 Guide)',
    category: 'Government',
    date: 'May 28, 2025',
    body: [
      'Indian passport photos must be 35×45 mm (413×531 px at 300 DPI), white background, face centered, file size under 200KB.',
      'Use ToolNest\'s Passport Photo Maker with the India preset — it crops, resizes and compresses automatically.',
    ],
  },
  'remove-background-free': {
    title: 'Remove Image Backgrounds for Free — Complete Guide',
    category: 'Image',
    date: 'May 20, 2025',
    body: [
      'ToolNest\'s Background Remover uses an AI model running in your browser via WASM. No upload to external servers.',
      'For product photos, pair it with Background Changer to place items on custom colors or scenes.',
    ],
  },
  'seo-checklist-2025': {
    title: 'On-Page SEO Checklist for 2025',
    category: 'SEO',
    date: 'May 12, 2025',
    body: [
      'Start with a unique title tag (≤60 chars), meta description (≤155 chars), and one H1 per page.',
      'Use ToolNest\'s SEO Analyzer to audit any URL, Meta Tag Generator for snippets, and Schema Markup Generator for JSON-LD.',
    ],
  },
};

interface Props { params: Promise<{ slug: string }> }

export async function generateStaticParams() {
  return Object.keys(posts).map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = posts[slug];
  if (!post) return {};
  return { title: `${post.title} | ToolNest Blog`, description: post.body[0] };
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params;
  const post = posts[slug];
  if (!post) notFound();

  return (
    <PageShell title={post.title} subtitle={`${post.category} · ${post.date}`}>
      {post.body.map((p, i) => <p key={i}>{p}</p>)}
      <p className="mt-6"><Link href="/blog">← Back to Blog</Link> · <Link href="/tools">Try our tools</Link></p>
    </PageShell>
  );
}
