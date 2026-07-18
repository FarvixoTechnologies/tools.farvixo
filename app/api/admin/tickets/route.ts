import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  const auth = await requirePermission('support.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const status = url.searchParams.get('status') ?? '';
  const page = Math.max(1, Number(url.searchParams.get('page') || 1));
  const limit = 25;
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  let query = admin
    .from('tickets')
    .select('id, user_id, subject, status, priority, created_at, updated_at', { count: 'exact' })
    .order('updated_at', { ascending: false })
    .range(from, to);

  if (status) query = query.eq('status', status);

  const { data, error, count } = await query;
  if (error) {
    return apiOk({
      ready: false,
      tickets: [],
      total: 0,
      page,
      pages: 0,
      error: error.message,
    });
  }

  return apiOk({
    ready: true,
    tickets: data ?? [],
    total: count ?? 0,
    page,
    pages: Math.ceil((count ?? 0) / limit),
  });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('support.write');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { id?: string; status?: string; priority?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }
  if (!body.id) return apiErr('Ticket id required', 400);

  const updates: Record<string, string> = { updated_at: new Date().toISOString() };
  if (body.status && ['open', 'pending', 'closed', 'resolved'].includes(body.status)) {
    updates.status = body.status;
  }
  if (body.priority && ['low', 'normal', 'high', 'urgent'].includes(body.priority)) {
    updates.priority = body.priority;
  }

  const { error } = await admin.from('tickets').update(updates).eq('id', body.id);
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'ticket.update', body.id, updates);
  return apiOk({ updated: true });
}
