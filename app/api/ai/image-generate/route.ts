import { apiErr } from '@/lib/api-response';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';
import { createAdminClient } from '@/lib/supabase/admin';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { checkQuota, recordUsage, logAi } from '@/lib/ai/engine';

async function caller(): Promise<{ userId: string | null; plan: string }> {
  if (!getSupabaseEnv()) return { userId: null, plan: 'FREE' };
  try {
    const { supabase } = await createRouteHandlerClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return { userId: null, plan: 'FREE' };
    const { data } = await supabase.from('profiles').select('plan').eq('id', user.id).maybeSingle();
    return { userId: user.id, plan: data?.plan ?? 'FREE' };
  } catch { return { userId: null, plan: 'FREE' }; }
}

const BURST_LIMIT = 10;
const DAILY_LIMIT = 200;
const DAY_MS = 24 * 60 * 60 * 1000;

interface ImageGenBody {
  prompt?: string;
  negative?: string;
  width?: number;
  height?: number;
  seed?: number;
  model?: string;
  enhance?: boolean;
}

function clampDim(n: unknown, fallback: number): number {
  const v = typeof n === 'number' ? n : fallback;
  return Math.min(2048, Math.max(256, Math.round(v)));
}

function buildPrompt(prompt: string, negative?: string): string {
  const p = prompt.trim().slice(0, 1800);
  if (!negative?.trim()) return p;
  return `${p} --no ${negative.trim().slice(0, 400)}`;
}

async function fetchImage(url: string): Promise<ArrayBuffer | null> {
  try {
    const res = await fetch(url, {
      headers: {
        Accept: 'image/*,*/*',
        'User-Agent': 'FarvixoTools/1.0 (free image proxy)',
      },
      cache: 'no-store',
    });
    if (!res.ok) return null;
    const buf = await res.arrayBuffer();
    if (buf.byteLength < 800) return null;
    return buf;
  } catch {
    return null;
  }
}

export async function POST(req: Request) {
  const ip = clientIp(req);

  const burst = rateLimit(`img:burst:${ip}`, BURST_LIMIT, 60_000);
  if (!burst.allowed) return rateLimitResponse(burst.retryAfterSeconds);

  const daily = rateLimit(`img:daily:${ip}`, DAILY_LIMIT, DAY_MS);
  if (!daily.allowed) {
    return apiErr('Daily free limit reached — try again in a few hours.', 429);
  }

  // AI Management quota enforcement.
  const { userId, plan } = await caller();
  const admin = createAdminClient();
  if (admin) {
    const q = await checkQuota(admin, userId, plan);
    if (!q.allowed) return apiErr(`AI ${q.reason} quota reached (${q.used}/${q.limit}).`, 429);
  }
  const startedAt = Date.now();

  let body: ImageGenBody;
  try {
    body = (await req.json()) as ImageGenBody;
  } catch {
    return apiErr('Invalid JSON body', 400);
  }

  const prompt = body.prompt?.trim();
  if (!prompt) return apiErr('prompt is required', 400);

  const width = clampDim(body.width, 1024);
  const height = clampDim(body.height, 1024);
  const model = typeof body.model === 'string' && /^[a-z0-9-]{1,32}$/i.test(body.model) ? body.model : 'flux';
  const seed = typeof body.seed === 'number' ? Math.floor(body.seed) : Math.floor(Math.random() * 1e9);

  const params = new URLSearchParams({
    width: String(width),
    height: String(height),
    seed: String(seed),
    model,
    nologo: 'true',
    enhance: body.enhance ? 'true' : 'false',
  });

  const apiKey = process.env.POLLINATIONS_API_KEY?.trim();
  if (apiKey) params.set('key', apiKey);

  const fullPrompt = buildPrompt(prompt, body.negative);
  const encoded = encodeURIComponent(fullPrompt);

  // Free tier — image.pollinations.ai (no key, no 401)
  const urls = [
    `https://image.pollinations.ai/prompt/${encoded}?${params}`,
  ];

  // Premium path only when admin configured a key
  if (apiKey) {
    urls.push(`https://gen.pollinations.ai/image/${encoded}?${params}`);
  }

  for (const url of urls) {
    const buf = await fetchImage(url);
    if (buf) {
      if (admin) {
        void recordUsage(admin, { userId, providerId: 'pollinations', modelId: model, promptTokens: 0, completionTokens: 0, latencyMs: Date.now() - startedAt, status: 'success' });
        void logAi(admin, { userId, providerId: 'pollinations', modelId: model, kind: 'request', message: 'image ok', meta: { width, height } });
      }
      return new Response(buf, {
        status: 200,
        headers: {
          'Content-Type': 'image/jpeg',
          'Cache-Control': 'private, no-store',
        },
      });
    }
  }

  if (admin) {
    void recordUsage(admin, { userId, providerId: 'pollinations', modelId: model, promptTokens: 0, completionTokens: 0, latencyMs: Date.now() - startedAt, status: 'error', errorCode: 'image_unavailable' });
    void logAi(admin, { userId, providerId: 'pollinations', modelId: model, kind: 'error', level: 'error', message: 'image server busy' });
  }
  return apiErr(
    'Free image server busy — please wait 10 seconds and try again, or use a shorter prompt.',
    502,
  );
}
