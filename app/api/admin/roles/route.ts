import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

const KEY_RE = /^[A-Z0-9_]{2,32}$/;

export async function GET(req: Request) {
  const auth = await requirePermission('roles.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const q = (url.searchParams.get('q') ?? '').trim().toLowerCase();
  const system = url.searchParams.get('system'); // 'true' | 'false' | null
  const page = Math.max(1, Number(url.searchParams.get('page') || 1));
  const limit = 20;
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = admin
    .from('roles')
    .select('key, name, description, is_system, inherits_from, sort_order, created_at', { count: 'exact' })
    .order('sort_order', { ascending: true })
    .range(from, to);
  if (q) query = query.or(`key.ilike.%${q}%,name.ilike.%${q}%`);
  if (system === 'true') query = query.eq('is_system', true);
  if (system === 'false') query = query.eq('is_system', false);

  const { data: roles, error, count } = await query;
  if (error) return apiErr(error.message, 500);

  // Permission counts per role + member counts (batched).
  const keys = (roles ?? []).map((r) => r.key);
  const permCounts: Record<string, number> = {};
  const memberCounts: Record<string, number> = {};
  if (keys.length) {
    const { data: rp } = await admin.from('role_permissions').select('role_key').in('role_key', keys);
    for (const row of rp ?? []) permCounts[row.role_key] = (permCounts[row.role_key] ?? 0) + 1;
    const { data: members } = await admin.from('profiles').select('role').in('role', keys);
    for (const row of members ?? []) memberCounts[row.role] = (memberCounts[row.role] ?? 0) + 1;
  }

  const rows = (roles ?? []).map((r) => ({
    ...r,
    permission_count: permCounts[r.key] ?? 0,
    member_count: memberCounts[r.key] ?? 0,
  }));

  return apiOk({ roles: rows, total: count ?? 0, page, pages: Math.ceil((count ?? 0) / limit) });
}

export async function POST(req: Request) {
  const auth = await requirePermission('roles.write');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { key?: string; name?: string; description?: string; inherits_from?: string | null };
  try { body = (await req.json()) as typeof body; } catch { return apiErr('Invalid body', 400); }

  const key = (body.key ?? '').trim().toUpperCase();
  const name = (body.name ?? '').trim();
  if (!KEY_RE.test(key)) return apiErr('Key must be 2–32 chars: A–Z, 0–9, underscore', 400);
  if (!name) return apiErr('Name is required', 400);

  const inherits = body.inherits_from ? body.inherits_from.trim().toUpperCase() : null;
  if (inherits) {
    const { data: parent } = await admin.from('roles').select('key').eq('key', inherits).maybeSingle();
    if (!parent) return apiErr('inherits_from role does not exist', 400);
  }

  const { error } = await admin.from('roles').insert({
    key, name,
    description: (body.description ?? '').trim().slice(0, 300) || null,
    is_system: false,
    inherits_from: inherits,
    sort_order: 100,
  });
  if (error) return apiErr(error.code === '23505' ? 'A role with that key already exists' : error.message, 400);

  await logAdminAction(admin, userId, 'role.create', key, { name, inherits });
  return apiOk({ created: true, key });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('roles.write');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { key?: string; name?: string; description?: string; inherits_from?: string | null };
  try { body = (await req.json()) as typeof body; } catch { return apiErr('Invalid body', 400); }

  const key = (body.key ?? '').trim().toUpperCase();
  if (!key) return apiErr('key required', 400);

  const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
  if (typeof body.name === 'string' && body.name.trim()) updates.name = body.name.trim();
  if (typeof body.description === 'string') updates.description = body.description.trim().slice(0, 300) || null;
  if (body.inherits_from !== undefined) {
    const inh = body.inherits_from ? body.inherits_from.trim().toUpperCase() : null;
    if (inh === key) return apiErr('A role cannot inherit from itself', 400);
    updates.inherits_from = inh;
  }
  if (Object.keys(updates).length === 1) return apiErr('Nothing to update', 400);

  const { error } = await admin.from('roles').update(updates).eq('key', key);
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'role.update', key, updates);
  return apiOk({ updated: true });
}

export async function DELETE(req: Request) {
  const auth = await requirePermission('roles.delete');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  const key = (new URL(req.url).searchParams.get('key') ?? '').trim().toUpperCase();
  if (!key) return apiErr('key required', 400);

  const { data: role } = await admin.from('roles').select('key, is_system').eq('key', key).maybeSingle();
  if (!role) return apiErr('Role not found', 404);
  if (role.is_system) return apiErr('System roles cannot be deleted', 400);

  const { count } = await admin.from('profiles').select('id', { count: 'exact', head: true }).eq('role', key);
  if ((count ?? 0) > 0) return apiErr(`Role is assigned to ${count} user(s); reassign them first`, 409);

  const { error } = await admin.from('roles').delete().eq('key', key);
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'role.delete', key);
  return apiOk({ deleted: true });
}
