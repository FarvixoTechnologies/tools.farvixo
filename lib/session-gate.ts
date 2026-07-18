import type { SupabaseClient } from '@supabase/supabase-js';
import { createAdminClient } from '@/lib/supabase/admin';

/**
 * Immediate session enforcement used by middleware.
 *
 * One lightweight RPC (`session_gate`) returns a single reason string for the
 * caller's own account + device. Positive ("allowed") results are cached in the
 * edge isolate for a short TTL to avoid a DB hit on every protected request;
 * denials are never cached, so a revoked/blocked user is re-evaluated each time
 * and a restore/relogin takes effect immediately.
 */

export const GATE_TTL_MS = 30_000; // 30s allow-cache — bounds enforcement lag

export type GateReason = '' | 'revoked' | 'banned' | 'suspended' | 'deleted' | 'invalid';

type CacheEntry = { exp: number };
// Module scope persists across requests within a warm edge isolate.
const allowCache = new Map<string, CacheEntry>();

function sweep(now: number): void {
  if (allowCache.size < 5000) return;
  for (const [k, v] of allowCache) if (v.exp <= now) allowCache.delete(k);
}

/** Returns '' when the session is allowed, or a deny reason. */
export async function checkSessionGate(
  supabase: SupabaseClient,
  userId: string,
  deviceId: string,
): Promise<GateReason> {
  const key = `${userId}:${deviceId}`;
  const now = Date.now();

  const cached = allowCache.get(key);
  if (cached && cached.exp > now) return '';

  const { data, error } = await supabase.rpc('session_gate', { p_device_id: deviceId });

  // Fail-open on transient RPC/network errors so a Supabase blip can't lock
  // everyone out; the JWT was already validated by getUser() upstream.
  if (error) return '';

  const reason = (typeof data === 'string' ? data : '') as GateReason;

  if (reason === '') {
    sweep(now);
    allowCache.set(key, { exp: now + GATE_TTL_MS });
  }
  return reason;
}

/** Human-readable reason for the login screen. */
export function gateMessage(reason: GateReason): string {
  switch (reason) {
    case 'revoked': return 'Your session was ended by an administrator.';
    case 'banned': return 'Your account has been banned.';
    case 'suspended': return 'Your account is temporarily suspended.';
    case 'deleted': return 'This account is no longer available.';
    default: return 'Please sign in again.';
  }
}

/** Fire-and-forget audit of a middleware denial (service role; edge-safe). */
export function auditDenial(userId: string, reason: GateReason, path: string): void {
  try {
    const admin = createAdminClient();
    if (!admin) return;
    void admin
      .from('admin_audit_log')
      .insert({ actor_id: userId, action: 'session.denied', target: userId, meta: { reason, path } })
      .then(() => {}, () => {});
  } catch {
    /* never block the request on audit */
  }
}
