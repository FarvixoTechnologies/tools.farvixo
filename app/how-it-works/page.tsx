import type { Metadata } from 'next';
import Link from 'next/link';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'How It Works | ToolNest',
  description: 'Learn how ToolNest tools work — upload, process and download in three simple steps.',
};

export default function HowItWorksPage() {
  return (
    <PageShell title="How It Works" subtitle="Three steps to get anything done">
      <div className="hiw" style={{ marginTop: 24 }}>
        {[
          { n: 1, t: 'Choose a tool', d: 'Browse 130+ tools by category or search with ⌘K. Every tool has a dedicated page with clear instructions.' },
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
