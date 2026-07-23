import Link from 'next/link';
import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'How It Works',
  description: 'How Farvixo Tools work — upload or paste, process instantly in your browser, and download. Three simple steps, 100% private, no sign-up required.',
  path: '/how-it-works',
});

const jsonLd = webPageJsonLd({
  name: 'How Farvixo Tools Work',
  description: 'Upload, process and download in three simple, browser-based steps.',
  path: '/how-it-works',
});

export default function HowItWorksPage() {
  return (
    <PageShell title="How It Works" subtitle="Three steps to get anything done" jsonLd={jsonLd}>
      <div className="hiw" style={{ marginTop: 24 }}>
        {[
          { n: 1, t: 'Choose a tool', d: 'Browse 150+ tools by category or search with ⌘K. Every tool has a dedicated page with clear instructions.' },
          { n: 2, t: 'Upload or enter', d: 'Drag & drop files or type your input. Processing runs in your browser — private and instant.' },
          { n: 3, t: 'Download result', d: 'Get your output immediately. No sign-up required for free tools. Pro users get cloud storage and batch processing.' },
        ].map((s) => (
          <div key={s.n} className="hiw-step">
            <span className="hiw-num">{s.n}</span>
            <b>{s.t}</b>
            <p>{s.d}</p>
          </div>
        ))}
      </div>
      <p className="text-center mt-6"><Link href="/tools" className="btn btn-primary">Explore All Tools →</Link></p>
    </PageShell>
  );
}
