import type { Metadata } from 'next';
import PageShell from '@/components/content/PageShell';

export const metadata: Metadata = {
  title: 'GDPR | Farvixo Tools',
  description: 'Farvixo Tools GDPR compliance and data subject rights.',
};

export default function GdprPage() {
  return (
    <PageShell title="GDPR Compliance" subtitle="Your data rights under EU GDPR">
      <h2>Data controller</h2>
      <p>Farvixo Technologies, operating Farvixo Tools (tools.farvixo.com). Contact: <a href="mailto:privacy@farvixo.com">privacy@farvixo.com</a></p>
      <h2>Legal basis</h2>
      <p>We process data based on consent (newsletter), contract (Pro subscriptions) and legitimate interest (security, analytics).</p>
      <h2>Your rights</h2>
      <ul>
        <li>Right of access and portability</li>
        <li>Right to rectification</li>
        <li>Right to erasure (&quot;right to be forgotten&quot;)</li>
        <li>Right to restrict or object to processing</li>
        <li>Right to lodge a complaint with your supervisory authority</li>
      </ul>
      <h2>Data retention</h2>
      <p>Free-tier uploaded files are deleted after 24 hours. Account data is retained until you delete your account.</p>
    </PageShell>
  );
}
