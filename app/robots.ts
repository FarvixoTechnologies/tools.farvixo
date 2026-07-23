import type { MetadataRoute } from 'next';

const BASE = 'https://tools.farvixo.com';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: ['/', '/api/og'],
        disallow: ['/api/', '/dashboard/', '/admin/', '/login', '/signup'],
      },
    ],
    sitemap: [`${BASE}/sitemap.xml`, `${BASE}/image-sitemap.xml`],
    host: BASE,
  };
}
