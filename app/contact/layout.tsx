import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Contact Us | Farvixo Tools',
  description: 'Get in touch with the Farvixo team.',
};

export default function ContactLayout({ children }: { children: React.ReactNode }) {
  return children;
}
