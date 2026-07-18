import { createClient } from '@supabase/supabase-js';
import { apiErr } from '@/lib/api-response';
import type { ChatMessage } from '@/lib/ai';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { createAdminClient } from '@/lib/supabase/admin';
import { adjustCredits, InsufficientCreditsError } from '@/lib/credits';
import { checkQuota, recordUsage, logAi, estimateTokens } from '@/lib/ai/engine';

import { buildFarvixoDefaultSystem } from '@/lib/engines/farvixo-ai-context';

const BURST_LIMIT = 12;              // per minute per IP
const FREE_DAILY_LIMIT = 50;        // server messages/day — then auto-falls back to free client AI
const DAY_MS = 24 * 60 * 60 * 1000;

async function getCallerPlan(req: Request): Promise<{ userId: string | null; plan: string }> {
  const env = getSupabaseEnv();
  if (!env) return { userId: null, plan: 'FREE' };

  try {
    const bearer = req.headers.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
    if (bearer && !bearer.startsWith('fx_')) {
      const supabase = createClient(env.url, env.anonKey, {
        global: { headers: { Authorization: `Bearer ${bearer}` } },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const {
        data: { user },
      } = await supabase.auth.getUser(bearer);
      if (!user) return { userId: null, plan: 'FREE' };
      const { data: profile } = await supabase
        .from('profiles')
        .select('plan')
        .eq('id', user.id)
        .maybeSingle();
      return { userId: user.id, plan: profile?.plan ?? 'FREE' };
    }

    const { supabase } = await createRouteHandlerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return { userId: null, plan: 'FREE' };
    const { data: profile } = await supabase
      .from('profiles')
      .select('plan')
      .eq('id', user.id)
      .maybeSingle();
    return { userId: user.id, plan: profile?.plan ?? 'FREE' };
  } catch {
    return { userId: null, plan: 'FREE' };
  }
}

export async function POST(req: Request) {
  const ip = clientIp(req);

  // Burst protection for everyone.
  const burst = rateLimit(`ai:burst:${ip}`, BURST_LIMIT, 60_000);
  if (!burst.allowed) return rateLimitResponse(burst.retryAfterSeconds);

  // Daily quota — Pro/Enterprise unlimited, everyone else 10/day.
  // Signed-in users past the free limit can keep going by spending 1 credit per message.
  const { userId, plan } = await getCallerPlan(req);

  // AI Management quota enforcement (daily/monthly, user- or plan-scoped).
  {
    const admin = createAdminClient();
    if (admin) {
      const quota = await checkQuota(admin, userId, plan);
      if (!quota.allowed) {
        return apiErr(
          `AI ${quota.reason} quota reached (${quota.used}/${quota.limit}). Try again later or upgrade your plan.`,
          429,
        );
      }
    }
  }

  if (plan !== 'PRO' && plan !== 'ENTERPRISE') {
    const identity = userId ? `user:${userId}` : `ip:${ip}`;
    const daily = rateLimit(`ai:daily:${identity}`, FREE_DAILY_LIMIT, DAY_MS);
    if (!daily.allowed) {
      const admin = userId ? createAdminClient() : null;
      if (admin && userId) {
        try {
          await adjustCredits(admin, userId, -1, 'ai_chat');
        } catch (err) {
          if (err instanceof InsufficientCreditsError) {
            return apiErr(
              'Daily free AI limit reached and you have no credits left. Get credits at /dashboard/credits, upgrade to Pro, or add your own Gemini API key in AI Settings.',
              429,
            );
          }
          return apiErr('Credit check failed — try again', 500);
        }
      } else {
        return apiErr(
          'Daily server AI limit reached — switching to free browser AI automatically. Or add your own Gemini key in AI Settings for unlimited.',
          429,
        );
      }
    }
  }

  try {
    const body = (await req.json()) as {
      messages?: ChatMessage[];
      system?: string;
      model?: string;
      temperature?: number;
    };

    if (!body.messages?.length) {
      return apiErr('messages array is required', 400);
    }
    if (body.messages.length > 50) {
      return apiErr('Conversation too long — start a new chat', 400);
    }
    const totalChars = body.messages.reduce((n, m) => n + (m.content?.length || 0), 0);
    if (totalChars > 100_000) {
      return apiErr('Message content too large', 400);
    }

    if (!process.env.GEMINI_API_KEY && !process.env.GROQ_API_KEY && !process.env.OPENROUTER_API_KEY) {
      // No server keys — Pollinations free fallback still works in streamWithFallback
    }

    const model = body.model && /^[a-z0-9./:_-]{1,80}$/i.test(body.model) ? body.model : undefined;

    const lastUser = [...(body.messages ?? [])].reverse().find((m) => m.role === 'user')?.content;
    const { withFarvixoIdentity } = await import('@/lib/engines/farvixo-identity');
    const system = withFarvixoIdentity(body.system || buildFarvixoDefaultSystem(lastUser)).slice(0, 16_000);
    const encoder = new TextEncoder();

    // Resolve the provider chain from the database (models → providers →
    // priority → health → Vault key). No hardcoded order.
    const routeAdmin = createAdminClient();
    const { resolveChain, streamChat } = await import('@/lib/ai/router');
    const chain = routeAdmin ? await resolveChain(routeAdmin, 'chat') : [];

    // Usage/observability accounting (recorded after the stream completes).
    const startedAt = Date.now();
    const inputChars = body.messages.map((m) => m.content ?? '').join(' ') + system;
    const providerPath: string[] = [];
    let usedProvider: string | null = null;
    let usedModel: string | null = model ?? null;
    let outputText = '';
    let exactUsage: { promptTokens: number; completionTokens: number } | null = null;

    const stream = new ReadableStream({
      async start(controller) {
        let ok = true;
        let errorMessage: string | null = null;
        let providerSent = false;
        const emit = (chunk: { text: string; provider: string; model: string }) => {
          if (chunk.provider !== usedProvider) { usedProvider = chunk.provider; usedModel = chunk.model; providerPath.push(chunk.provider); }
          if (!providerSent) { controller.enqueue(encoder.encode(`data: ${JSON.stringify({ provider: chunk.provider, model: chunk.model })}\n\n`)); providerSent = true; }
          // router yields cumulative text — send only the delta
          const delta = chunk.text.startsWith(outputText) ? chunk.text.slice(outputText.length) : chunk.text;
          outputText = chunk.text.length >= outputText.length ? chunk.text : outputText + chunk.text;
          if (delta) controller.enqueue(encoder.encode(`data: ${JSON.stringify({ text: delta })}\n\n`));
        };
        try {
          if (chain.length > 0) {
            for await (const chunk of streamChat(chain, body.messages!, system, body.temperature,
              (u) => { if (u) exactUsage = u; },
              (pid, err) => { void (routeAdmin && logAi(routeAdmin, { userId, providerId: pid, kind: 'error', level: 'warn', message: `retry: ${pid} — ${err}`, meta: { retry: true } })); })) {
              emit(chunk);
            }
          } else {
            // Safety net: keyless free provider chain when no DB provider is usable.
            const { streamWithFallback } = await import('@/lib/gemini/free-providers');
            for await (const chunk of streamWithFallback(body.messages!, system, model, body.temperature)) {
              outputText += chunk.text ?? '';
              if (chunk.provider !== usedProvider) { usedProvider = chunk.provider; usedModel = chunk.model; providerPath.push(chunk.provider); }
              if (!providerSent) { controller.enqueue(encoder.encode(`data: ${JSON.stringify({ provider: chunk.provider, model: chunk.model })}\n\n`)); providerSent = true; }
              controller.enqueue(encoder.encode(`data: ${JSON.stringify({ text: chunk.text })}\n\n`));
            }
          }
          controller.enqueue(encoder.encode('data: [DONE]\n\n'));
          controller.close();
        } catch (err) {
          ok = false;
          errorMessage = err instanceof Error ? err.message : 'AI generation failed';
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ error: errorMessage })}\n\n`));
          controller.close();
        } finally {
          const admin = routeAdmin ?? createAdminClient();
          if (admin) {
            const latencyMs = Date.now() - startedAt;
            // Exact tokens where the provider reported them; estimate otherwise.
            const promptTokens = exactUsage?.promptTokens ?? estimateTokens(inputChars);
            const completionTokens = exactUsage?.completionTokens ?? estimateTokens(outputText);
            void recordUsage(admin, {
              userId, providerId: usedProvider, modelId: usedModel,
              promptTokens, completionTokens, latencyMs,
              status: ok ? 'success' : 'error', errorCode: ok ? null : 'stream_error',
            });
            void logAi(admin, {
              userId, providerId: usedProvider, modelId: usedModel,
              kind: ok ? 'request' : 'error', level: ok ? 'info' : 'error',
              message: ok ? `chat ok via ${usedProvider}` : (errorMessage ?? 'error'),
              meta: { fallback_path: providerPath, retry_count: Math.max(0, providerPath.length - 1), latency_ms: latencyMs, token_source: exactUsage ? 'provider' : 'estimated' },
            });
          }
        }
      },
    });

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
      },
    });
  } catch {
    return apiErr('Invalid request body', 400);
  }
}

/** Flutter web / mobile preflight for cross-origin chat. */
export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
      'Access-Control-Max-Age': '86400',
    },
  });
}
