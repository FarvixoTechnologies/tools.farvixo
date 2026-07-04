import { apiErr, apiOk } from '@/lib/api-response';
import { getValidGoogleAccessToken, uploadToGoogleDrive } from '@/lib/cloud/google-drive';
import { getCallerPlan, isProPlan } from '@/lib/share';

export const dynamic = 'force-dynamic';

/** POST /api/cloud/google/export — upload file to Drive (Pro). Body: raw file bytes + headers. */
export async function POST(req: Request) {
  const { userId, plan } = await getCallerPlan();
  if (!userId || !isProPlan(plan)) return apiErr('Google Drive export requires Pro', 403);

  const accessToken = await getValidGoogleAccessToken(userId);
  if (!accessToken) return apiErr('Connect Google Drive first', 401);

  const fileName = req.headers.get('x-file-name') || 'toolnest-export';
  const mimeType = req.headers.get('content-type') || 'application/octet-stream';
  const body = await req.arrayBuffer();

  try {
    const result = await uploadToGoogleDrive(accessToken, fileName, mimeType, body);
    return apiOk({ id: result.id, webViewLink: result.webViewLink });
  } catch (e) {
    return apiErr(e instanceof Error ? e.message : 'Upload failed', 500);
  }
}

/** GET /api/cloud/google/export — return access token for Picker (Pro). */
export async function GET() {
  const { userId, plan } = await getCallerPlan();
  if (!userId || !isProPlan(plan)) return apiErr('Google Drive requires Pro', 403);

  const accessToken = await getValidGoogleAccessToken(userId);
  if (!accessToken) return apiErr('Connect Google Drive first', 401);

  const clientId = process.env.GOOGLE_CLIENT_ID;
  const apiKey = process.env.GOOGLE_PICKER_API_KEY;
  return apiOk({ accessToken, clientId, apiKey, appId: process.env.GOOGLE_APP_ID });
}
