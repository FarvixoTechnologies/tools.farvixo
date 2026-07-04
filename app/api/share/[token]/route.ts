import { type NextRequest, NextResponse } from 'next/server';
import { apiErr } from '@/lib/api-response';
import { createAdminClient } from '@/lib/supabase/admin';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

/** GET /api/share/[token] — validate a share token and stream the file. */
export async function GET(req: NextRequest, { params }: { params: Promise<{ token: string }> }) {
  const rl = rateLimit(`share-dl:${clientIp(req)}`, 30, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const { token } = await params;
  if (!/^[\w-]{10,40}$/.test(token)) return apiErr('Invalid share link', 400);

  const admin = createAdminClient();
  if (!admin) return apiErr('Sharing is not configured on this server', 503);

  const { data: share } = await admin
    .from('shares')
    .select('id, file_name, mime_type, storage_path, expires_at, max_downloads, downloads')
    .eq('token', token)
    .maybeSingle();

  if (!share) return apiErr('This share link does not exist or was removed', 404);
  if (new Date(share.expires_at).getTime() < Date.now()) {
    return apiErr('This share link has expired', 410);
  }
  if (share.max_downloads !== null && share.downloads >= share.max_downloads) {
    return apiErr('This share link has reached its download limit', 410);
  }

  const { data: signed, error: signError } = await admin.storage
    .from('shares')
    .createSignedUrl(share.storage_path, 60, { download: share.file_name });
  if (signError || !signed?.signedUrl) {
    console.error('[share] sign failed:', signError?.message);
    return apiErr('Could not prepare the download', 500);
  }

  // Analytics: count the download (best-effort).
  await admin
    .from('shares')
    .update({ downloads: share.downloads + 1 })
    .eq('id', share.id);

  return NextResponse.redirect(signed.signedUrl, 302);
}
