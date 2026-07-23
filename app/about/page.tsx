import Link from 'next/link';
import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'About Us',
  description: 'Farvixo Tools is one platform with 150+ free online AI & productivity tools — PDF, image, video, AI and more. Built by Farvixo Technologies. Build Beyond.',
  path: '/about',
});

const jsonLd = webPageJsonLd({
  type: 'AboutPage',
  name: 'About Farvixo Tools',
  description: 'One platform with 150+ free online AI & productivity tools, built by Farvixo Technologies.',
  path: '/about',
});

export default function AboutPage() {
  return (
    <PageShell title="About Farvixo Tools" subtitle="Build Beyond." jsonLd={jsonLd}>
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
