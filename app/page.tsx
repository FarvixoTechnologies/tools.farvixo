import Hero from '@/components/homepage/Hero';
import Explorer from '@/components/homepage/Explorer';
import Newsletter from '@/components/homepage/Newsletter';
import FaqSection from '@/components/FaqSection';
import { HomepageInlineAd, FooterLeaderboardAd } from '@/components/ads/HomepageAds';
import { faqJsonLd, type Faq } from '@/lib/seo';

/* Homepage FAQ — feeds both the visible section and the FAQPage rich result.
   Site-wide Organization/WebSite/SearchAction schema already ships from the
   root layout, so the homepage only adds its FAQ here. */
const HOME_FAQ: Faq[] = [
  { q: 'Is Farvixo Tools free to use?', a: 'Yes. All 150+ tools are free with no sign-up and no watermarks. Optional Farvixo Pro adds unlimited usage, cloud storage and batch processing.' },
  { q: 'Are my files private?', a: 'Yes. Most tools process files entirely in your browser, so your files never leave your device. The few server-side tools handle data transiently and store nothing.' },
  { q: 'Do I need to install anything?', a: 'No. Every tool runs in any modern web browser on desktop, tablet and mobile — no downloads, no extensions and no account required.' },
  { q: 'What kinds of tools does Farvixo offer?', a: 'PDF, image, video, audio, AI, developer, text, SEO, business, social media, utility, security, calculator, file-converter and government document tools — 15 categories in one place.' },
  { q: 'Does Farvixo Tools use AI?', a: 'Yes. AI powers chat, writing, image generation, OCR, translation, document analysis and smart suggestions across many tools, with a free tier and optional API key.' },
  { q: 'Does it work on mobile?', a: 'Yes — every tool is fully responsive and works on Android and iPhone exactly like it does on desktop.' },
];

export default function HomePage() {
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd(HOME_FAQ)) }} />
      <Hero />
      <Explorer />
      <HomepageInlineAd />
      <section className="container" style={{ marginBottom: 48 }}>
        <FaqSection items={HOME_FAQ} heading="Frequently asked questions" />
      </section>
      <Newsletter />
      <FooterLeaderboardAd />
    </>
  );
}
