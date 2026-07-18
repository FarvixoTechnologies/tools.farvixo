import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  const { data, error } = await auth.ctx.admin
    .from('ai_quotas')
    .select('id, scope, scope_key, daily_limit, monthly_limit, updated_at')
    .order('scope').order('scope_key');
  if (error) return apiErr(error.message, 500);
  return apiOk({ quotas: data ?? [] });
}

/** Upsert a quota for a plan or a specific user. */
export async function PUT(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: { scope?: string; scope_key?: string; daily_limit?: number | null; monthly_limit?: number | null };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }

  const scope = (b.scope ?? '').toLowerCase();
  const scopeKey = (b.scope_key ?? '').trim();
  if (!['plan', 'user'].includes(scope) || !scopeKey) return apiErr('scope (plan|user) and scope_key required', 400);

  const norm = (v: number | null | undefined) =>
    v === null || v === undefined || Number(v) < 0 ? null : Math.floor(Number(v));

  const { error } = await admin.from('ai_quotas').upsert({
    scope, scope_key: scope === 'plan' ? scopeKey.toUpperCase() : scopeKey,
    daily_limit: norm(b.daily_limit),
    monthly_limit: norm(b.monthly_limit),
    updated_at: new Date().toISOString(),
  }, { onConflict: 'scope,scope_key' });
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'ai.quota.set', `${scope}:${scopeKey}`, { daily: b.daily_limit, monthly: b.monthly_limit });
  return apiOk({ saved: true });
}
