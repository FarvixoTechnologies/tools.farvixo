import type { SupabaseClient } from '@supabase/supabase-js';
import type { ChatMessage } from '@/lib/ai';

/**
 * Database-driven AI runtime. The chain of providers to try is resolved entirely
 * from ai_models (priority) + ai_providers (is_active) + health + Vault keys.
 * No hardcoded provider order, no env-only routing (env is only a key fallback).
 */

const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://tools.farvixo.com';

/** Env var fallback per provider (used only when no Vault key exists). */
const ENV_KEY: Record<string, string | undefined> = {
  gemini: process.env.GEMINI_API_KEY,
  openai: process.env.OPENAI_API_KEY,
  anthropic: process.env.ANTHROPIC_API_KEY,
  groq: process.env.GROQ_API_KEY,
  openrouter: process.env.OPENROUTER_API_KEY,
  ollama: process.env.OLLAMA_API_KEY, // usually unset — ollama needs no key
};

export type TokenUsage = { promptTokens: number; completionTokens: number } | null;

export type ChainEntry = {
  providerId: string;
  modelId: string;
  baseUrl: string | null;
  key: string;
  keySource: 'vault' | 'env' | 'none';
};

/** Providers with a recent high failure rate (skipped during routing). */
export async function getUnhealthyProviders(admin: SupabaseClient): Promise<Set<string>> {
  const since = new Date(Date.now() - 6 * 3600_000).toISOString();
  const { data } = await admin.from('ai_usage').select('provider_id, status').gte('created_at', since).limit(5000);
  const acc: Record<string, { total: number; err: number }> = {};
  for (const r of data ?? []) {
    const p = (r.provider_id as string) || 'unknown';
    (acc[p] ??= { total: 0, err: 0 });
    acc[p].total += 1;
    if (r.status === 'error') acc[p].err += 1;
  }
  const bad = new Set<string>();
  for (const [p, v] of Object.entries(acc)) if (v.total >= 5 && v.err / v.total >= 0.5) bad.add(p);
  return bad;
}

/** Resolve the active provider key: Vault first, then env, else null. */
async function resolveKey(admin: SupabaseClient, providerId: string): Promise<{ key: string; source: 'vault' | 'env' } | null> {
  const { data: row } = await admin
    .from('ai_api_keys')
    .select('vault_secret_id')
    .eq('provider_id', providerId)
    .eq('status', 'active')
    .not('vault_secret_id', 'is', null)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (row?.vault_secret_id) {
    const { data: secret } = await admin.rpc('ai_key_read', { p_id: row.vault_secret_id });
    if (secret && String(secret).length > 0) return { key: String(secret), source: 'vault' };
  }
  const env = ENV_KEY[providerId];
  if (env) return { key: env, source: 'env' };
  // Ollama can run keyless.
  if (providerId === 'ollama') return { key: '', source: 'env' };
  return null;
}

/**
 * Build the ordered chain: active models by priority, active providers, skipping
 * unhealthy ones and those without a usable key. One provider per entry (best
 * model). Order comes purely from the database.
 */
export async function resolveChain(admin: SupabaseClient, category = 'chat'): Promise<ChainEntry[]> {
  const unhealthy = await getUnhealthyProviders(admin);

  const { data: models } = await admin
    .from('ai_models')
    .select('id, provider_id, priority, ai_providers!inner(id, is_active, base_url)')
    .eq('is_active', true)
    .eq('category', category)
    .order('priority', { ascending: true });

  const seen = new Set<string>();
  const chain: ChainEntry[] = [];
  for (const m of models ?? []) {
    const prov = (m as unknown as { ai_providers: { id: string; is_active: boolean; base_url: string | null } }).ai_providers;
    const pid = m.provider_id as string;
    if (!prov?.is_active || seen.has(pid) || unhealthy.has(pid)) continue;
    seen.add(pid);
    const resolved = await resolveKey(admin, pid);
    if (!resolved) continue; // no valid key → skip provider
    chain.push({ providerId: pid, modelId: m.id as string, baseUrl: prov.base_url, key: resolved.key, keySource: resolved.source });
  }
  return chain;
}

/* ─────────── Provider streamers (yield cumulative text; report usage) ─────────── */

function toOpenAiMessages(messages: ChatMessage[], system: string) {
  return [{ role: 'system' as const, content: system }, ...messages.map((m) => ({ role: m.role, content: m.content }))];
}

const OPENAI_COMPAT_URL: Record<string, string> = {
  openai: 'https://api.openai.com/v1/chat/completions',
  groq: 'https://api.groq.com/openai/v1/chat/completions',
  openrouter: 'https://openrouter.ai/api/v1/chat/completions',
};

