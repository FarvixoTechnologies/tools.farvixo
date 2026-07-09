import type { Metadata } from 'next';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'Refund Policy | Farvixo Tools',
  description: 'Farvixo Pro subscription refund policy.',
};

export default function RefundPolicyPage() {
  return (
    <PageShell title="Refund Policy" subtitle="Last updated: July 3, 2025">
      <h2>7-day money-back guarantee</h2>
      <p>If you are not satisfied with Farvixo Pro within 7 days of your first payment, contact us for a full refund — no questions asked.</p>
      <h2>How to request</h2>
      <p>Email <a href="mailto:billing@farvixo.com">billing@farvixo.com</a> with your account email and payment date. Refunds are processed within 5–10 business days.</p>
      <h2>Renewals</h2>
      <p>Subscription renewals after the first 7 days are non-refundable unless required by applicable law. You may cancel anytime to prevent future charges.</p>
    </PageShell>
  );
}
