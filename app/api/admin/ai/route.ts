import { apiErr, apiOk } from '@/lib/api-response';
import { requireAdmin } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const [providers, models, usageCount, feedbackCount, recentUsage, topModels] = await Promise.all([
    admin.from('ai_providers').select('id, display_name, is_active').order('id'),
    admin.from('ai_models').select('id, provider_id, display_name, is_active').order('id'),
    admin.from('ai_usage').select('id', { count: 'exact', head: true }),
    admin.from('ai_feedback').select('id', { count: 'exact', head: true }),
    admin
      .from('ai_usage')
      .select('id, user_id, provider_id, model_id, prompt_tokens, completion_tokens, created_at')
      .order('created_at', { ascending: false })
      .limit(40),
    admin.from('ai_usage').select('model_id, prompt_tokens, completion_tokens').limit(2000),
  ]);

  const modelTotals: Record<string, { calls: number; tokens: number }> = {};
  for (const row of topModels.data ?? []) {
    const key = row.model_id || 'unknown';
    if (!modelTotals[key]) modelTotals[key] = { calls: 0, tokens: 0 };
    modelTotals[key].calls += 1;
    modelTotals[key].tokens += (row.prompt_tokens ?? 0) + (row.completion_tokens ?? 0);
  }

  return apiOk({
    ready: !providers.error && !models.error,
    error: providers.error?.message || models.error?.message || usageCount.error?.message || null,
    providers: providers.data ?? [],
    models: models.data ?? [],
    totals: {
      usageRows: usageCount.count ?? 0,
      feedback: feedbackCount.count ?? 0,
    },
    recentUsage: recentUsage.data ?? [],
    byModel: Object.entries(modelTotals)
      .map(([model_id, v]) => ({ model_id, ...v }))
      .sort((a, b) => b.calls - a.calls)
      .slice(0, 12),
  });
}
