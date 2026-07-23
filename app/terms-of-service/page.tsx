import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'Terms of Service',
  description: 'The terms and conditions for using Farvixo Tools — your rights, acceptable use, and our service commitments. Please read before using the platform.',
  path: '/terms-of-service',
});

const jsonLd = webPageJsonLd({
  name: 'Terms of Service',
  description: 'Terms and conditions for using Farvixo Tools.',
  path: '/terms-of-service',
});

export default function TermsPage() {
  return (
    <PageShell title="Terms of Service" subtitle="Last updated: July 3, 2025" jsonLd={jsonLd}>
      <h2>1. Acceptance</h2>
      <p>By accessing Farvixo Tools you agree to these Terms. If you disagree, please do not use the service.</p>
      <h2>2. Service description</h2>
      <p>Farvixo Tools provides free and Pro-tier online tools for file conversion, editing, AI assistance and related utilities. Features may change without notice.</p>
      <h2>3. Acceptable use</h2>
      <p>You agree not to use Farvixo Tools for illegal activity, malware distribution, copyright infringement or abuse of rate limits and API endpoints.</p>
      <h2>4. Pro subscriptions</h2>
      <p>Paid plans are billed monthly or annually via Stripe. Refunds are governed by our <a href="/refund-policy">Refund Policy</a>.</p>
      <h2>5. Disclaimer</h2>
      <p>Tools are provided &quot;as is&quot; without warranty. We are not liable for data loss — always keep backups of important files.</p>
      <h2>6. Governing law</h2>
      <p>These terms are governed by the laws of India. Disputes shall be subject to the courts of Kolkata.</p>
    </PageShell>
  );
}
