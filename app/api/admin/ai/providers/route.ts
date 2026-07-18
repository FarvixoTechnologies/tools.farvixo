import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  const { data, error } = await auth.ctx.admin
    .from('ai_providers')
    .select('id, display_name, is_active, base_url, docs_url, sort_order')
    .order('sort_order');
  if (error) return apiErr(error.message, 500);
  return apiOk({ providers: data ?? [] });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { id?: string; is_active?: boolean; display_name?: string; base_url?: string };
  try { body = (await req.json()) as typeof body; } catch { return apiErr('Invalid body', 400); }
  if (!body.id) return apiErr('id required', 400);

  const updates: Record<string, unknown> = {};
  if (typeof body.is_active === 'boolean') updates.is_active = body.is_active;
  if (typeof body.display_name === 'string' && body.display_name.trim()) updates.display_name = body.display_name.trim();
  if (typeof body.base_url === 'string') updates.base_url = body.base_url.trim() || null;
  if (!Object.keys(updates).length) return apiErr('Nothing to update', 400);

  const { error } = await admin.from('ai_providers').update(updates).eq('id', body.id);
  if (error) return apiErr(error.message, 500);
  await logAdminAction(admin, userId, 'ai.provider.update', body.id, updates);
  return apiOk({ updated: true });
}
