import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Server-side AI execution engine: quota enforcement, cost calculation, and
 * usage/log recording against the AI Management tables. All functions are
 * best-effort for recording (never throw into the request path) but strict for
 * quota (the caller must honour a false result with a 429).
 */

/** Rough token estimate when a provider doesn't return usage (≈4 chars/token). */
export function estimateTokens(text: string): number {
  return Math.max(0, Math.ceil((text?.length ?? 0) / 4));
}

/** Provider fallback order (spec §2). */
export const FALLBACK_ORDER = ['gemini', 'openrouter', 'groq', 'anthropic', 'openai', 'ollama'] as const;

export type UsageRow = {
  userId: string | null;
  providerId: string | null;
  modelId: string | null;
  promptTokens: number;
  completionTokens: number;
  latencyMs: number;
  status: 'success' | 'error';
  errorCode?: string | null;
};

/** Cost in USD from ai_models pricing (per 1k tokens). Missing model → 0. */
export async function computeCost(
  admin: SupabaseClient,
  modelId: string | null,
  promptTokens: number,
  completionTokens: number,
): Promise<number> {
  if (!modelId) return 0;
  const { data } = await admin
    .from('ai_models')
    .select('input_cost_per_1k, output_cost_per_1k')
    .eq('id', modelId)
    .maybeSingle();
  if (!data) return 0;
  const cost =
    (promptTokens / 1000) * Number(data.input_cost_per_1k ?? 0) +
    (completionTokens / 1000) * Number(data.output_cost_per_1k ?? 0);
  return Math.round(cost * 1e6) / 1e6;
}

/** Insert an ai_usage row (with computed cost). Never throws. */
export async function recordUsage(admin: SupabaseClient, u: UsageRow): Promise<void> {
  try {
    const cost = await computeCost(admin, u.modelId, u.promptTokens, u.completionTokens);
    await admin.from('ai_usage').insert({
      user_id: u.userId,
      provider_id: u.providerId,
      model_id: u.modelId,
      prompt_tokens: u.promptTokens,
      completion_tokens: u.completionTokens,
      cost,
      latency_ms: u.latencyMs,
      status: u.status,
      error_code: u.errorCode ?? null,
    });
  } catch {
    /* observability must never break the request */
  }
}

/** Insert an ai_logs row. Never throws. */
export async function logAi(
  admin: SupabaseClient,
  entry: {
    userId?: string | null;
    providerId?: string | null;
    modelId?: string | null;
    kind?: 'request' | 'error' | 'moderation';
    level?: 'info' | 'warn' | 'error';
    message?: string;
    meta?: Record<string, unknown>;
  },
): Promise<void> {
  try {
    await admin.from('ai_logs').insert({
      user_id: entry.userId ?? null,
      provider_id: entry.providerId ?? null,
      model_id: entry.modelId ?? null,
      kind: entry.kind ?? 'request',
      level: entry.level ?? 'info',
      message: entry.message ?? null,
      meta: entry.meta ?? {},
    });
  } catch {
    /* best-effort */
  }
}

export type QuotaResult = { allowed: boolean; reason?: string; scope?: string; limit?: number; used?: number };

function startOfDay(): string {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}
function startOfMonth(): string {
  const d = new Date();
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)).toISOString();
}

/**
 * Enforce AI quotas before a request. A user-scoped quota overrides the plan
 * quota. Returns { allowed:false } with a reason when the daily or monthly cap
 * is reached; the caller must respond 429.
 */
export async function checkQuota(
  admin: SupabaseClient,
  userId: string | null,
  plan: string,
): Promise<QuotaResult> {
  if (!userId) return { allowed: true }; // anonymous handled by IP rate limits upstream

  const [{ data: quotas }, dayCount, monthCount] = await Promise.all([
    admin.from('ai_quotas').select('scope, scope_key, daily_limit, monthly_limit')
      .or(`and(scope.eq.user,scope_key.eq.${userId}),and(scope.eq.plan,scope_key.eq.${plan.toUpperCase()})`),
    admin.from('ai_usage').select('id', { count: 'exact', head: true }).eq('user_id', userId).gte('created_at', startOfDay()),
    admin.from('ai_usage').select('id', { count: 'exact', head: true }).eq('user_id', userId).gte('created_at', startOfMonth()),
  ]);

  const userQuota = (quotas ?? []).find((q) => q.scope === 'user');
  const planQuota = (quotas ?? []).find((q) => q.scope === 'plan');
  const active = userQuota ?? planQuota;
  if (!active) return { allowed: true };

  const usedDay = dayCount.count ?? 0;
  const usedMonth = monthCount.count ?? 0;

  if (active.daily_limit != null && usedDay >= active.daily_limit) {
    return { allowed: false, reason: 'daily', scope: active.scope, limit: active.daily_limit, used: usedDay };
  }
  if (active.monthly_limit != null && usedMonth >= active.monthly_limit) {
    return { allowed: false, reason: 'monthly', scope: active.scope, limit: active.monthly_limit, used: usedMonth };
  }
  return { allowed: true };
}
