import { apiErr, apiOk } from '@/lib/api-response';
import { getValidDropboxAccessToken, uploadToDropbox } from '@/lib/cloud/dropbox';
import { getCallerPlan, isProPlan } from '@/lib/share';

export const dynamic = 'force-dynamic';

/** POST /api/cloud/dropbox/export */
export async function POST(req: Request) {
  const { userId, plan } = await getCallerPlan();
  if (!userId || !isProPlan(plan)) return apiErr('Dropbox export requires Pro', 403);

  const accessToken = await getValidDropboxAccessToken(userId);
  if (!accessToken) return apiErr('Connect Dropbox first', 401);

  const fileName = req.headers.get('x-file-name') || 'toolnest-export';
  const body = await req.arrayBuffer();

  try {
    const result = await uploadToDropbox(accessToken, fileName, body);
    return apiOk(result);
  } catch (e) {
    return apiErr(e instanceof Error ? e.message : 'Upload failed', 500);
  }
}
