import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Contact Us | ToolNest',
  description: 'Get in touch with the ToolNest team.',
};

export default function ContactLayout({ children }: { children: React.ReactNode }) {
  return children;
}
