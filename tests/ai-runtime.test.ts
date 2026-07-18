import { describe, it, expect, vi } from 'vitest';
import { estimateTokens, computeCost, checkQuota, recordUsage, FALLBACK_ORDER } from '@/lib/ai/engine';
import { resolveChain } from '@/lib/ai/router';

/**
 * Minimal chainable mock of the Supabase service client. `handlers` maps a table
 * name to the resolved result for a terminal await; `rpc` maps rpc name → value.
 */
function mockAdmin(opts: {
  tables?: Record<string, unknown>;
  counts?: Record<string, number>;
  rpc?: Record<string, unknown>;
}) {
  const rpc = vi.fn(async (name: string) => ({ data: opts.rpc?.[name] ?? null, error: null }));
  const from = vi.fn((table: string) => {
    const result = {
      data: opts.tables?.[table] ?? null,
      count: opts.counts?.[table] ?? 0,
      error: null,
    };
    const builder: Record<string, unknown> = {};
    // every chained method returns the builder; awaiting resolves to `result`
    for (const m of ['select', 'eq', 'or', 'gte', 'not', 'order', 'limit', 'in']) {
      builder[m] = () => builder;
    }
    builder.maybeSingle = async () => result;
    builder.single = async () => result;
    builder.then = (res: (v: typeof result) => unknown) => res(result);
    return builder;
  });
  return { from, rpc } as unknown as import('@supabase/supabase-js').SupabaseClient;
}

describe('estimateTokens', () => {
  it('estimates ~4 chars per token', () => {
    expect(estimateTokens('')).toBe(0);
    expect(estimateTokens('abcd')).toBe(1);
    expect(estimateTokens('a'.repeat(400))).toBe(100);
  });
});

describe('FALLBACK_ORDER', () => {
  it('lists all six providers', () => {
    expect(FALLBACK_ORDER).toEqual(['gemini', 'openrouter', 'groq', 'anthropic', 'openai', 'ollama']);
  });
});

describe('computeCost', () => {
  it('multiplies tokens by model pricing', async () => {
    const admin = mockAdmin({ tables: { ai_models: { input_cost_per_1k: 0.001, output_cost_per_1k: 0.002 } } });
    const cost = await computeCost(admin, 'gpt-4o', 1000, 500);
    expect(cost).toBeCloseTo(0.001 + 0.001, 6); // 1k in @0.001 + 0.5k out @0.002
  });
  it('returns 0 for unknown model', async () => {
    const admin = mockAdmin({ tables: { ai_models: null } });
    expect(await computeCost(admin, 'nope', 1000, 1000)).toBe(0);
  });
});

describe('checkQuota', () => {
  it('allows anonymous (no userId)', async () => {
    const admin = mockAdmin({});
    expect((await checkQuota(admin, null, 'FREE')).allowed).toBe(true);
  });
  it('blocks when daily limit exceeded', async () => {
    const admin = mockAdmin({
      tables: { ai_quotas: [{ scope: 'plan', scope_key: 'FREE', daily_limit: 25, monthly_limit: 300 }] },
      counts: { ai_usage: 25 },
    });
    const r = await checkQuota(admin, 'u1', 'FREE');
    expect(r.allowed).toBe(false);
    expect(r.reason).toBe('daily');
  });
  it('allows under the limit', async () => {
    const admin = mockAdmin({
      tables: { ai_quotas: [{ scope: 'plan', scope_key: 'FREE', daily_limit: 25, monthly_limit: 300 }] },
      counts: { ai_usage: 3 },
    });
    expect((await checkQuota(admin, 'u1', 'FREE')).allowed).toBe(true);
  });
  it('allows when no quota configured', async () => {
    const admin = mockAdmin({ tables: { ai_quotas: [] }, counts: { ai_usage: 999 } });
    expect((await checkQuota(admin, 'u1', 'ENTERPRISE')).allowed).toBe(true);
  });
});

describe('recordUsage', () => {
  it('never throws even if insert fails', async () => {
    const admin = { from: () => ({ insert: async () => { throw new Error('db down'); } }) } as unknown as import('@supabase/supabase-js').SupabaseClient;
    await expect(recordUsage(admin, { userId: 'u', providerId: 'gemini', modelId: 'm', promptTokens: 1, completionTokens: 1, latencyMs: 1, status: 'success' })).resolves.toBeUndefined();
  });
});

describe('resolveChain', () => {
  it('skips providers without a usable key', async () => {
    // model exists, provider active, but no vault key and no env key → skipped
    const admin = mockAdmin({
      tables: {
        ai_usage: [],
        ai_models: [{ id: 'gpt-4o', provider_id: 'openai', priority: 1, ai_providers: { id: 'openai', is_active: true, base_url: null } }],
        ai_api_keys: null,
      },
    });
    const chain = await resolveChain(admin, 'chat');
    expect(chain.length).toBe(0);
  });
});
