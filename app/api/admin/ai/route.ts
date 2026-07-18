import { apiOk } from '@/lib/api-response';
import { requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

/** Realtime AI dashboard: KPIs (24h + 30d), providers/models, recent activity. */
export async function GET() {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const now = new Date();
  const dayAgo = new Date(now.getTime() - 86_400_000).toISOString();
  const monthAgo = new Date(now.getTime() - 30 * 86_400_000).toISOString();

  const [day, month, providers, models, recentUsage, recentLogs, byModelRows] = await Promise.all([
    admin.rpc('ai_usage_stats', { p_from: dayAgo, p_to: now.toISOString() }),
    admin.rpc('ai_usage_stats', { p_from: monthAgo, p_to: now.toISOString() }),
    admin.from('ai_providers').select('id, display_name, is_active').order('sort_order'),
    admin.from('ai_models').select('id, provider_id, display_name, category, is_active, priority').order('priority'),
    admin.from('ai_usage').select('id, user_id, provider_id, model_id, total_tokens, cost, latency_ms, status, created_at').order('created_at', { ascending: false }).limit(20),
    admin.from('ai_logs').select('id, kind, level, message, model_id, created_at').order('created_at', { ascending: false }).limit(20),
    admin.from('ai_usage').select('model_id, total_tokens, cost, status').limit(3000),
  ]);

  const byModel: Record<string, { calls: number; tokens: number; cost: number; errors: number }> = {};
  for (const r of byModelRows.data ?? []) {
    const k = (r.model_id as string) || 'unknown';
    (byModel[k] ??= { calls: 0, tokens: 0, cost: 0, errors: 0 });
    byModel[k].calls += 1;
    byModel[k].tokens += (r.total_tokens as number) ?? 0;
    byModel[k].cost += Number(r.cost ?? 0);
    if (r.status === 'error') byModel[k].errors += 1;
  }

  const zero = { requests: 0, tokens: 0, cost: 0, avg_latency: 0, success: 0, errors: 0 };
  const d = (day.data?.[0] as typeof zero | undefined) ?? zero;
  const m = (month.data?.[0] as typeof zero | undefined) ?? zero;

  return apiOk({
    kpis: {
      day: { ...d, successRate: d.requests ? Math.round((d.success / d.requests) * 100) : 100 },
      month: m,
    },
    providers: providers.data ?? [],
    models: models.data ?? [],
    recentUsage: recentUsage.data ?? [],
    recentLogs: recentLogs.data ?? [],
    byModel: Object.entries(byModel).map(([model_id, v]) => ({ model_id, ...v })).sort((a, b) => b.calls - a.calls).slice(0, 12),
  });
}
