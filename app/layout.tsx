import type { Metadata, Viewport } from 'next';
import { Sora, Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import GlobalUI from '@/components/GlobalUI';
import { AuthProvider } from '@/components/providers/AuthProvider';
import BottomNav from '@/components/layout/BottomNav';

const sora = Sora({ subsets: ['latin'], variable: '--font-sora', weight: ['400', '600', '700', '800'] });
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });
const jetbrains = JetBrains_Mono({ subsets: ['latin'], variable: '--font-jetbrains', weight: ['400', '500'] });

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#7C3AED',
};

const SITE_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://toolnestfm.com';
const DEFAULT_OG = `${SITE_URL}/api/og?title=128%2B+Free+Online+Tools&subtitle=One+Platform.+Infinite+Tools.&badge=AI`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  applicationName: 'ToolNest',
  title: {
    default: 'ToolNest — 128 Free Online Tools Powered by AI | PDF, Image, Video & More',
    template: '%s | ToolNest',
  },
  description:
    'One Platform. Infinite Tools. Convert, compress, edit and create with 128 free AI-powered tools — PDF, Image, Video, Audio, Developer, SEO, Business, Weather and more. No sign-up, no watermark, 100% private.',
  keywords: [
    'online tools', 'free online tools', 'pdf tools', 'image compressor', 'background remover',
    'ai tools', 'video converter', 'audio converter', 'seo tools', 'developer tools',
    'free tools', 'toolnest', 'file converter', 'weather', 'no sign up tools',
  ],
  authors: [{ name: 'ToolNest', url: SITE_URL }],
  creator: 'ToolNest',
  publisher: 'Fam Cloud Pvt. Ltd.',
  category: 'technology',
  alternates: { canonical: SITE_URL },
  icons: {
    icon: '/favicon.png',
    apple: '/logo-icon.png',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1, 'max-video-preview': -1 },
  },
  openGraph: {
    title: 'ToolNest — One Platform. Infinite Tools. Powered by AI.',
    description: '128 free online tools: PDF, Image, Video, Audio, AI, Developer, SEO, Weather & more. No sign-up, 100% private.',
    url: SITE_URL,
    siteName: 'ToolNest',
    type: 'website',
    locale: 'en_US',
    images: [{ url: DEFAULT_OG, width: 1200, height: 630, alt: 'ToolNest — 128 free online tools' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ToolNest — One Platform. Infinite Tools. Powered by AI.',
    description: '128 free online tools: PDF, Image, Video, Audio, AI, Developer, SEO, Weather & more.',
    images: [DEFAULT_OG],
    creator: '@toolnestfm',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        '@id': `${SITE_URL}#org`,
        name: 'ToolNest',
        legalName: 'Fam Cloud Pvt. Ltd.',
        url: SITE_URL,
        logo: `${SITE_URL}/logo-icon.png`,
        description: '128 free online tools powered by AI.',
        sameAs: [
          'https://twitter.com/toolnestfm',
          'https://github.com/toolnestfm',
          'https://www.linkedin.com/company/toolnestfm',
        ],
      },
      {
        '@type': 'WebSite',
        '@id': `${SITE_URL}#website`,
        name: 'ToolNest',
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
        name: 'ToolNest',
        url: SITE_URL,
        applicationCategory: 'UtilitiesApplication',
        operatingSystem: 'Web',
        description: '128 free online tools powered by AI — PDF, Image, Video, Audio, AI, Developer, SEO and more.',
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
        <GlobalUI>
          <AuthProvider>
            <Header />
            <main>{children}</main>
            <Footer />
            <BottomNav />
          </AuthProvider>
        </GlobalUI>
      </body>
    </html>
  );
}
