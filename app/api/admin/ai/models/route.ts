import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const q = (url.searchParams.get('q') ?? '').trim();
  const provider = url.searchParams.get('provider') ?? '';
  const category = url.searchParams.get('category') ?? '';
  const active = url.searchParams.get('active') ?? '';

  let query = admin
    .from('ai_models')
    .select('id, provider_id, display_name, category, is_active, priority, input_cost_per_1k, output_cost_per_1k, context_window')
    .order('priority', { ascending: true });
  if (q) query = query.or(`id.ilike.%${q}%,display_name.ilike.%${q}%`);
  if (provider) query = query.eq('provider_id', provider);
  if (category) query = query.eq('category', category);
  if (active === 'true') query = query.eq('is_active', true);
  if (active === 'false') query = query.eq('is_active', false);

  const { data, error } = await query;
  if (error) return apiErr(error.message, 500);
  return apiOk({ models: data ?? [] });
}

export async function POST(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: {
    id?: string; provider_id?: string; display_name?: string; category?: string;
    priority?: number; input_cost_per_1k?: number; output_cost_per_1k?: number; context_window?: number;
  };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }
  const id = (b.id ?? '').trim();
  if (!id || !b.provider_id || !b.display_name) return apiErr('id, provider_id, display_name required', 400);

  const { data: prov } = await admin.from('ai_providers').select('id').eq('id', b.provider_id).maybeSingle();
  if (!prov) return apiErr('provider does not exist', 400);

  const { error } = await admin.from('ai_models').insert({
    id, provider_id: b.provider_id, display_name: b.display_name.trim(),
    category: b.category || 'chat',
    priority: Number.isFinite(b.priority) ? b.priority : 100,
    input_cost_per_1k: b.input_cost_per_1k ?? 0,
    output_cost_per_1k: b.output_cost_per_1k ?? 0,
    context_window: b.context_window ?? null,
  });
  if (error) return apiErr(error.code === '23505' ? 'Model id already exists' : error.message, 400);
  await logAdminAction(admin, userId, 'ai.model.create', id);
  return apiOk({ created: true, id });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: Record<string, unknown> & { id?: string };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }
  if (!b.id) return apiErr('id required', 400);

  const updates: Record<string, unknown> = {};
  for (const f of ['display_name', 'category', 'is_active', 'priority', 'input_cost_per_1k', 'output_cost_per_1k', 'context_window'] as const) {
    if (b[f] !== undefined) updates[f] = b[f];
  }
  if (!Object.keys(updates).length) return apiErr('Nothing to update', 400);

  const { error } = await admin.from('ai_models').update(updates).eq('id', b.id);
  if (error) return apiErr(error.message, 500);
  await logAdminAction(admin, userId, 'ai.model.update', String(b.id), updates);
  return apiOk({ updated: true });
}

export async function DELETE(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;
  const id = new URL(req.url).searchParams.get('id') ?? '';
  if (!id) return apiErr('id required', 400);
  const { error } = await admin.from('ai_models').delete().eq('id', id);
  if (error) return apiErr(error.message, 500);
  await logAdminAction(admin, userId, 'ai.model.delete', id);
  return apiOk({ deleted: true });
}
