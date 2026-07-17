import { apiErr } from '@/lib/api-response';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

/**
 * GET /api/account/export — GDPR self-service data export.
 * Returns a downloadable JSON bundle of the signed-in user's own data.
 */
export async function GET(req: Request) {
  const rl = rateLimit(`account-export:${clientIp(req)}`, 5, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  if (!getSupabaseEnv()) return apiErr('Auth not configured', 503);

  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiErr('Unauthorized', 401);

  const [profile, settings, socials, prefs, notifPrefs, jobs, history, favorites] = await Promise.all([
    supabase.from('profiles').select('*').eq('id', user.id).maybeSingle(),
    supabase.from('settings').select('*').eq('user_id', user.id).maybeSingle(),
    supabase.from('user_socials').select('*').eq('user_id', user.id).maybeSingle(),
    supabase.from('user_preferences').select('*').eq('user_id', user.id).maybeSingle(),
    supabase.from('notification_preferences').select('*').eq('user_id', user.id).maybeSingle(),
    supabase.from('jobs').select('*').eq('user_id', user.id).order('created_at', { ascending: false }).limit(500),
    supabase.from('login_history').select('*').eq('user_id', user.id).order('created_at', { ascending: false }).limit(200),
    supabase.from('favorites').select('*').eq('user_id', user.id).limit(500),
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
    profile: profile.data ?? null,
    settings: settings.data ?? null,
    socials: socials.data ?? null,
    preferences: prefs.data ?? null,
    notification_preferences: notifPrefs.data ?? null,
    jobs: jobs.data ?? [],
    login_history: history.data ?? [],
    favorites: favorites.data ?? [],
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
