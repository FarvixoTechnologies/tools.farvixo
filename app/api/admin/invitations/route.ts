import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requireAdmin, requireSuperAdmin } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function GET(req: Request) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const url = new URL(req.url);
  const status = url.searchParams.get('status') ?? '';
  const q = (url.searchParams.get('q') ?? '').trim().toLowerCase();
  const page = Math.max(1, Number(url.searchParams.get('page') || 1));
  const limit = 20;
  const from = (page - 1) * limit;

  let query = admin
    .from('admin_invitations')
    .select('id, email, role_key, status, invited_by, expires_at, created_at, accepted_at', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + limit - 1);
  if (status) query = query.eq('status', status);
  if (q) query = query.ilike('email', `%${q}%`);

  const { data, error, count } = await query;
  if (error) return apiErr(error.message, 500);

  // Mark expired on read (cheap, no cron needed).
  const now = Date.now();
  const rows = (data ?? []).map((r) => ({
    ...r,
    status: r.status === 'pending' && new Date(r.expires_at).getTime() < now ? 'expired' : r.status,
  }));

  return apiOk({ invitations: rows, total: count ?? 0, page, pages: Math.ceil((count ?? 0) / limit) });
}

export async function POST(req: Request) {
  const auth = await requireSuperAdmin();
  if (!auth.ok) return auth.response;
  const { admin, userId, role: actorRole } = auth.ctx;

  let body: { email?: string; role_key?: string };
  try { body = (await req.json()) as typeof body; } catch { return apiErr('Invalid body', 400); }

  const email = (body.email ?? '').trim().toLowerCase();
  const roleKey = (body.role_key ?? 'ADMIN').trim().toUpperCase();
  if (!EMAIL_RE.test(email)) return apiErr('Valid email required', 400);
  if (roleKey === 'SUPER_ADMIN' && actorRole !== 'SUPER_ADMIN') {
    return apiErr('Only super admins can invite super admins', 403);
  }

  const { data: role } = await admin.from('roles').select('key').eq('key', roleKey).maybeSingle();
  if (!role) return apiErr('Role does not exist', 400);

  const token = crypto.randomUUID();
  const redirectTo = `${process.env.NEXT_PUBLIC_APP_URL || 'https://tools.farvixo.com'}/admin`;

  // Send a real Supabase invite; fall back to a generated link if SMTP is off.
  let inviteLink: string | null = null;
  const invited = await admin.auth.admin.inviteUserByEmail(email, { redirectTo });
  let authUserId = invited.data?.user?.id ?? null;
  if (invited.error) {
    const gen = await admin.auth.admin.generateLink({ type: 'invite', email, options: { redirectTo } });
    if (gen.error || !gen.data?.properties?.action_link) {
      return apiErr(invited.error.message, 500);
    }
    inviteLink = gen.data.properties.action_link;
    authUserId = gen.data.user?.id ?? null;
  }

  // Assign the target role now so the account carries it on first sign-in.
  if (authUserId) {
    await admin.from('profiles').upsert({
      id: authUserId,
      role: roleKey,
      plan: 'ENTERPRISE',
      updated_at: new Date().toISOString(),
    });
  }

  const { data: inv, error } = await admin
    .from('admin_invitations')
    .insert({ email, role_key: roleKey, token, invited_by: userId, status: 'pending' })
    .select('id, email, role_key, status, expires_at, created_at')
    .single();
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'admin.invite', email, { role: roleKey });
  return apiOk({ invitation: inv, invite_link: inviteLink });
}

export async function PATCH(req: Request) {
  const auth = await requireSuperAdmin();
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { id?: string; action?: 'revoke' };
  try { body = (await req.json()) as typeof body; } catch { return apiErr('Invalid body', 400); }
  if (!body.id) return apiErr('id required', 400);

  const { data: inv } = await admin
    .from('admin_invitations')
    .select('id, email, role_key, status')
    .eq('id', body.id)
    .maybeSingle();
  if (!inv) return apiErr('Invitation not found', 404);

  const { error } = await admin
    .from('admin_invitations')
    .update({ status: 'revoked' })
    .eq('id', body.id);
  if (error) return apiErr(error.message, 500);

  // Demote the invited account if it hasn't been used for anything else yet.
  const { data: authUser } = await admin.auth.admin.listUsers();
  const match = authUser?.users.find((u) => (u.email ?? '').toLowerCase() === inv.email.toLowerCase());
  if (match && !match.last_sign_in_at) {
    await admin.from('profiles').update({ role: 'USER' }).eq('id', match.id);
  }

  await logAdminAction(admin, userId, 'admin.invite_revoke', inv.email);
  return apiOk({ revoked: true });
}
