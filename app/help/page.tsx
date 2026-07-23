import Link from 'next/link';
import PageShell from '@/components/content/PageShell';
import FaqSection from '@/components/FaqSection';
import { pageMetadata, webPageJsonLd, faqJsonLd, type Faq } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'Help Center',
  description: 'Get help using Farvixo Tools — file privacy, free AI features, Pro plans and keyboard shortcuts. Answers to the most common questions in one place.',
  path: '/help',
});

const faqs: Faq[] = [
  { q: 'Are my files uploaded to a server?', a: 'Most tools process files entirely in your browser. Server-side tools (SEO Analyzer, SSL Checker) process data transiently and do not store files.' },
  { q: 'How do I use AI tools for free?', a: 'AI tools work out of the box with a free fallback. Add your Google Gemini API key via AI Assistant → Settings for best quality.' },
  { q: 'What is Farvixo Pro?', a: 'Pro unlocks unlimited usage, 100GB cloud storage, HD AI images, batch processing and no watermarks.' },
  { q: 'How do I search tools quickly?', a: 'Press ⌘K (Mac) or Ctrl+K (Windows) anywhere on the site to open the command palette.' },
];

const jsonLd = webPageJsonLd({
  name: 'Farvixo Tools Help Center',
  description: 'Answers to common questions about Farvixo Tools, AI features and accounts.',
  path: '/help',
  extra: [faqJsonLd(faqs)],
});

export default function HelpPage() {
  return (
    <PageShell title="Help Center" subtitle="Answers to common questions" jsonLd={jsonLd}>
      <FaqSection items={faqs} heading="Frequently asked questions" />
      <p className="mt-6">Still need help? <Link href="/contact">Contact support</Link> or check the <Link href="/status">status page</Link>.</p>
    </PageShell>
  );
}
