import { apiOk } from '@/lib/api-response';
import { requireAdmin } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const limit = Math.min(100, Math.max(10, Number(url.searchParams.get('limit') || 40)));

  const [sessions, logins, devices] = await Promise.all([
    admin
      .from('user_sessions')
      .select('id, user_id, device_id, provider, ip, user_agent, created_at, last_active_at, revoked_at')
      .order('last_active_at', { ascending: false })
      .limit(limit),
    admin
      .from('login_history')
      .select('id, user_id, provider, success, ip, user_agent, created_at')
      .order('created_at', { ascending: false })
      .limit(limit),
    admin
      .from('devices')
      .select('id, user_id, device_id, platform, app_version, last_seen_at, created_at')
      .order('last_seen_at', { ascending: false })
      .limit(limit),
  ]);

  return apiOk({
    ready: !sessions.error || !logins.error || !devices.error,
    errors: {
      sessions: sessions.error?.message ?? null,
      logins: logins.error?.message ?? null,
      devices: devices.error?.message ?? null,
    },
    sessions: sessions.data ?? [],
    logins: logins.data ?? [],
    devices: devices.data ?? [],
  });
}
