import type { Metadata } from 'next';
import Link from 'next/link';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Help Center | ToolNest',
  description: 'Get help using ToolNest tools, AI features and your account.',
};

const faqs = [
  { q: 'Are my files uploaded to a server?', a: 'Most tools process files entirely in your browser. Server-side tools (SEO Analyzer, SSL Checker) process data transiently and do not store files.' },
  { q: 'How do I use AI tools for free?', a: 'AI tools work out of the box with a free fallback. Add your Google Gemini API key via AI Assistant → Settings for best quality.' },
  { q: 'What is ToolNest Pro?', a: 'Pro unlocks unlimited usage, 100GB cloud storage, HD AI images, batch processing and no watermarks.' },
  { q: 'How do I search tools quickly?', a: 'Press ⌘K (Mac) or Ctrl+K (Windows) anywhere on the site to open the command palette.' },
];

export default function HelpPage() {
  return (
    <PageShell title="Help Center" subtitle="Answers to common questions">
      {faqs.map((f) => (
        <details key={f.q} className="faq-item mb-4">
          <summary>{f.q}</summary>
          <p>{f.a}</p>
        </details>
      ))}
      <p className="mt-6">Still need help? <Link href="/contact">Contact support</Link> or check the <Link href="/status">status page</Link>.</p>
    </PageShell>
  );
}
