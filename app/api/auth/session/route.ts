import { apiErr, apiOk } from '@/lib/api-response';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

/**
 * Session/device capture. Called by the client on auth state changes.
 * Writes with the service role after verifying the user via cookies, so IP and
 * User-Agent come from trusted request headers (not client-supplied).
 */
export async function POST(req: Request) {
  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiErr('Unauthorized', 401);

  const admin = createAdminClient();
  if (!admin) return apiErr('Server not configured', 503);

  let body: { device_id?: string; platform?: string; app_version?: string; event?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    body = {};
  }

  const deviceId = (body.device_id ?? '').toString().slice(0, 128) || 'web';
  const platform = (body.platform ?? '').toString().slice(0, 64) || null;
  const appVersion = (body.app_version ?? '').toString().slice(0, 32) || null;
  const isSignIn = body.event === 'SIGNED_IN';

  const h = req.headers;
  const ip =
    h.get('cf-connecting-ip') ||
    h.get('x-forwarded-for')?.split(',')[0].trim() ||
    h.get('x-real-ip') ||
    null;
  const userAgent = h.get('user-agent')?.slice(0, 400) ?? null;
  const provider = (user.app_metadata?.provider as string | undefined) ?? 'email';
  const now = new Date().toISOString();

  // Device history (one row per user+device).
  await admin.from('devices').upsert(
    {
      user_id: user.id,
      device_id: deviceId,
      platform,
      app_version: appVersion,
      user_agent: userAgent,
      last_seen_at: now,
    },
    { onConflict: 'user_id,device_id' },
  );

  if (isSignIn) {
    // Fresh sign-in (re)activates the session for this device.
    await admin.from('user_sessions').upsert(
      {
        user_id: user.id,
        device_id: deviceId,
        provider,
        ip,
        user_agent: userAgent,
        last_active_at: now,
        revoked_at: null,
        revoked_by: null,
      },
      { onConflict: 'user_id,device_id' },
    );

    await admin.from('login_history').insert({
      user_id: user.id,
      provider,
      success: true,
      ip,
      user_agent: userAgent,
    });

    return apiOk({ tracked: true, revoked: false });
  }

  // Token refresh: enforce revocation. If an admin revoked this session, tell the
  // client to sign out (this fires within the token lifetime, ~1h). Never
  // un-revoke here — only an explicit sign-in reactivates a session.
  const { data: existing } = await admin
    .from('user_sessions')
    .select('id, revoked_at')
    .eq('user_id', user.id)
    .eq('device_id', deviceId)
    .maybeSingle();

  if (existing?.revoked_at) {
    return apiOk({ tracked: true, revoked: true });
  }

  await admin.from('user_sessions').upsert(
    {
      user_id: user.id,
      device_id: deviceId,
      provider,
      ip,
      user_agent: userAgent,
      last_active_at: now,
    },
    { onConflict: 'user_id,device_id' },
  );

  return apiOk({ tracked: true, revoked: false });
}
