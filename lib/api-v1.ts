import type { SupabaseClient, User } from '@supabase/supabase-js';
import { apiErr, apiOk } from '@/lib/api-response';
import { createAdminClient } from '@/lib/supabase/admin';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import {
  adjustCredits,
  authenticateApiKey,
  InsufficientCreditsError,
  type ApiKeyAuth,
} from '@/lib/credits';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

/** Shared plumbing for the Farvixo Tools public API (/api/v1/*). */

export interface V1Context {
  admin: SupabaseClient;
  auth: ApiKeyAuth;
}

export interface V1SessionContext {
  supabase: SupabaseClient;
  admin: SupabaseClient | null;
  user: User;
}

type RequireKeyResult = { ok: true; ctx: V1Context } | { ok: false; response: Response };
type RequireSessionResult =
  | { ok: true; ctx: V1SessionContext }
  | { ok: false; response: Response };

export type Pagination = {
  page: number;
  pageSize: number;
  from: number;
  to: number;
};

/** Parse ?page=&limit= (or pageSize=) with sane caps. */
export function parsePagination(req: Request, defaults?: { pageSize?: number; max?: number }): Pagination {
  const url = new URL(req.url);
  const page = Math.max(1, Number(url.searchParams.get('page') || 1) || 1);
  const max = defaults?.max ?? 100;
  const pageSize = Math.min(
    max,
    Math.max(1, Number(url.searchParams.get('limit') || url.searchParams.get('pageSize') || defaults?.pageSize || 25) || 25),
  );
  const from = (page - 1) * pageSize;
  return { page, pageSize, from, to: from + pageSize - 1 };
}

/** Sort helper: ?sort=field&order=asc|desc */
export function parseSort(
  req: Request,
  allowed: string[],
  fallback: { sort: string; ascending: boolean },
): { sort: string; ascending: boolean } {
  const url = new URL(req.url);
  const sort = url.searchParams.get('sort')?.trim() || fallback.sort;
  const order = (url.searchParams.get('order') || 'desc').toLowerCase();
  if (!allowed.includes(sort)) return fallback;
  return { sort, ascending: order === 'asc' };
}

/** Rate-limit by IP, then resolve the Bearer API key. */
export async function requireApiKey(req: Request, limitPerMin = 60): Promise<RequireKeyResult> {
  const rl = rateLimit(`v1:${clientIp(req)}`, limitPerMin, 60_000);
  if (!rl.allowed) return { ok: false, response: rateLimitResponse(rl.retryAfterSeconds) };

  const admin = createAdminClient();
  if (!admin) return { ok: false, response: apiErr('API is not configured', 503, { code: 'SERVICE_UNAVAILABLE' }) };

  const auth = await authenticateApiKey(admin, req);
  if (!auth) {
    return {
      ok: false,
      response: apiErr('Invalid or revoked API key. Pass it as: Authorization: Bearer fx_live_...', 401, {
        code: 'UNAUTHORIZED',
      }),
    };
  }

  return { ok: true, ctx: { admin, auth } };
}

/** Cookie session (Supabase Auth JWT) for user-facing /api/v1 routes. */
export async function requireSession(req: Request, limitPerMin = 60): Promise<RequireSessionResult> {
  const rl = rateLimit(`v1sess:${clientIp(req)}`, limitPerMin, 60_000);
  if (!rl.allowed) return { ok: false, response: rateLimitResponse(rl.retryAfterSeconds) };

  const { supabase } = await createRouteHandlerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { ok: false, response: apiErr('Unauthorized — sign in required', 401, { code: 'UNAUTHORIZED' }) };
  }

  return {
    ok: true,
    ctx: { supabase, admin: createAdminClient(), user },
  };
}

/**
 * Run a credit-charged operation: spend first (atomic), refund if the
 * operation throws. On success responds with { ...result, credits }.
 */
export async function withCredits(
  ctx: V1Context,
  cost: number,
  fn: () => Promise<Record<string, unknown>>,
): Promise<Response> {
  let balance: number;
  try {
    balance = await adjustCredits(ctx.admin, ctx.auth.userId, -cost, 'api_call', undefined, {
      key_id: ctx.auth.keyId,
    });
  } catch (err) {
    if (err instanceof InsufficientCreditsError) {
      return apiErr('Insufficient credits. Buy more at tools.farvixo.com/dashboard/credits', 402);
    }
    return apiErr('Credit check failed — try again', 500);
  }

  try {
    const result = await fn();
    return apiOk({ ...result, credits: { spent: cost, remaining: balance } });
  } catch (err) {
    await adjustCredits(ctx.admin, ctx.auth.userId, cost, 'api_call', undefined, {
      key_id: ctx.auth.keyId,
      refund: true,
    }).catch(() => undefined);
    const message = err instanceof Error ? err.message : 'Operation failed';
    return apiErr(message, 502);
  }
}

/** Parse a JSON body; returns null on malformed input. */
export async function readJson<T>(req: Request): Promise<T | null> {
  try {
    return (await req.json()) as T;
  } catch {
    return null;
  }
}
