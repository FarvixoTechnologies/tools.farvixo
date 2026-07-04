import { apiErr, apiOk } from '@/lib/api-response';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

export interface NotificationRow {
  id: string;
  type: string;
  title: string;
  body: string | null;
  href: string | null;
  read: boolean;
  created_at: string;
}

/** GET /api/notifications — latest 20 for the signed-in user + unread count. */
export async function GET() {
  if (!getSupabaseEnv()) return apiOk({ notifications: [], unreadCount: 0 });

  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiErr('Sign in to view notifications', 401);

  const { data: fetched, error } = await supabase
    .from('notifications')
    .select('id, type, title, body, href, read, created_at')
    .order('created_at', { ascending: false })
    .limit(20);

  if (error) {
    console.error('[notifications] fetch failed:', error.message);
    return apiErr('Could not load notifications', 500);
  }

  // First visit: seed a welcome notification so the inbox is never empty.
  let notifications = fetched;
  if (!notifications || notifications.length === 0) {
    const { data: seeded } = await supabase
      .from('notifications')
      .insert({
        user_id: user.id,
        type: 'system',
        title: 'Welcome to ToolNest 🎉',
        body: 'Explore 120+ tools — PDF, Image, AI and more. Your files and history live in your dashboard.',
        href: '/tools',
      })
      .select('id, type, title, body, href, read, created_at');
    notifications = seeded ?? [];
  }

  const { count } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('read', false);

  return apiOk({ notifications, unreadCount: count ?? 0 });
}

/** PATCH /api/notifications — mark read. Body: { ids?: string[]; all?: true } */
export async function PATCH(req: Request) {
  if (!getSupabaseEnv()) return apiOk({ updated: 0 });

  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiErr('Sign in first', 401);

  let body: { ids?: string[]; all?: boolean };
  try {
    body = (await req.json()) as { ids?: string[]; all?: boolean };
  } catch {
    return apiErr('Invalid request body', 400);
  }

  let query = supabase.from('notifications').update({ read: true }).eq('user_id', user.id);
  if (!body.all) {
    const ids = (body.ids ?? []).filter((x) => typeof x === 'string').slice(0, 50);
    if (ids.length === 0) return apiErr('Nothing to mark read', 400);
    query = query.in('id', ids);
  }

  const { error } = await query;
  if (error) {
    console.error('[notifications] update failed:', error.message);
    return apiErr('Could not update notifications', 500);
  }
  return apiOk({ ok: true });
}

/** POST /api/notifications — create a notification for the signed-in user (used by client-side tool flows). */
export async function POST(req: Request) {
  const rl = rateLimit(`notif:${clientIp(req)}`, 20, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  if (!getSupabaseEnv()) return apiOk({ created: false });

  const { supabase } = await createRouteHandlerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return apiOk({ created: false });

  let body: { type?: string; title?: string; body?: string; href?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid request body', 400);
  }

  const title = (body.title ?? '').trim().slice(0, 120);
  if (!title) return apiErr('Title is required', 400);
  const type = ['system', 'job', 'billing', 'announcement'].includes(body.type ?? '') ? body.type : 'system';
  const href = body.href && body.href.startsWith('/') ? body.href.slice(0, 200) : null;

  const { error } = await supabase.from('notifications').insert({
    user_id: user.id,
    type,
    title,
    body: (body.body ?? '').trim().slice(0, 500) || null,
    href,
  });

  if (error) {
    console.error('[notifications] insert failed:', error.message);
    return apiErr('Could not create notification', 500);
  }
  return apiOk({ created: true });
}
