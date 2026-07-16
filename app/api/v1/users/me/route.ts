import { apiErr, apiOk } from '@/lib/api-response';
import { parsePagination, readJson, requireSession } from '@/lib/api-v1';
import { profileToUser, type ProfileRow } from '@/lib/auth';

export const dynamic = 'force-dynamic';

const PROFILE_FIELDS =
  'id, full_name, avatar_url, plan, role, tools_used_today, is_banned, storage_used_mb, credits';

/**
 * GET /api/v1/users/me — signed-in profile (session cookie JWT).
 * PATCH /api/v1/users/me — update full_name / avatar_url.
 */
export async function GET(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const { data: row } = await supabase.from('profiles').select(PROFILE_FIELDS).eq('id', user.id).maybeSingle();

  if ((row as { is_banned?: boolean } | null)?.is_banned) {
    return apiErr('Account suspended', 403, { code: 'FORBIDDEN' });
  }

  if (!row) {
    return apiOk({
      user: profileToUser(
        {
          id: user.id,
          full_name: (user.user_metadata?.full_name as string) ?? null,
          avatar_url: (user.user_metadata?.avatar_url as string) ?? null,
          plan: 'FREE',
          role: 'USER',
          tools_used_today: 0,
        },
        user.email ?? '',
      ),
    });
  }

  const storage = (row as { storage_used_mb?: number }).storage_used_mb ?? 0;
  return apiOk({
    user: profileToUser(row as ProfileRow, user.email ?? '', storage),
    credits: (row as { credits?: number }).credits ?? 0,
  });
}

export async function PATCH(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const body = await readJson<{ full_name?: string; avatar_url?: string | null }>(req);
  if (!body) return apiErr('Invalid JSON body', 400, { code: 'BAD_REQUEST' });

  const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
  if (typeof body.full_name === 'string') {
    const name = body.full_name.trim().slice(0, 120);
    if (name.length < 1) return apiErr('full_name required', 422, { code: 'VALIDATION_ERROR' });
    patch.full_name = name;
  }
  if (body.avatar_url !== undefined) {
    patch.avatar_url = body.avatar_url;
  }
  if (Object.keys(patch).length <= 1) {
    return apiErr('No valid fields to update', 422, { code: 'VALIDATION_ERROR' });
  }

  const { data, error } = await supabase
    .from('profiles')
    .update(patch)
    .eq('id', user.id)
    .select(PROFILE_FIELDS)
    .maybeSingle();

  if (error) return apiErr(error.message, 500);
  return apiOk(
    { user: data ? profileToUser(data as ProfileRow, user.email ?? '') : null },
    200,
    { message: 'Profile updated' },
  );
}

/** DELETE — hard delete remains at POST /api/account/delete */
export async function DELETE(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  return apiErr(
    'Use POST /api/account/delete or Dashboard → Settings to permanently delete your account',
    501,
    { code: 'NOT_IMPLEMENTED' },
  );
}
