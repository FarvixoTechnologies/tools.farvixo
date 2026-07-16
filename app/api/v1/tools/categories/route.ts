import { apiOk } from '@/lib/api-response';
import { categories } from '@/data/categories';
import { tools } from '@/data/tools';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

/** GET /api/v1/tools/categories — public category list + live tool counts. */
export async function GET(req: Request) {
  const rl = rateLimit(`v1cats:${clientIp(req)}`, 60, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const counts: Record<string, number> = {};
  for (const t of tools) {
    counts[t.category] = (counts[t.category] ?? 0) + 1;
  }

  return apiOk({
    count: categories.length,
    categories: categories.map((c) => ({
      slug: c.slug,
      name: c.name,
      shortName: c.shortName,
      icon: c.icon,
      accent: c.accent,
      description: c.description,
      toolCount: counts[c.slug] ?? 0,
      url: `https://tools.farvixo.com/tools/${c.slug}`,
    })),
  });
}
