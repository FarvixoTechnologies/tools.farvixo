import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requireAdmin, requireSuperAdmin } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

type RouteCtx = { params: Promise<{ key: string }> };

export async function GET(_req: Request, ctx: RouteCtx) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;
  const key = (await ctx.params).key.toUpperCase();

  const { data: role, error } = await admin
    .from('roles')
    .select('key, name, description, is_system, inherits_from, sort_order')
    .eq('key', key)
    .maybeSingle();
  if (error) return apiErr(error.message, 500);
  if (!role) return apiErr('Role not found', 404);

  const [{ data: direct }, { data: effective }] = await Promise.all([
    admin.from('role_permissions').select('permission_key').eq('role_key', key),
    admin.rpc('role_effective_permissions', { p_role: key }),
  ]);

  return apiOk({
    role,
    direct: (direct ?? []).map((r) => r.permission_key),
    // Effective = direct ∪ inherited (from inherits_from chain).
    effective: (effective ?? []).map((r: { permission_key: string }) => r.permission_key),
  });
}

/** Replace a role's DIRECT permission set (the matrix save). */
export async function PUT(req: Request, ctx: RouteCtx) {
  const auth = await requireSuperAdmin();
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;
  const key = (await ctx.params).key.toUpperCase();

  let body: { permissions?: string[] };
  try { body = (await req.json()) as typeof body; } catch { return apiErr('Invalid body', 400); }
  if (!Array.isArray(body.permissions)) return apiErr('permissions[] required', 400);

  const { data: role } = await admin.from('roles').select('key').eq('key', key).maybeSingle();
  if (!role) return apiErr('Role not found', 404);

  // Validate against real permission keys.
  const { data: valid } = await admin.from('permissions').select('key');
  const validSet = new Set((valid ?? []).map((p) => p.key));
  const wanted = [...new Set(body.permissions)].filter((p) => validSet.has(p));

  // Replace set: delete all, then insert wanted.
  const del = await admin.from('role_permissions').delete().eq('role_key', key);
  if (del.error) return apiErr(del.error.message, 500);
  if (wanted.length) {
    const ins = await admin.from('role_permissions').insert(wanted.map((p) => ({ role_key: key, permission_key: p })));
    if (ins.error) return apiErr(ins.error.message, 500);
  }

  await logAdminAction(admin, userId, 'role.set_permissions', key, { count: wanted.length });
  return apiOk({ saved: true, count: wanted.length });
}
