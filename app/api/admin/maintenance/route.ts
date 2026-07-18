import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requirePermission('system.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const [maint, flags, remote] = await Promise.all([
    admin.from('maintenance').select('*').eq('id', 1).maybeSingle(),
    admin.from('feature_flags').select('key, enabled, rollout_pct, meta, updated_at').order('key'),
    admin.from('remote_config').select('key, value, updated_at').order('key'),
  ]);

  return apiOk({
    ready: !maint.error,
    error: maint.error?.message || flags.error?.message || remote.error?.message || null,
    maintenance: maint.data ?? { id: 1, is_active: false, message: null, starts_at: null, ends_at: null },
    featureFlags: flags.data ?? [],
    remoteConfig: remote.data ?? [],
  });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('system.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: {
    is_active?: boolean;
    message?: string | null;
    starts_at?: string | null;
    ends_at?: string | null;
  };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }

  const row = {
    id: 1,
    is_active: !!body.is_active,
    message: body.message ?? null,
    starts_at: body.starts_at || null,
    ends_at: body.ends_at || null,
  };

  const { error } = await admin.from('maintenance').upsert(row, { onConflict: 'id' });
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'maintenance.update', '1', row);
  return apiOk({ updated: true, maintenance: row });
}
