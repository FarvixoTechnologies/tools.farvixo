import { apiOk } from '@/lib/api-response';
import { tools } from '@/data/tools';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';
import { parsePagination } from '@/lib/api-v1';

export const dynamic = 'force-dynamic';

/** GET /api/v1/tools/search?q= — name/description/category search with pagination. */
export async function GET(req: Request) {
  const rl = rateLimit(`v1tsearch:${clientIp(req)}`, 60, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const url = new URL(req.url);
  const q = (url.searchParams.get('q') || url.searchParams.get('query') || '').trim().toLowerCase();
  const { page, pageSize, from, to } = parsePagination(req, { pageSize: 20, max: 50 });

  let list = tools;
  if (q) {
    list = tools.filter((t) => {
      const hay = `${t.name} ${t.description} ${t.category} ${t.slug}`.toLowerCase();
      return q.split(/\s+/).every((token) => hay.includes(token));
    });
  }

  const slice = list.slice(from, to + 1);
  return apiOk(
    {
      query: q,
      count: list.length,
      tools: slice.map((t) => ({
        slug: t.slug,
        name: t.name,
        description: t.description,
        category: t.category,
        badge: t.badge ?? null,
        url: `https://tools.farvixo.com/tools/${t.category}/${t.slug}`,
      })),
    },
    200,
    { meta: { page, pageSize, total: list.length } },
  );
}
