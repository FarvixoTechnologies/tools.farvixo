import type { Metadata, Viewport } from 'next';
import { Sora, Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import GlobalUI from '@/components/GlobalUI';
import FirebaseProvider from '@/components/FirebaseProvider';
import MicrosoftClarity from '@/components/MicrosoftClarity';
import GoogleAnalytics from '@/components/GoogleAnalytics';
import { AuthProvider } from '@/components/providers/AuthProvider';
import BottomNav from '@/components/layout/BottomNav';
import ScrollManager from '@/components/ScrollManager';

const sora = Sora({ subsets: ['latin'], variable: '--font-sora', weight: ['400', '600', '700', '800'] });
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });
const jetbrains = JetBrains_Mono({ subsets: ['latin'], variable: '--font-jetbrains', weight: ['400', '500'] });

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#6C4DFF',
};

const SITE_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://tools.farvixo.com';
const DEFAULT_OG = `${SITE_URL}/api/og?title=150%2B+Free+Online+AI+%26+Productivity+Tools&subtitle=Build+Beyond.&badge=AI`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  applicationName: 'Farvixo Tools',
  title: {
    default: 'Farvixo Tools — 150+ Free Online AI & Productivity Tools',
    template: '%s | Farvixo Tools',
  },
  description:
    'Use 150+ free AI-powered online tools — PDF, image, video, audio, developer, SEO tools, converters and calculators. Fast, secure and private. Build Beyond.',
  keywords: [
    'farvixo', 'farvixo tools', 'ai tools', 'online tools', 'developer tools',
    'free pdf tools', 'image tools', 'seo tools', 'converters', 'calculators',
    'utilities', 'productivity', 'online utilities', 'file tools', 'modern ai platform',
  ],
  authors: [{ name: 'Farvixo Technologies', url: SITE_URL }],
  creator: 'Farvixo Technologies',
  publisher: 'Farvixo Technologies',
  category: 'technology',
  alternates: {
    canonical: SITE_URL,
    // Multi-language readiness — single locale today; expand LOCALES in lib/seo.
    languages: { 'x-default': SITE_URL, en: SITE_URL },
  },
  // Search Console / Bing Webmaster hooks — set the tokens in env to activate.
  verification: {
    google: process.env.NEXT_PUBLIC_GSC_VERIFICATION || undefined,
    other: process.env.NEXT_PUBLIC_BING_VERIFICATION
      ? { 'msvalidate.01': process.env.NEXT_PUBLIC_BING_VERIFICATION }
      : undefined,
  },
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: 'any' },
      { url: '/favicon.svg', type: 'image/svg+xml' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
    ],
    shortcut: '/favicon.ico',
    apple: '/apple-touch-icon.png',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1, 'max-video-preview': -1 },
  },
  openGraph: {
    title: 'Farvixo Tools — 150+ Free Online AI & Productivity Tools',
    description: 'Use 150+ free AI-powered online tools — PDF, image, video, audio, developer & SEO tools, converters and calculators. Fast, secure and private.',
    url: SITE_URL,
    siteName: 'Farvixo Tools',
    type: 'website',
    locale: 'en_US',
    images: [{ url: DEFAULT_OG, width: 1200, height: 630, alt: 'Farvixo Tools — 150+ free online AI & productivity tools' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Farvixo Tools — 150+ Free Online AI & Productivity Tools',
    description: 'Use 150+ free AI-powered online tools — PDF, image, video, audio, developer & SEO tools, converters and calculators. Fast, secure and private.',
    images: [DEFAULT_OG],
    creator: '@farvixo',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        '@id': `${SITE_URL}#org`,
        name: 'Farvixo Technologies',
        legalName: 'Farvixo Technologies',
        url: SITE_URL,
        logo: `${SITE_URL}/farvixo-logo.svg`,
        description: '150+ free online AI & productivity tools.',
        sameAs: [
          'https://twitter.com/farvixo',
          'https://github.com/farvixo',
          'https://www.linkedin.com/company/farvixo',
        ],
      },
      {
        '@type': 'WebSite',
        '@id': `${SITE_URL}#website`,
        name: 'Farvixo Tools',
        url: SITE_URL,
        publisher: { '@id': `${SITE_URL}#org` },
        potentialAction: {
          '@type': 'SearchAction',
          target: { '@type': 'EntryPoint', urlTemplate: `${SITE_URL}/tools?q={search_term_string}` },
          'query-input': 'required name=search_term_string',
        },
      },
      {
        '@type': 'WebApplication',
        name: 'Farvixo Tools',
        url: SITE_URL,
        applicationCategory: 'UtilitiesApplication',
        operatingSystem: 'Web',
        description: '150+ free online AI & productivity tools — PDF, Image, Video, Audio, AI, Developer, SEO and more.',
        isAccessibleForFree: true,
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
        publisher: { '@id': `${SITE_URL}#org` },
      },
    ],
  };
  return (
    <html lang="en" data-theme="dark" suppressHydrationWarning>
      <body className={`${sora.variable} ${inter.variable} ${jetbrains.variable}`}>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
        <a href="#main-content" className="skip-link">Skip to main content</a>
        <GlobalUI>
          <ScrollManager />
          <AuthProvider>
            <FirebaseProvider />
            <MicrosoftClarity />
            <GoogleAnalytics />
            <Header />
            <main id="main-content">{children}</main>
            <Footer />
            <BottomNav />
          </AuthProvider>
        </GlobalUI>
      </body>
    </html>
  );
}
