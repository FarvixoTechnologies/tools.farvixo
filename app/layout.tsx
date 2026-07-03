import type { Metadata } from 'next';
import { Sora, Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import GlobalUI from '@/components/GlobalUI';
import { AuthProvider } from '@/components/providers/AuthProvider';

const sora = Sora({ subsets: ['latin'], variable: '--font-sora', weight: ['400', '600', '700', '800'] });
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });
const jetbrains = JetBrains_Mono({ subsets: ['latin'], variable: '--font-jetbrains', weight: ['400', '500'] });

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'https://toolnestfm.com'),
  title: 'ToolNest — 120+ Free Online Tools Powered by AI | PDF, Image, Video & More',
  description:
    'One Platform. Infinite Tools. Convert, compress, edit and create with 120+ free AI-powered tools — PDF, Image, Video, Audio, Developer, SEO, Business and more.',
  keywords: ['online tools', 'pdf tools', 'image compressor', 'ai tools', 'free tools', 'toolnest'],
  openGraph: {
    title: 'ToolNest — One Platform. Infinite Tools. Powered by AI.',
    description: '120+ free online tools: PDF, Image, Video, Audio, AI, Developer, SEO & more.',
    url: 'https://toolnestfm.com',
    siteName: 'ToolNest',
    type: 'website',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'WebApplication',
    name: 'ToolNest',
    url: 'https://toolnestfm.com',
    applicationCategory: 'UtilitiesApplication',
    operatingSystem: 'Web',
    description: '120+ free online tools powered by AI.',
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
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
          </AuthProvider>
        </GlobalUI>
      </body>
    </html>
  );
}
