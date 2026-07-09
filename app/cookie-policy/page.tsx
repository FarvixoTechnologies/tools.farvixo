import type { Metadata } from 'next';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Cookie Policy | Farvixo Tools',
  description: 'How Farvixo Tools uses cookies and similar technologies.',
};

export default function CookiePolicyPage() {
  return (
    <PageShell title="Cookie Policy" subtitle="Last updated: July 3, 2025">
      <h2>What are cookies?</h2>
      <p>Cookies are small text files stored on your device to remember preferences and improve your experience.</p>
      <h2>Cookies we use</h2>
      <ul>
        <li><strong>Essential</strong> — theme preference, session authentication.</li>
        <li><strong>Functional</strong> — AI API key storage (local only), newsletter subscription state.</li>
        <li><strong>Analytics</strong> — anonymous usage metrics via Vercel Analytics.</li>
      </ul>
      <h2>Managing cookies</h2>
      <p>You can disable cookies in your browser settings. Some features (login, theme persistence) may not work without them.</p>
    </PageShell>
  );
}
