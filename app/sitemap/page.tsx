import Link from 'next/link';
import PageShell from '@/components/content/PageShell';
import { categories } from '@/data/categories';
import { tools } from '@/data/tools';

export default function SitemapPage() {
  const staticPages = [
    { label: 'Home', href: '/' },
    { label: 'All Tools', href: '/tools' },
    { label: 'About', href: '/about' },
    { label: 'Contact', href: '/contact' },
    { label: 'Blog', href: '/blog' },
    { label: 'Help Center', href: '/help' },
    { label: 'Status', href: '/status' },
    { label: 'Login', href: '/login' },
    { label: 'Sign Up', href: '/signup' },
    { label: 'Privacy Policy', href: '/privacy-policy' },
    { label: 'Terms of Service', href: '/terms-of-service' },
    { label: 'Security', href: '/security' },
  ];

  return (
    <PageShell title="Sitemap" subtitle="All pages on ToolNest">
      <div className="sitemap-grid">
        <div>
          <h3>Main pages</h3>
          <ul>{staticPages.map((p) => <li key={p.href}><Link href={p.href}>{p.label}</Link></li>)}</ul>
        </div>
        {categories.map((c) => (
          <div key={c.slug}>
            <h3><Link href={`/tools/${c.slug}`}>{c.name}</Link></h3>
            <ul>
              {tools.filter((t) => t.category === c.slug).map((t) => (
                <li key={t.slug}><Link href={`/tools/${t.category}/${t.slug}`}>{t.name}</Link></li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </PageShell>
  );
}
