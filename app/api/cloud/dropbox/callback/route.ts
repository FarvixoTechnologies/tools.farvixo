import { NextResponse } from 'next/server';
import { exchangeDropboxCode } from '@/lib/cloud/dropbox';
import { saveCloudTokens } from '@/lib/cloud/google-drive';

export const dynamic = 'force-dynamic';

/** GET /api/cloud/dropbox/callback */
export async function GET(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const stateRaw = url.searchParams.get('state');
  if (!code || !stateRaw) {
    return NextResponse.redirect(new URL('/tools?cloud=error', req.url));
  }

  let returnTo = '/tools';
  let userId = '';
  try {
    const state = JSON.parse(Buffer.from(stateRaw, 'base64url').toString()) as {
      returnTo?: string;
      userId?: string;
    };
    returnTo = state.returnTo || '/tools';
    userId = state.userId || '';
  } catch {
    return NextResponse.redirect(new URL('/tools?cloud=error', req.url));
  }

  const origin = process.env.NEXT_PUBLIC_APP_URL || url.origin;
  const redirectUri = `${origin}/api/cloud/dropbox/callback`;

  try {
    const tokens = await exchangeDropboxCode(code, redirectUri);
    if (userId) {
      const expiresAt = tokens.expires_in
        ? new Date(Date.now() + tokens.expires_in * 1000)
        : null;
      await saveCloudTokens(
        userId,
        'dropbox',
        tokens.access_token,
        tokens.refresh_token ?? null,
        expiresAt,
      );
    }
    return NextResponse.redirect(new URL(`${returnTo}?cloud=dropbox-connected`, req.url));
  } catch {
    return NextResponse.redirect(new URL(`${returnTo}?cloud=error`, req.url));
  }
}
