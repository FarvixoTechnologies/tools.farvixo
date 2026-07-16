import { apiErr, apiOk } from '@/lib/api-response';
import { tools } from '@/data/tools';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

type Ctx = { params: Promise<{ id: string }> };

/** GET /api/v1/tools/:id — tool by slug (Architecture v3). */
export async function GET(req: Request, ctx: Ctx) {
  const rl = rateLimit(`v1tool:${clientIp(req)}`, 60, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const { id } = await ctx.params;
  const slug = decodeURIComponent(id).trim().toLowerCase();
  const tool = tools.find((t) => t.slug === slug || t.slug.toLowerCase() === slug);

  if (!tool) return apiErr(`Tool not found: ${slug}`, 404, { code: 'NOT_FOUND' });

  return apiOk({
    tool: {
      slug: tool.slug,
      name: tool.name,
      description: tool.description,
      category: tool.category,
      badge: tool.badge ?? null,
      url: `https://tools.farvixo.com/tools/${tool.category}/${tool.slug}`,
    },
  });
}
