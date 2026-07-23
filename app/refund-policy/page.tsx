import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'Refund Policy',
  description: 'The Farvixo Pro refund policy — a 7-day money-back guarantee on your first payment, no questions asked. Learn how to request one and when it applies.',
  path: '/refund-policy',
});

const jsonLd = webPageJsonLd({
  name: 'Refund Policy',
  description: 'Farvixo Pro subscription refund policy.',
  path: '/refund-policy',
});

export default function RefundPolicyPage() {
  return (
    <PageShell title="Refund Policy" subtitle="Last updated: July 3, 2025" jsonLd={jsonLd}>
      <h2>7-day money-back guarantee</h2>
      <p>If you are not satisfied with Farvixo Pro within 7 days of your first payment, contact us for a full refund — no questions asked.</p>
      <h2>How to request</h2>
      <p>Email <a href="mailto:billing@farvixo.com">billing@farvixo.com</a> with your account email and payment date. Refunds are processed within 5–10 business days.</p>
      <h2>Renewals</h2>
      <p>Subscription renewals after the first 7 days are non-refundable unless required by applicable law. You may cancel anytime to prevent future charges.</p>
    </PageShell>
  );
}
