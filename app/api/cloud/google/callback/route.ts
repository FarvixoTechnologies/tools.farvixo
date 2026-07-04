import { NextResponse } from 'next/server';
import { saveCloudTokens } from '@/lib/cloud/google-drive';

export const dynamic = 'force-dynamic';

/** GET /api/cloud/google/callback — OAuth callback. */
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

  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const origin = process.env.NEXT_PUBLIC_APP_URL || url.origin;
  const redirectUri = `${origin}/api/cloud/google/callback`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: clientId!,
      client_secret: clientSecret!,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    }),
  });

  if (!tokenRes.ok) {
    return NextResponse.redirect(new URL(`${returnTo}?cloud=error`, req.url));
  }

  const tokens = (await tokenRes.json()) as {
    access_token: string;
    refresh_token?: string;
    expires_in?: number;
    scope?: string;
  };

  if (userId) {
    const expiresAt = tokens.expires_in
      ? new Date(Date.now() + tokens.expires_in * 1000)
      : null;
    await saveCloudTokens(
      userId,
      'google',
      tokens.access_token,
      tokens.refresh_token ?? null,
      expiresAt,
      tokens.scope,
    );
  }

  return NextResponse.redirect(new URL(`${returnTo}?cloud=google-connected`, req.url));
}
