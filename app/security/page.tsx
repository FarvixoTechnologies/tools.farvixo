import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'Security',
  description: 'How Farvixo Tools keeps your data safe — privacy-first browser processing, encryption in transit, and GDPR compliance. Your files stay on your device.',
  path: '/security',
});

const jsonLd = webPageJsonLd({
  name: 'Security',
  description: 'How Farvixo Tools keeps your data safe with privacy-first processing, encryption and GDPR compliance.',
  path: '/security',
});

export default function SecurityPage() {
  return (
    <PageShell title="Security" subtitle="Your data safety is our top priority" jsonLd={jsonLd}>
      <h2>🔒 Privacy by design</h2>
      <p>150+ tools run entirely in your browser. Files never leave your device unless a tool explicitly requires server-side processing.</p>
      <h2>Encryption</h2>
      <ul>
        <li>256-bit SSL/TLS on all connections</li>
        <li>AES-256 encryption for password-protected PDFs</li>
        <li>Signed, expiring download URLs for cloud storage (Pro)</li>
      </ul>
      <h2>Infrastructure</h2>
      <p>Hosted on Vercel with Cloudflare R2 for file storage. Supabase PostgreSQL with Row Level Security for account data.</p>
      <h2>Compliance</h2>
      <p>GDPR compliant. See our <a href="/gdpr">GDPR page</a> and <a href="/privacy-policy">Privacy Policy</a> for details.</p>
      <h2>Report a vulnerability</h2>
      <p>Email <a href="mailto:security@farvixo.com">security@farvixo.com</a>. We respond within 48 hours.</p>
    </PageShell>
  );
}
