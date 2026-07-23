import { pageMetadata, webPageJsonLd } from '@/lib/seo';

// Metadata can't be exported from the client `page.tsx`, so it lives here.
export const metadata = pageMetadata({
  title: 'Contact Us',
  description: 'Get in touch with the Farvixo Tools team — questions, feedback, partnerships or support. Email hello@farvixo.com or use the form; we reply within 24 hours.',
  path: '/contact',
});

const jsonLd = webPageJsonLd({
  type: 'ContactPage',
  name: 'Contact Farvixo Tools',
  description: 'Contact the Farvixo Tools team for support, feedback or partnerships.',
  path: '/contact',
});

export default function ContactLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      {children}
    </>
  );
}
