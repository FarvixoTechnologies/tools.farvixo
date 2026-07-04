import { randomBytes } from 'crypto';
import { apiErr, apiOk } from '@/lib/api-response';
import { createAdminClient } from '@/lib/supabase/admin';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

const MAX_SHARE_BYTES = 25 * 1024 * 1024; // 25MB
const EXPIRY_HOURS = new Set([1, 24, 168, 720]); // 1h, 24h, 7d, 30d

/** POST /api/share — upload a processed file and get a secure share link. */
export async function POST(req: Request) {
  const rl = rateLimit(`share:${clientIp(req)}`, 10, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const admin = createAdminClient();
  if (!admin) return apiErr('Sharing is not configured on this server', 503);

  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return apiErr('Expected multipart form data', 400);
  }

  const file = form.get('file');
  if (!(file instanceof File)) return apiErr('file is required', 400);
  if (file.size === 0) return apiErr('File is empty', 400);
  if (file.size > MAX_SHARE_BYTES) return apiErr('File too large — share links support up to 25MB', 413);

  const hours = Number(form.get('expiresInHours') ?? 24);
  const expiresInHours = EXPIRY_HOURS.has(hours) ? hours : 24;
  const oneTime = form.get('oneTime') === 'true';

  let userId: string | null = null;
  if (getSupabaseEnv()) {
    try {
      const { supabase } = await createRouteHandlerClient();
      const { data: { user } } = await supabase.auth.getUser();
      userId = user?.id ?? null;
    } catch { /* anonymous shares allowed */ }
  }

  const token = randomBytes(16).toString('base64url');
  const safeName = file.name.replace(/[^\w.\-()\s]/g, '_').slice(0, 120) || 'file';
  const storagePath = `${token}/${safeName}`;

  const { error: uploadError } = await admin.storage
    .from('shares')
    .upload(storagePath, file, { contentType: file.type || 'application/octet-stream' });
  if (uploadError) {
    console.error('[share] upload failed:', uploadError.message);
    return apiErr('Could not store the file for sharing', 500);
  }

  const expiresAt = new Date(Date.now() + expiresInHours * 3600_000).toISOString();
  const { error: insertError } = await admin.from('shares').insert({
    token,
    user_id: userId,
    file_name: file.name,
    file_size: file.size,
    mime_type: file.type || 'application/octet-stream',
    storage_path: storagePath,
    expires_at: expiresAt,
    max_downloads: oneTime ? 1 : null,
  });
  if (insertError) {
    console.error('[share] insert failed:', insertError.message);
    await admin.storage.from('shares').remove([storagePath]);
    return apiErr('Could not create share link', 500);
  }

  const origin = process.env.NEXT_PUBLIC_APP_URL || new URL(req.url).origin;
  return apiOk({
    token,
    url: `${origin}/api/share/${token}`,
    expiresAt,
  });
}
