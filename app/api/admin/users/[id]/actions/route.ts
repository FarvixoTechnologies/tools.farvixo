import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requireAdmin } from '@/lib/admin-auth';
import { createNotification } from '@/lib/notifications';
import { isMissingColumnError, type AdminUserAction } from '@/lib/admin-users';

export const dynamic = 'force-dynamic';

type RouteCtx = { params: Promise<{ id: string }> };

const BAN_DURATION = '876000h'; // ~100 years

export async function POST(req: Request, ctx: RouteCtx) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin, userId: actorId, role: actorRole } = auth.ctx;
  const { id: targetId } = await ctx.params;

  if (targetId === actorId) {
    return apiErr('You cannot perform destructive actions on your own account', 400);
  }

  let body: {
    action?: AdminUserAction;
    reason?: string;
    hours?: number;
    title?: string;
    body?: string;
    href?: string;
  };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }

  const action = body.action;
  if (!action) return apiErr('action is required', 400);

  // Fallback select keeps this working before 06_user_admin.sql has run.
  let profile: { id: string; role: string; email?: string | null; is_banned?: boolean } | null = null;
  {
    const full = await admin.from('profiles').select('id, role, email, is_banned').eq('id', targetId).maybeSingle();
    if (!full.error) {
      profile = full.data;
    } else {
      const legacy = await admin.from('profiles').select('id, role').eq('id', targetId).maybeSingle();
      profile = legacy.data;
    }
  }
  if (!profile) return apiErr('User not found', 404);

  if (profile.role === 'SUPER_ADMIN' && actorRole !== 'SUPER_ADMIN') {
    return apiErr('Only super admins can modify super admin accounts', 403);
  }

  switch (action) {
    case 'ban': {
      const reason = (body.reason ?? '').trim().slice(0, 500) || 'Banned by admin';
      const { error: authErr } = await admin.auth.admin.updateUserById(targetId, { ban_duration: BAN_DURATION });
      if (authErr) return apiErr(authErr.message, 500);

      const { error } = await admin.from('profiles').update({
        is_banned: true,
        banned_at: new Date().toISOString(),
        ban_reason: reason,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error) {
        if (isMissingColumnError(error.message)) {
          return apiErr('Auth ban applied, but profile flags need the 06_user_admin.sql migration — run it in the Supabase SQL editor.', 400);
        }
        return apiErr(error.message, 500);
      }

      await logAdminAction(admin, actorId, 'user.ban', targetId, { reason });
      return apiOk({ banned: true, reason });
    }

    case 'unban': {
      const { error: authErr } = await admin.auth.admin.updateUserById(targetId, { ban_duration: 'none' });
      if (authErr) return apiErr(authErr.message, 500);

      const { error } = await admin.from('profiles').update({
        is_banned: false,
        banned_at: null,
        ban_reason: null,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error) {
        if (isMissingColumnError(error.message)) {
          return apiErr('Auth unban applied, but profile flags need the 06_user_admin.sql migration — run it in the Supabase SQL editor.', 400);
        }
        return apiErr(error.message, 500);
      }

      await logAdminAction(admin, actorId, 'user.unban', targetId);
      return apiOk({ unbanned: true });
    }

    case 'suspend': {
      const reason = (body.reason ?? '').trim().slice(0, 500) || 'Suspended by admin';
      // hours defaults to 24h; clamp 1h..8760h (1 year)
      const hours = Math.min(Math.max(Math.floor(Number(body.hours ?? 24)) || 24, 1), 8760);
      const until = new Date(Date.now() + hours * 3600_000).toISOString();

      // Temporary auth ban so the user actually cannot sign in until it lifts.
      const { error: authErr } = await admin.auth.admin.updateUserById(targetId, { ban_duration: `${hours}h` });
      if (authErr) return apiErr(authErr.message, 500);

      const { error } = await admin.from('profiles').update({
        suspended_until: until,
        suspended_at: new Date().toISOString(),
        suspended_reason: reason,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error) {
        if (isMissingColumnError(error.message)) {
          return apiErr('Auth suspension applied, but profile flags need the latest migration.', 400);
        }
        return apiErr(error.message, 500);
      }

      await logAdminAction(admin, actorId, 'user.suspend', targetId, { reason, hours, until });
      return apiOk({ suspended: true, until, reason });
    }

    case 'unsuspend': {
      const { error: authErr } = await admin.auth.admin.updateUserById(targetId, { ban_duration: 'none' });
      if (authErr) return apiErr(authErr.message, 500);

      const { error } = await admin.from('profiles').update({
        suspended_until: null,
        suspended_at: null,
        suspended_reason: null,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error && !isMissingColumnError(error.message)) return apiErr(error.message, 500);

      await logAdminAction(admin, actorId, 'user.unsuspend', targetId);
      return apiOk({ unsuspended: true });
    }

    case 'soft_delete': {
      // Reversible delete: hide from the app + block sign-in, but keep the row
      // so it can be restored. Permanent removal stays on DELETE /users/[id].
      const reason = (body.reason ?? '').trim().slice(0, 500) || null;
      const { error: authErr } = await admin.auth.admin.updateUserById(targetId, { ban_duration: BAN_DURATION });
      if (authErr) return apiErr(authErr.message, 500);

      const { error } = await admin.from('profiles').update({
        deleted_at: new Date().toISOString(),
        deleted_by: actorId,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error) {
        if (isMissingColumnError(error.message)) {
          return apiErr('Sign-in blocked, but soft-delete needs the latest migration.', 400);
        }
        return apiErr(error.message, 500);
      }

      await logAdminAction(admin, actorId, 'user.soft_delete', targetId, { reason });
      return apiOk({ deleted: true });
    }

    case 'restore': {
      // Clear soft-delete + any suspension and re-enable sign-in.
      const { error: authErr } = await admin.auth.admin.updateUserById(targetId, { ban_duration: 'none' });
      if (authErr) return apiErr(authErr.message, 500);

      const { error } = await admin.from('profiles').update({
        deleted_at: null,
        deleted_by: null,
        suspended_until: null,
        suspended_at: null,
        suspended_reason: null,
        is_banned: false,
        banned_at: null,
        ban_reason: null,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error && !isMissingColumnError(error.message)) return apiErr(error.message, 500);

      await logAdminAction(admin, actorId, 'user.restore', targetId);
      return apiOk({ restored: true });
    }

    case 'reset_quota': {
      const { error } = await admin.from('profiles').update({
        tools_used_today: 0,
        updated_at: new Date().toISOString(),
      }).eq('id', targetId);
      if (error) return apiErr(error.message, 500);

      await logAdminAction(admin, actorId, 'user.reset_quota', targetId);
      return apiOk({ reset: true });
    }

    case 'notify': {
      const title = (body.title ?? '').trim().slice(0, 120);
      const notifyBody = (body.body ?? '').trim().slice(0, 1000);
      const href = (body.href ?? '').trim().slice(0, 500) || null;
      if (!title) return apiErr('Notification title is required', 400);

      const ok = await createNotification(admin, targetId, {
        type: 'system',
        title,
        body: notifyBody,
        href,
      });
      if (!ok) return apiErr('Failed to send notification', 500);

      await logAdminAction(admin, actorId, 'user.notify', targetId, { title });
      return apiOk({ sent: true });
    }

    case 'password_reset': {
      let userEmail = profile.email;
      if (!userEmail) {
        const { data: authUser } = await admin.auth.admin.getUserById(targetId);
        userEmail = authUser?.user?.email ?? null;
      }
      if (!userEmail) return apiErr('User has no email', 400);

      const { data, error } = await admin.auth.admin.generateLink({
        type: 'recovery',
        email: userEmail,
      });
      if (error || !data?.properties?.action_link) {
        return apiErr(error?.message ?? 'Failed to generate reset link', 500);
      }

      await logAdminAction(admin, actorId, 'user.password_reset', targetId);
      return apiOk({ reset_link: data.properties.action_link });
    }

    default:
      return apiErr('Unknown action', 400);
  }
}
