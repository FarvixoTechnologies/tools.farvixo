import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';
import { logAi } from '@/lib/ai/engine';

export const dynamic = 'force-dynamic';

const WINDOW_HOURS = 6;
const MIN_SAMPLES = 5;
const UNHEALTHY_FAILURE_RATE = 0.5;

type Health = { provider_id: string; requests: number; errors: number; failureRate: number; avgLatency: number; healthy: boolean };

async function computeHealth(admin: import('@supabase/supabase-js').SupabaseClient): Promise<Health[]> {
  const since = new Date(Date.now() - WINDOW_HOURS * 3600_000).toISOString();
  const { data } = await admin
    .from('ai_usage')
    .select('provider_id, status, latency_ms')
    .gte('created_at', since)
    .limit(5000);

  const acc: Record<string, { total: number; errors: number; latency: number; latN: number }> = {};
  for (const r of data ?? []) {
    const p = (r.provider_id as string) || 'unknown';
    (acc[p] ??= { total: 0, errors: 0, latency: 0, latN: 0 });
    acc[p].total += 1;
    if (r.status === 'error') acc[p].errors += 1;
    if (r.latency_ms != null) { acc[p].latency += r.latency_ms as number; acc[p].latN += 1; }
  }
  return Object.entries(acc).map(([provider_id, v]) => {
    const failureRate = v.total ? v.errors / v.total : 0;
    return {
      provider_id, requests: v.total, errors: v.errors,
      failureRate: Math.round(failureRate * 100) / 100,
      avgLatency: v.latN ? Math.round(v.latency / v.latN) : 0,
      healthy: !(v.total >= MIN_SAMPLES && failureRate >= UNHEALTHY_FAILURE_RATE),
    };
  });
}

export async function GET() {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  return apiOk({ windowHours: WINDOW_HOURS, health: await computeHealth(auth.ctx.admin) });
}

/** Auto-disable providers whose recent failure rate exceeds the threshold. */
export async function POST() {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  const health = await computeHealth(admin);
  const unhealthy = health.filter((h) => !h.healthy).map((h) => h.provider_id);

  if (unhealthy.length) {
    await admin.from('ai_providers').update({ is_active: false }).in('id', unhealthy);
    for (const p of unhealthy) {
      await logAi(admin, { providerId: p, kind: 'error', level: 'warn', message: `Provider ${p} auto-disabled (high failure rate)`, meta: { auto_disabled: true } });
    }
    await logAdminAction(admin, userId, 'ai.health.auto_disable', unhealthy.join(','), { unhealthy });
  }

  return apiOk({ health, disabled: unhealthy });
}
