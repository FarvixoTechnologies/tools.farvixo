import { apiErr, apiOk } from '@/lib/api-response';
import { requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

/** AI logs (request / error / moderation) with search, filters, pagination. */
export async function GET(req: Request) {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const q = (url.searchParams.get('q') ?? '').trim();
  const kind = url.searchParams.get('kind') ?? '';
  const level = url.searchParams.get('level') ?? '';
  const page = Math.max(1, Number(url.searchParams.get('page') || 1));
  const limit = 30;
  const from = (page - 1) * limit;

  let query = admin
    .from('ai_logs')
    .select('id, user_id, provider_id, model_id, kind, level, message, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + limit - 1);
  if (kind) query = query.eq('kind', kind);
  if (level) query = query.eq('level', level);
  if (q) query = query.or(`message.ilike.%${q}%,model_id.ilike.%${q}%`);

  const { data, error, count } = await query;
  if (error) return apiErr(error.message, 500);
  return apiOk({ logs: data ?? [], total: count ?? 0, page, pages: Math.ceil((count ?? 0) / limit) });
}
