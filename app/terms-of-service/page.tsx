import type { Metadata } from 'next';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Terms of Service | ToolNest',
  description: 'Terms and conditions for using ToolNest online tools.',
};

export default function TermsPage() {
  return (
    <PageShell title="Terms of Service" subtitle="Last updated: July 3, 2025">
      <h2>1. Acceptance</h2>
      <p>By accessing ToolNest you agree to these Terms. If you disagree, please do not use the service.</p>
      <h2>2. Service description</h2>
      <p>ToolNest provides free and Pro-tier online tools for file conversion, editing, AI assistance and related utilities. Features may change without notice.</p>
      <h2>3. Acceptable use</h2>
      <p>You agree not to use ToolNest for illegal activity, malware distribution, copyright infringement or abuse of rate limits and API endpoints.</p>
      <h2>4. Pro subscriptions</h2>
      <p>Paid plans are billed monthly or annually via Stripe. Refunds are governed by our <a href="/refund-policy">Refund Policy</a>.</p>
      <h2>5. Disclaimer</h2>
      <p>Tools are provided &quot;as is&quot; without warranty. We are not liable for data loss — always keep backups of important files.</p>
      <h2>6. Governing law</h2>
      <p>These terms are governed by the laws of India. Disputes shall be subject to the courts of Kolkata.</p>
    </PageShell>
  );
}
