import { apiErr, apiOk } from '@/lib/api-response';
import { readJson, requireSession } from '@/lib/api-v1';
import { tools } from '@/data/tools';

export const dynamic = 'force-dynamic';

/** POST /api/v1/tools/favorite — { toolSlug, favorite?: boolean } */
export async function POST(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const body = await readJson<{ toolSlug?: string; favorite?: boolean }>(req);
  if (!body?.toolSlug) return apiErr('toolSlug required', 422, { code: 'VALIDATION_ERROR' });

  const tool = tools.find((t) => t.slug === body.toolSlug);
  if (!tool) return apiErr('Unknown tool', 404, { code: 'NOT_FOUND' });

  const favorite = body.favorite !== false;

  if (favorite) {
    const { error } = await supabase.from('favorites').upsert(
      {
        user_id: user.id,
        tool_slug: tool.slug,
        tool_name: tool.name,
        category: tool.category,
      },
      { onConflict: 'user_id,tool_slug' },
    );
    if (error) {
      return apiOk(
        { favorite: true, toolSlug: tool.slug, persisted: false, note: error.message },
        200,
        { message: 'Favorite accepted (table may need SQL 08)' },
      );
    }
  } else {
    await supabase.from('favorites').delete().eq('user_id', user.id).eq('tool_slug', tool.slug);
  }

  return apiOk({ favorite, toolSlug: tool.slug }, 200, { message: favorite ? 'Favorited' : 'Removed' });
}

/** GET /api/v1/tools/favorite — list favorites */
export async function GET(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const { data, error } = await supabase
    .from('favorites')
    .select('tool_slug, category, created_at')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) return apiOk({ favorites: [], ready: false, error: error.message });
  return apiOk({ favorites: data ?? [], ready: true });
}
