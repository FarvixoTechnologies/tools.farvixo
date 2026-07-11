import type { Metadata } from 'next';
import Link from 'next/link';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'About Us | Farvixo Tools',
  description: 'Learn about Farvixo Tools — one platform with 150+ free online AI & productivity tools.',
};

export default function AboutPage() {
  return (
    <PageShell title="About Farvixo Tools" subtitle="Build Beyond.">
      <p>Farvixo Tools is built by <strong>Faruk Mondal</strong> and the team at <strong>Farvixo Technologies</strong>. We set out to replace the fragmented landscape of single-purpose tool sites with one unified platform — one account, one history, one AI brain across every tool.</p>
      <h2>Our mission</h2>
      <p>Give everyone professional-grade tools for PDF, image, video, audio, AI, developer, SEO and business tasks — free, fast, and private.</p>
      <h2>By the numbers</h2>
      <ul>
        <li>150+ tools across 15 categories</li>
        <li>A growing worldwide user community</li>
        <li>100% free to use</li>
        <li>100% browser-based processing where possible</li>
      </ul>
      <h2>Get started</h2>
      <p><Link href="/tools">Browse all tools</Link> · <Link href="/contact">Contact us</Link> · <Link href="/login">Create free account</Link></p>
    </PageShell>
  );
}
