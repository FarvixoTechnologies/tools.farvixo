import type { Metadata } from 'next';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Privacy Policy | Farvixo Tools',
  description: 'How Farvixo Tools collects, uses and protects your data.',
};

export default function PrivacyPolicyPage() {
  return (
    <PageShell title="Privacy Policy" subtitle="Last updated: July 3, 2025">
      <h2>1. Overview</h2>
      <p>Farvixo Tools (&quot;we&quot;, &quot;us&quot;) operates tools.farvixo.com. This policy explains what data we collect and how we use it when you use our free online tools platform.</p>
      <h2>2. Data we collect</h2>
      <ul>
        <li><strong>Account data</strong> — email, name and profile photo when you sign up.</li>
        <li><strong>Usage data</strong> — pages visited, tools used and search queries (anonymized analytics).</li>
        <li><strong>Newsletter</strong> — email address if you subscribe.</li>
      </ul>
      <h2>3. File processing</h2>
      <p>Most tools run entirely in your browser. Your files are not uploaded to our servers unless a tool explicitly requires server-side processing (e.g. SEO Analyzer, SSL Checker). In those cases, data is processed transiently and not stored.</p>
      <h2>4. Your rights</h2>
      <p>You may request access, correction or deletion of your personal data by contacting us at <a href="mailto:privacy@farvixo.com">privacy@farvixo.com</a>.</p>
      <h2>5. Contact</h2>
      <p>Farvixo Technologies · Faruk Mondal · <a href="/contact">Contact page</a></p>
    </PageShell>
  );
}