async function* openaiCompatStream(
  url: string, key: string, model: string, messages: ChatMessage[], system: string,
  temperature: number | undefined, onUsage: (u: TokenUsage) => void, extraHeaders: Record<string, string> = {},
): AsyncGenerator<string> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}`, ...extraHeaders },
    body: JSON.stringify({ model, messages: toOpenAiMessages(messages, system), temperature: temperature ?? 0.7, stream: true, stream_options: { include_usage: true } }),
  });
  if (!res.ok) throw new Error(`${res.status}: ${(await res.text()).slice(0, 160)}`);
  const reader = res.body?.getReader();
  if (!reader) throw new Error('No response stream');
  const decoder = new TextDecoder();
  let buffer = '', full = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n'); buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      const payload = line.slice(5).trim();
      if (!payload || payload === '[DONE]') continue;
      try {
        const j = JSON.parse(payload) as { choices?: { delta?: { content?: string } }[]; usage?: { prompt_tokens?: number; completion_tokens?: number }; error?: { message?: string } };
        if (j.error?.message) throw new Error(j.error.message);
        if (j.usage) onUsage({ promptTokens: j.usage.prompt_tokens ?? 0, completionTokens: j.usage.completion_tokens ?? 0 });
        const delta = j.choices?.[0]?.delta?.content ?? '';
        if (delta) { full += delta; yield full; }
      } catch (e) { if (e instanceof Error && e.message !== 'Unexpected end of JSON input') throw e; }
    }
  }
}

async function* geminiStream(
  key: string, model: string, messages: ChatMessage[], system: string,
  temperature: number | undefined, onUsage: (u: TokenUsage) => void,
): AsyncGenerator<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse&key=${encodeURIComponent(key)}`;
  const contents = messages.map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] }));
  const res = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ contents, systemInstruction: { parts: [{ text: system }] }, generationConfig: { temperature: temperature ?? 0.7 } }),
  });
  if (!res.ok) throw new Error(`${res.status}: ${(await res.text()).slice(0, 160)}`);
  const reader = res.body?.getReader(); if (!reader) throw new Error('No response stream');
  const decoder = new TextDecoder(); let buffer = '', full = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n'); buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      try {
        const j = JSON.parse(line.slice(5).trim()) as { candidates?: { content?: { parts?: { text?: string }[] } }[]; usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number } };
        if (j.usageMetadata) onUsage({ promptTokens: j.usageMetadata.promptTokenCount ?? 0, completionTokens: j.usageMetadata.candidatesTokenCount ?? 0 });
        const t = j.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
        if (t) { full += t; yield full; }
      } catch { /* skip partial */ }
    }
  }
}

async function* anthropicStream(
  key: string, model: string, messages: ChatMessage[], system: string,
  temperature: number | undefined, onUsage: (u: TokenUsage) => void,
): AsyncGenerator<string> {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({ model, system, max_tokens: 4096, temperature: temperature ?? 0.7, stream: true, messages: messages.map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content })) }),
  });
  if (!res.ok) throw new Error(`${res.status}: ${(await res.text()).slice(0, 160)}`);
  const reader = res.body?.getReader(); if (!reader) throw new Error('No response stream');
  const decoder = new TextDecoder(); let buffer = '', full = '', pt = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n'); buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      try {
        const j = JSON.parse(line.slice(5).trim()) as { type?: string; delta?: { text?: string }; message?: { usage?: { input_tokens?: number } }; usage?: { output_tokens?: number } };
        if (j.message?.usage?.input_tokens) pt = j.message.usage.input_tokens;
        if (j.usage?.output_tokens) onUsage({ promptTokens: pt, completionTokens: j.usage.output_tokens });
        if (j.type === 'content_block_delta' && j.delta?.text) { full += j.delta.text; yield full; }
      } catch { /* skip */ }
    }
  }
}

export type StreamResult = { text: string; provider: string; model: string };

/**
 * Stream a chat completion driven by the DB chain, retrying down the chain on
 * failure. Calls onEvent for provider switches / retries so the caller can build
 * the fallback path and capture exact token usage.
 */
export async function* streamChat(
  chain: ChainEntry[],
  messages: ChatMessage[],
  system: string,
  temperature: number | undefined,
  onUsage: (u: TokenUsage) => void,
  onRetry: (providerId: string, error: string) => void,
): AsyncGenerator<StreamResult> {
  const errors: string[] = [];
  for (const entry of chain) {
    try {
      let gen: AsyncGenerator<string>;
      if (entry.providerId === 'gemini') gen = geminiStream(entry.key, entry.modelId, messages, system, temperature, onUsage);
      else if (entry.providerId === 'anthropic') gen = anthropicStream(entry.key, entry.modelId, messages, system, temperature, onUsage);
      else if (entry.providerId === 'ollama') {
        const base = (entry.baseUrl || 'http://localhost:11434').replace(/\/$/, '');
        gen = openaiCompatStream(`${base}/v1/chat/completions`, entry.key || 'ollama', entry.modelId, messages, system, temperature, onUsage);
      } else {
        const url = OPENAI_COMPAT_URL[entry.providerId];
        if (!url) { onRetry(entry.providerId, 'unsupported provider'); continue; }
        const extra: Record<string, string> = entry.providerId === 'openrouter' ? { 'HTTP-Referer': APP_URL, 'X-Title': 'Farvixo Tools' } : {};
        gen = openaiCompatStream(url, entry.key, entry.modelId, messages, system, temperature, onUsage, extra);
      }
      let any = false;
      for await (const text of gen) { any = true; yield { text, provider: entry.providerId, model: entry.modelId }; }
      if (any) return; // success
      onRetry(entry.providerId, 'empty response');
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'failed';
      errors.push(`${entry.providerId}: ${msg}`);
      onRetry(entry.providerId, msg);
    }
  }
  throw new Error(errors.length ? `All providers failed — ${errors.join(' · ')}` : 'No AI provider available (check models, keys, health in Admin → AI).');
}
