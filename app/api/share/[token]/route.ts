import { type NextRequest, NextResponse } from 'next/server';
import { apiErr, apiOk } from '@/lib/api-response';
import { createAdminClient } from '@/lib/supabase/admin';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';
import { deviceHint, eventFingerprint, getCallerPlan, verifySharePassword } from '@/lib/share';

export const dynamic = 'force-dynamic';

type ShareRow = {
  id: string;
  user_id: string | null;
  file_name: string;
  mime_type: string;
  storage_path: string;
  expires_at: string;
  max_downloads: number | null;
  downloads: number;
  password_hash: string | null;
  share_events: unknown;
};

async function appendShareEvent(
  admin: NonNullable<ReturnType<typeof createAdminClient>>,
  shareId: string,
  events: unknown,
  type: string,
  req: Request,
) {
  const list = Array.isArray(events) ? [...events] : [];
  list.push({
    type,
    at: new Date().toISOString(),
    device: deviceHint(req),
    fp: eventFingerprint(req),
  });
  await admin.from('shares').update({ share_events: list }).eq('id', shareId);
}

/** GET /api/share/[token] — metadata (JSON) or download (redirect). */
export async function GET(req: NextRequest, { params }: { params: Promise<{ token: string }> }) {
  const rl = rateLimit(`share-dl:${clientIp(req)}`, 30, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const { token } = await params;
  if (!/^[\w-]{10,40}$/.test(token)) return apiErr('Invalid share link', 400);

  const admin = createAdminClient();
  if (!admin) return apiErr('Sharing is not configured on this server', 503);

  const { data: share } = await admin
    .from('shares')
    .select('id, user_id, file_name, mime_type, storage_path, expires_at, max_downloads, downloads, password_hash, share_events')
    .eq('token', token)
    .maybeSingle<ShareRow>();

  if (!share) return apiErr('This share link does not exist or was removed', 404);
  if (new Date(share.expires_at).getTime() < Date.now()) {
    return apiErr('This share link has expired', 410);
  }
  if (share.max_downloads !== null && share.downloads >= share.max_downloads) {
    return apiErr('This share link has reached its download limit', 410);
  }

  const metaOnly = req.nextUrl.searchParams.get('meta') === '1';
  if (metaOnly) {
    return apiOk({
      fileName: share.file_name,
      mimeType: share.mime_type,
      expiresAt: share.expires_at,
      requiresPassword: !!share.password_hash,
      downloads: share.downloads,
      maxDownloads: share.max_downloads,
    });
  }

  if (share.password_hash) {
    const pwd = req.nextUrl.searchParams.get('password') ?? req.headers.get('x-share-password');
    if (!pwd || !verifySharePassword(pwd, share.password_hash)) {
      return apiErr('Password required or incorrect', 401);
    }
  }

  const { data: signed, error: signError } = await admin.storage
    .from('shares')
    .createSignedUrl(share.storage_path, 60, { download: share.file_name });
  if (signError || !signed?.signedUrl) {
    console.error('[share] sign failed:', signError?.message);
    return apiErr('Could not prepare the download', 500);
  }

  await admin.from('shares').update({ downloads: share.downloads + 1 }).eq('id', share.id);
  await appendShareEvent(admin, share.id, share.share_events, 'share_downloaded', req);

  return NextResponse.redirect(signed.signedUrl, 302);
}

/** DELETE /api/share/[token] — revoke a share link (owner). */
export async function DELETE(req: NextRequest, { params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  if (!/^[\w-]{10,40}$/.test(token)) return apiErr('Invalid share link', 400);

  const { userId } = await getCallerPlan();
  if (!userId) return apiErr('Sign in to revoke share links', 401);

  const admin = createAdminClient();
  if (!admin) return apiErr('Sharing is not configured', 503);

  const { data: share } = await admin
    .from('shares')
    .select('id, user_id, storage_path')
    .eq('token', token)
    .maybeSingle();

  if (!share) return apiErr('Share link not found', 404);
  if (share.user_id !== userId) return apiErr('Not authorized to revoke this link', 403);

  await admin.storage.from('shares').remove([share.storage_path]);
  await admin.from('shares').delete().eq('id', share.id);

  return apiOk({ revoked: true });
}
