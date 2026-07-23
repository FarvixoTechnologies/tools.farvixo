import { tools } from '@/data/tools';
import { getCategory } from '@/data/categories';
import { SITE, toolUrl, ogImage } from '@/lib/seo';

export const dynamic = 'force-static';

function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/**
 * Google image sitemap — one <image:image> per tool, pointing at its branded
 * dynamic OG image. Helps Google Images index every tool page's preview.
 * Served at /image-sitemap.xml and referenced from robots.txt.
 */
export function GET(): Response {
  const urls = tools
    .map((t) => {
      const cat = getCategory(t.category);
      const loc = esc(toolUrl(t));
      const img = esc(ogImage({ title: t.name, subtitle: cat?.name ?? SITE.tagline }));
      const title = esc(`${t.name} — Farvixo Tools`);
      const caption = esc(t.description);
      return `  <url>\n    <loc>${loc}</loc>\n    <image:image>\n      <image:loc>${img}</image:loc>\n      <image:title>${title}</image:title>\n      <image:caption>${caption}</image:caption>\n    </image:image>\n  </url>`;
    })
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">\n${urls}\n</urlset>`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'public, max-age=3600, s-maxage=86400',
    },
  });
}
