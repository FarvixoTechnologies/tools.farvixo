import { apiErr, apiOk } from '@/lib/api-response';
import { parsePagination, readJson, requireSession } from '@/lib/api-v1';
import { ensureWelcomeNotification } from '@/lib/notifications';

export const dynamic = 'force-dynamic';

/** GET /api/v1/notifications — paginated inbox. */
export async function GET(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;
  const { page, pageSize, from, to } = parsePagination(req, { pageSize: 20, max: 50 });

  await ensureWelcomeNotification(supabase, user.id);

  const { data, error, count } = await supabase
    .from('notifications')
    .select('id, type, title, body, href, read, created_at', { count: 'exact' })
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .range(from, to);

  if (error) return apiErr(error.message, 500);

  const { count: unread } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('read', false);

  return apiOk(
    {
      notifications: data ?? [],
      unreadCount: unread ?? 0,
      total: count ?? 0,
    },
    200,
    { meta: { page, pageSize, total: count ?? 0 } },
  );
}

/** PATCH /api/v1/notifications — mark read: { ids?: string[], all?: true } */
export async function PATCH(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const body = await readJson<{ ids?: string[]; all?: boolean }>(req);
  if (!body) return apiErr('Invalid JSON body', 400);

  let query = supabase.from('notifications').update({ read: true }).eq('user_id', user.id);
  if (body.all) {
    query = query.eq('read', false);
  } else if (body.ids?.length) {
    query = query.in('id', body.ids.slice(0, 100));
  } else {
    return apiErr('Provide ids[] or all: true', 422, { code: 'VALIDATION_ERROR' });
  }

  const { error } = await query;
  if (error) return apiErr(error.message, 500);
  return apiOk({ updated: true }, 200, { message: 'Notifications marked read' });
}

/** DELETE /api/v1/notifications — { ids: string[] } */
export async function DELETE(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const body = await readJson<{ ids?: string[]; all?: boolean }>(req);
  if (!body) return apiErr('Invalid JSON body', 400);

  let query = supabase.from('notifications').delete().eq('user_id', user.id);
  if (body.all) {
    // delete all for user
  } else if (body.ids?.length) {
    query = query.in('id', body.ids.slice(0, 100));
  } else {
    return apiErr('Provide ids[] or all: true', 422, { code: 'VALIDATION_ERROR' });
  }

  const { error } = await query;
  if (error) return apiErr(error.message, 500);
  return apiOk({ deleted: true }, 200, { message: 'Notifications deleted' });
}
