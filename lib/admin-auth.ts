import type { SupabaseClient } from '@supabase/supabase-js';
import { apiErr } from '@/lib/api-response';
import { isAdminRoleString } from '@/lib/auth';
import { createAdminClient } from '@/lib/supabase/admin';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';

export type AdminRole = 'USER' | 'ADMIN' | 'SUPER_ADMIN';

const AUDIT_FALLBACK_EVENT = '__admin_audit__';

export function isAdminRole(role: string | null | undefined): boolean {
  return isAdminRoleString(role);
}

type AdminContext = {
  userId: string;
  role: string;
  admin: SupabaseClient;
};

type RequireAdminResult =
  | { ok: true; ctx: AdminContext }
  | { ok: false; response: Response };

export async function requireAdmin(): Promise<RequireAdminResult> {
  const admin = createAdminClient();
  if (!admin) return { ok: false, response: apiErr('Admin backend not configured', 503) };

  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { ok: false, response: apiErr('Unauthorized', 401) };

  const { data: profile } = await admin.from('profiles').select('role').eq('id', user.id).single();
  if (!profile || !isAdminRole(profile.role)) {
    return { ok: false, response: apiErr('Forbidden — admin access required', 403) };
  }

  return { ok: true, ctx: { userId: user.id, role: profile.role, admin } };
}

export async function requireSuperAdmin(): Promise<RequireAdminResult> {
  const result = await requireAdmin();
  if (!result.ok) return result;
  if ((result.ctx.role ?? '').toUpperCase() !== 'SUPER_ADMIN') {
    return { ok: false, response: apiErr('Forbidden — super admin required', 403) };
  }
  return result;
}

/* ─────────────────── Granular permission enforcement ─────────────────── */

export type PermissionContext = AdminContext & { permissions: Set<string> };
type PermResult =
  | { ok: true; ctx: PermissionContext }
  | { ok: false; response: Response };

/**
 * Resolves the caller and loads their effective permissions ONCE per request
 * (single RPC, respecting role inheritance). SUPER_ADMIN bypasses all checks.
 */
async function authorize(): Promise<PermResult> {
  const admin = createAdminClient();
  if (!admin) return { ok: false, response: apiErr('Admin backend not configured', 503) };

  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { ok: false, response: apiErr('Unauthorized', 401) };

  const { data: profile } = await admin.from('profiles').select('role').eq('id', user.id).single();
  const role = (profile?.role ?? 'USER').toUpperCase();

  let permissions = new Set<string>();
  if (role !== 'SUPER_ADMIN') {
    const { data } = await admin.rpc('role_effective_permissions', { p_role: role });
    permissions = new Set(((data ?? []) as { permission_key: string }[]).map((r) => r.permission_key));
  }
  return { ok: true, ctx: { userId: user.id, role, admin, permissions } };
}

function isSuper(ctx: PermissionContext): boolean {
  return ctx.role === 'SUPER_ADMIN';
}

async function deny(ctx: PermissionContext, required: string | string[]): Promise<Response> {
  const req = Array.isArray(required) ? required.join(',') : required;
  // Audit: permission denied — required permission, effective role, user id.
  await logAdminAction(ctx.admin, ctx.userId, 'permission.denied', req, {
    required,
    role: ctx.role,
    user_id: ctx.userId,
  });
  return apiErr(`Forbidden — requires permission: ${req}`, 403, { code: 'FORBIDDEN' });
}

/** The caller's role + effective permissions (for the client to gate UI). */
export async function resolvePermissions(): Promise<{ role: string; permissions: string[]; isSuperAdmin: boolean } | null> {
  const base = await authorize();
  if (!base.ok) return null;
  const { ctx } = base;
  return { role: ctx.role, permissions: [...ctx.permissions], isSuperAdmin: isSuper(ctx) };
}

/** Require a single permission (SUPER_ADMIN bypasses). */
export async function requirePermission(permission: string): Promise<PermResult> {
  const base = await authorize();
  if (!base.ok) return base;
  const { ctx } = base;
  if (isSuper(ctx) || ctx.permissions.has(permission)) return { ok: true, ctx };
  return { ok: false, response: await deny(ctx, permission) };
}

/** Require ANY of the permissions. */
export async function requireAnyPermission(permissions: string[]): Promise<PermResult> {
  const base = await authorize();
  if (!base.ok) return base;
  const { ctx } = base;
  if (isSuper(ctx) || permissions.some((p) => ctx.permissions.has(p))) return { ok: true, ctx };
  return { ok: false, response: await deny(ctx, permissions) };
}

/** Require ALL of the permissions. */
export async function requireAllPermissions(permissions: string[]): Promise<PermResult> {
  const base = await authorize();
  if (!base.ok) return base;
  const { ctx } = base;
  if (isSuper(ctx) || permissions.every((p) => ctx.permissions.has(p))) return { ok: true, ctx };
  return { ok: false, response: await deny(ctx, permissions) };
}

export async function logAdminAction(
  admin: SupabaseClient,
  actorId: string,
  action: string,
  target?: string,
  meta?: Record<string, unknown>,
): Promise<void> {
  const { error } = await admin.from('admin_audit_log').insert({
    actor_id: actorId,
    action,
    target: target ?? null,
    meta: meta ?? {},
  });

  if (!error) return;

  // Fallback when admin_audit_log table is not migrated yet
  await admin.from('analytics_events').insert({
    event: AUDIT_FALLBACK_EVENT,
    user_id: actorId,
    props: { action, target: target ?? null, meta: meta ?? {}, actor_id: actorId },
  });
}

export async function listAdminAuditLogs(
  admin: SupabaseClient,
  opts: { page: number; limit: number; actorId?: string },
) {
  const from = (opts.page - 1) * opts.limit;
  const to = from + opts.limit - 1;

  let query = admin
    .from('admin_audit_log')
    .select('id, actor_id, action, target, meta, created_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, to);

  if (opts.actorId) query = query.eq('actor_id', opts.actorId);

  const { data, error, count } = await query;
  if (!error) {
    return { logs: data ?? [], total: count ?? 0, page: opts.page, pages: Math.ceil((count ?? 0) / opts.limit) };
  }

  // Fallback: analytics_events
  let fb = admin
    .from('analytics_events')
    .select('id, user_id, props, created_at', { count: 'exact' })
    .eq('event', AUDIT_FALLBACK_EVENT)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (opts.actorId) fb = fb.eq('user_id', opts.actorId);

  const { data: rows, count: fbCount } = await fb;
  const logs = (rows ?? []).map((r) => {
    const props = (r.props ?? {}) as Record<string, unknown>;
    return {
      id: r.id as string,
      actor_id: (props.actor_id as string) || (r.user_id as string) || '',
      action: (props.action as string) || 'unknown',
      target: (props.target as string) || null,
      meta: (props.meta as Record<string, unknown>) || {},
      created_at: r.created_at as string,
    };
  });

  return {
    logs,
    total: fbCount ?? 0,
    page: opts.page,
    pages: Math.ceil((fbCount ?? 0) / opts.limit),
  };
}
