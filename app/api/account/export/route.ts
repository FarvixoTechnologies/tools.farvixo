import { apiErr } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

/**
 * GET /api/account/export — GDPR self-service data export.
 * Returns a downloadable JSON bundle of the signed-in user's own data.
 * Accepts cookie session or Authorization Bearer (Flutter).
 */
export async function GET(req: Request) {
  const rl = rateLimit(`account-export:${clientIp(req)}`, 5, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  if (!getSupabaseEnv()) return apiErr('Auth not configured', 503);

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  async function one<T>(promise: PromiseLike<{ data: T; error: { message: string } | null }>): Promise<T | null> {
    const { data, error } = await promise;
    if (error) {
      console.warn('[account/export] skip table:', error.message);
      return null;
    }
    return data;
  }

  const [
    profile,
    settings,
    socials,
    prefs,
    notifPrefs,
    jobs,
    history,
    favorites,
    userSettings,
    userFavorites,
    userDevices,
    userToolStats,
  ] = await Promise.all([
    one(supabase.from('profiles').select('*').eq('id', user.id).maybeSingle()),
    one(supabase.from('settings').select('*').eq('user_id', user.id).maybeSingle()),
    one(supabase.from('user_socials').select('*').eq('user_id', user.id).maybeSingle()),
    one(supabase.from('user_preferences').select('*').eq('user_id', user.id).maybeSingle()),
    one(supabase.from('notification_preferences').select('*').eq('user_id', user.id).maybeSingle()),
    one(
      supabase
        .from('jobs')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(500),
    ),
    one(
      supabase
        .from('login_history')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(200),
    ),
    one(supabase.from('favorites').select('*').eq('user_id', user.id).limit(500)),
    one(supabase.from('user_settings').select('*').eq('user_id', user.id).maybeSingle()),
    one(supabase.from('user_favorites').select('*').eq('user_id', user.id).limit(500)),
    one(supabase.from('user_devices').select('*').eq('user_id', user.id).limit(100)),
    one(supabase.from('user_tool_stats').select('*').eq('user_id', user.id).limit(500)),
  ]);

  const bundle = {
    export_meta: {
      generated_at: new Date().toISOString(),
      user_id: user.id,
      email: user.email,
      format: 'farvixo-data-export-v1',
    },
    account: {
      id: user.id,
      email: user.email,
      created_at: user.created_at,
      last_sign_in_at: user.last_sign_in_at,
      providers: user.app_metadata?.providers ?? [],
    },
    profile,
    settings,
    socials,
    preferences: prefs,
    notification_preferences: notifPrefs,
    jobs: jobs ?? [],
    login_history: history ?? [],
    favorites: favorites ?? [],
    user_settings: userSettings,
    user_favorites: userFavorites ?? [],
    user_devices: userDevices ?? [],
    user_tool_stats: userToolStats ?? [],
  };

  const filename = `farvixo-data-${new Date().toISOString().slice(0, 10)}.json`;
  return new Response(JSON.stringify(bundle, null, 2), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Cache-Control': 'no-store',
    },
  });
}
