import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requireAdmin } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const [ips, failed, events] = await Promise.all([
    admin.from('blocked_ips').select('ip, reason, created_at').order('created_at', { ascending: false }).limit(100),
    admin
      .from('failed_logins')
      .select('id, email, ip, reason, user_agent, created_at')
      .order('created_at', { ascending: false })
      .limit(50),
    admin
      .from('security_events')
      .select('id, user_id, event, severity, meta, created_at')
      .order('created_at', { ascending: false })
      .limit(50),
  ]);

  return apiOk({
    ready: !ips.error,
    errors: {
      blocked_ips: ips.error?.message ?? null,
      failed_logins: failed.error?.message ?? null,
      security_events: events.error?.message ?? null,
    },
    blockedIps: ips.data ?? [],
    failedLogins: failed.data ?? [],
    securityEvents: events.data ?? [],
  });
}

export async function POST(req: Request) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { ip?: string; reason?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }
  const ip = body.ip?.trim();
  if (!ip) return apiErr('IP / CIDR required', 400);

  const { error } = await admin.from('blocked_ips').upsert({
    ip,
    reason: body.reason?.trim() || null,
  });
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'security.block_ip', ip, { reason: body.reason });
  return apiOk({ blocked: true, ip });
}

export async function DELETE(req: Request) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  const url = new URL(req.url);
  const ip = url.searchParams.get('ip')?.trim();
  if (!ip) return apiErr('ip query required', 400);

  const { error } = await admin.from('blocked_ips').delete().eq('ip', ip);
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'security.unblock_ip', ip);
  return apiOk({ unblocked: true, ip });
}
