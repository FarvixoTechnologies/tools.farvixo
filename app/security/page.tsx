import type { Metadata } from 'next';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Security | ToolNest',
  description: 'How ToolNest keeps your data safe with encryption, privacy-first processing and GDPR compliance.',
};

export default function SecurityPage() {
  return (
    <PageShell title="Security" subtitle="Your data safety is our top priority">
      <h2>🔒 Privacy by design</h2>
      <p>130+ tools run entirely in your browser. Files never leave your device unless a tool explicitly requires server-side processing.</p>
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
      <p>Email <a href="mailto:security@toolnestfm.com">security@toolnestfm.com</a>. We respond within 48 hours.</p>
    </PageShell>
  );
}
