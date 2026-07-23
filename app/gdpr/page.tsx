import PageShell from '@/components/content/PageShell';
import { pageMetadata, webPageJsonLd } from '@/lib/seo';

export const metadata = pageMetadata({
  title: 'GDPR Compliance',
  description: 'Farvixo Tools and the EU GDPR — the legal basis for processing, your data-subject rights, and how to exercise them. Privacy-first by design.',
  path: '/gdpr',
});

const jsonLd = webPageJsonLd({
  name: 'GDPR Compliance',
  description: 'Farvixo Tools GDPR compliance and data subject rights.',
  path: '/gdpr',
});

export default function GdprPage() {
  return (
    <PageShell title="GDPR Compliance" subtitle="Your data rights under EU GDPR" jsonLd={jsonLd}>
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
