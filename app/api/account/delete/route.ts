import { createHash } from 'crypto';
import { apiErr, apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';
import { createAdminClient } from '@/lib/supabase/admin';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

/**
 * POST /api/account/delete — permanently delete the signed-in user's account.
 * Records into deleted_accounts, then admin-deletes the auth user (CASCADE).
 * Accepts cookie session or Authorization Bearer (Flutter).
 */
export async function POST(req: Request) {
  const rl = rateLimit(`account-delete:${clientIp(req)}`, 3, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  if (!getSupabaseEnv()) return apiErr('Auth is not configured', 503);

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { user } = gate.ctx;

  const admin = createAdminClient();
  if (!admin) {
    return apiErr('Account deletion is not available — contact support@farvixo.com', 503);
  }

  const now = new Date().toISOString();
  const emailHash = user.email
    ? createHash('sha256').update(user.email.toLowerCase()).digest('hex')
    : null;
  const { error: logErr } = await admin.from('deleted_accounts').insert({
    former_user_id: user.id,
    email_hash: emailHash,
    reason: 'user_requested',
    snapshot: { source: 'api/account/delete' },
    deleted_at: now,
  });
  if (logErr) {
    // Table may not exist in older envs — log and continue with delete.
    console.warn('[account] deleted_accounts insert:', logErr.message);
  }

  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error('[account] delete failed:', error.message);
    return apiErr('Could not delete account — contact support@farvixo.com', 500);
  }

  return apiOk({ deleted: true });
}
