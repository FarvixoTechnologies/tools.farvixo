import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

const KEY_RE = /^[a-z0-9_-]{2,48}$/;

export async function GET(req: Request) {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');

  // Single template + its version history.
  if (id) {
    const [{ data: tpl }, { data: versions }] = await Promise.all([
      admin.from('ai_prompt_templates').select('id, key, name, category, description, is_active, current_version').eq('id', id).maybeSingle(),
      admin.from('ai_prompt_versions').select('id, version, content, created_at').eq('template_id', id).order('version', { ascending: false }),
    ]);
    if (!tpl) return apiErr('Template not found', 404);
    return apiOk({ template: tpl, versions: versions ?? [] });
  }

  const q = (url.searchParams.get('q') ?? '').trim();
  const category = url.searchParams.get('category') ?? '';
  let query = admin
    .from('ai_prompt_templates')
    .select('id, key, name, category, description, is_active, current_version, updated_at')
    .order('updated_at', { ascending: false });
  if (q) query = query.or(`key.ilike.%${q}%,name.ilike.%${q}%`);
  if (category) query = query.eq('category', category);

  const { data, error } = await query;
  if (error) return apiErr(error.message, 500);
  return apiOk({ templates: data ?? [] });
}

export async function POST(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: { key?: string; name?: string; category?: string; description?: string; content?: string };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }
  const key = (b.key ?? '').trim().toLowerCase();
  if (!KEY_RE.test(key)) return apiErr('Key: 2–48 chars a-z, 0-9, _ or -', 400);
  if (!b.name?.trim() || !b.content?.trim()) return apiErr('name and content required', 400);

  const { data: tpl, error } = await admin.from('ai_prompt_templates').insert({
    key, name: b.name.trim(), category: (b.category || 'General').trim(),
    description: (b.description ?? '').trim().slice(0, 300) || null,
    current_version: 1,
  }).select('id').single();
  if (error) return apiErr(error.code === '23505' ? 'Template key already exists' : error.message, 400);

  await admin.from('ai_prompt_versions').insert({ template_id: tpl.id, version: 1, content: b.content, created_by: userId });
  await logAdminAction(admin, userId, 'ai.template.create', key);
  return apiOk({ created: true, id: tpl.id });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: { id?: string; action?: 'new_version' | 'update'; content?: string; name?: string; category?: string; description?: string; is_active?: boolean };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }
  if (!b.id) return apiErr('id required', 400);

  const { data: tpl } = await admin.from('ai_prompt_templates').select('id, current_version').eq('id', b.id).maybeSingle();
  if (!tpl) return apiErr('Template not found', 404);

  if (b.action === 'new_version') {
    if (!b.content?.trim()) return apiErr('content required', 400);
    const next = (tpl.current_version ?? 0) + 1;
    const ins = await admin.from('ai_prompt_versions').insert({ template_id: b.id, version: next, content: b.content, created_by: userId });
    if (ins.error) return apiErr(ins.error.message, 500);
    await admin.from('ai_prompt_templates').update({ current_version: next, updated_at: new Date().toISOString() }).eq('id', b.id);
    await logAdminAction(admin, userId, 'ai.template.version', b.id, { version: next });
    return apiOk({ version: next });
  }

  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
  if (typeof b.name === 'string' && b.name.trim()) updates.name = b.name.trim();
  if (typeof b.category === 'string' && b.category.trim()) updates.category = b.category.trim();
  if (typeof b.description === 'string') updates.description = b.description.trim().slice(0, 300) || null;
  if (typeof b.is_active === 'boolean') updates.is_active = b.is_active;
  const { error } = await admin.from('ai_prompt_templates').update(updates).eq('id', b.id);
  if (error) return apiErr(error.message, 500);
  await logAdminAction(admin, userId, 'ai.template.update', b.id, updates);
  return apiOk({ updated: true });
}

export async function DELETE(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;
  const id = new URL(req.url).searchParams.get('id') ?? '';
  if (!id) return apiErr('id required', 400);
  const { error } = await admin.from('ai_prompt_templates').delete().eq('id', id);
  if (error) return apiErr(error.message, 500);
  await logAdminAction(admin, userId, 'ai.template.delete', id);
  return apiOk({ deleted: true });
}
