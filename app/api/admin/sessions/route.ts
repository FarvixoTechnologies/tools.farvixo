import type { SupabaseClient } from '@supabase/supabase-js';
import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

type Row = Record<string, unknown> & { user_id?: string | null };

/** Attach { email, full_name } to rows by their user_id (single batched query). */
async function withUsers<T extends Row>(
  admin: SupabaseClient,
  rows: T[],
): Promise<(T & { email: string | null; full_name: string | null })[]> {
  const ids = [...new Set(rows.map((r) => r.user_id).filter((v): v is string => !!v))];
  const map: Record<string, { email: string | null; full_name: string | null }> = {};
  if (ids.length) {
    const { data } = await admin.from('profiles').select('id, email, full_name').in('id', ids);
    for (const p of (data ?? []) as { id: string; email: string | null; full_name: string | null }[]) {
      map[p.id] = { email: p.email, full_name: p.full_name };
    }
  }
  return rows.map((r) => ({
    ...r,
    email: (r.user_id && map[r.user_id]?.email) || null,
    full_name: (r.user_id && map[r.user_id]?.full_name) || null,
  }));
}

export async function GET(req: Request) {
  const auth = await requirePermission('security.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const limit = Math.min(200, Math.max(10, Number(url.searchParams.get('limit') || 50)));
  const view = url.searchParams.get('view') ?? 'all'; // all | active | revoked

  let sessionsQuery = admin
    .from('user_sessions')
    .select('id, user_id, device_id, provider, ip, user_agent, created_at, last_active_at, revoked_at')
    .order('last_active_at', { ascending: false })
    .limit(limit);
  if (view === 'active') sessionsQuery = sessionsQuery.is('revoked_at', null);
  if (view === 'revoked') sessionsQuery = sessionsQuery.not('revoked_at', 'is', null);

  const [sessions, logins, devices] = await Promise.all([
    sessionsQuery,
    admin
      .from('login_history')
      .select('id, user_id, provider, success, ip, user_agent, created_at')
      .order('created_at', { ascending: false })
      .limit(limit),
    admin
      .from('devices')
      .select('id, user_id, device_id, platform, app_version, user_agent, last_seen_at, created_at')
      .order('last_seen_at', { ascending: false })
      .limit(limit),
  ]);

  const err = sessions.error || logins.error || devices.error;
  if (err) return apiErr(err.message, 500);

  const [sessionRows, loginRows, deviceRows] = await Promise.all([
    withUsers(admin, (sessions.data ?? []) as Row[]),
    withUsers(admin, (logins.data ?? []) as Row[]),
    withUsers(admin, (devices.data ?? []) as Row[]),
  ]);

  return apiOk({
    ready: true,
    sessions: sessionRows,
    logins: loginRows,
    devices: deviceRows,
  });
}

export async function POST(req: Request) {
  const auth = await requirePermission('security.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId: actorId } = auth.ctx;

  let body: { action?: string; session_id?: string; user_id?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }

  const nowIso = new Date().toISOString();

  if (body.action === 'revoke_session') {
    if (!body.session_id) return apiErr('session_id required', 400);
    const { error } = await admin
      .from('user_sessions')
      .update({ revoked_at: nowIso, revoked_by: actorId })
      .eq('id', body.session_id)
      .is('revoked_at', null);
    if (error) return apiErr(error.message, 500);
    await logAdminAction(admin, actorId, 'session.revoke', body.session_id);
    return apiOk({ revoked: true });
  }

  if (body.action === 'force_logout') {
    if (!body.user_id) return apiErr('user_id required', 400);
    const { error, count } = await admin
      .from('user_sessions')
      .update({ revoked_at: nowIso, revoked_by: actorId }, { count: 'exact' })
      .eq('user_id', body.user_id)
      .is('revoked_at', null);
    if (error) return apiErr(error.message, 500);
    await logAdminAction(admin, actorId, 'session.force_logout', body.user_id, { revoked: count ?? 0 });
    return apiOk({ forced: true, revoked: count ?? 0 });
  }

  return apiErr('Unknown action', 400);
}
