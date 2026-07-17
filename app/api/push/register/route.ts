import { apiErr, apiOk } from '@/lib/api-response';
import { createAdminClient } from '@/lib/supabase/admin';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

/** Store FCM web push token for the signed-in Supabase user. */
export async function POST(req: Request) {
  const rl = rateLimit(`push:${clientIp(req)}`, 20, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  let body: { token?: string; platform?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid request body', 400);
  }

  const token = body.token?.trim();
  if (!token || token.length < 20 || token.length > 4096) {
    return apiErr('Valid FCM token required', 400);
  }

  const { supabase } = await createRouteHandlerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return apiErr('Unauthorized', 401);

  const admin = createAdminClient();
  if (!admin) return apiErr('Backend not configured', 503);

  const platform = (body.platform || 'web').slice(0, 32);

  const { error } = await admin.from('push_tokens').upsert(
    {
      user_id: user.id,
      token,
      platform,
    },
    { onConflict: 'user_id,token' },
  );

  if (error) {
    // Fallback: devices table (older schema)
    const { error: dErr } = await admin.from('devices').upsert(
      {
        user_id: user.id,
        device_id: `web:${token.slice(0, 32)}`,
        platform,
        push_token: token,
        last_seen_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,device_id' },
    );
    if (dErr) {
      console.error('[push/register]', error.message, dErr.message);
      return apiErr('Could not save push token', 500);
    }
  }

  return apiOk({ saved: true });
}
