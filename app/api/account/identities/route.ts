import { apiErr, apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

const LINKABLE = new Set(['google', 'github', 'apple']);

/**
 * GET /api/account/identities — list linked OAuth providers for the signed-in user.
 * Accepts cookie session or Authorization Bearer (Flutter).
 */
export async function GET(req: Request) {
  const rl = rateLimit(`account-identities:${clientIp(req)}`, 30, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  if (!getSupabaseEnv()) return apiErr('Auth is not configured', 503);

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { user } = gate.ctx;

  const identities = (user.identities ?? []).map((id) => {
    const row = id as {
      identity_id?: string;
      id?: string;
      provider: string;
      identity_data?: { email?: string };
      created_at?: string;
      last_sign_in_at?: string;
    };
    return {
      id: row.identity_id ?? row.id ?? row.provider,
      provider: row.provider,
      email: row.identity_data?.email ?? null,
      createdAt: row.created_at ?? null,
      lastSignInAt: row.last_sign_in_at ?? null,
      linkable: LINKABLE.has(row.provider),
    };
  });

  return apiOk({
    identities,
    linkableProviders: [...LINKABLE],
    email: user.email ?? null,
  });
}
