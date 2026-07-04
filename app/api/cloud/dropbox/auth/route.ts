import { NextResponse } from 'next/server';
import { getCallerPlan, isProPlan } from '@/lib/share';

export const dynamic = 'force-dynamic';

/** GET /api/cloud/dropbox/auth — start Dropbox OAuth (Pro). */
export async function GET(req: Request) {
  const { userId, plan } = await getCallerPlan();
  if (!userId || !isProPlan(plan)) {
    return NextResponse.redirect(new URL('/dashboard/billing?feature=dropbox', req.url));
  }

  const appKey = process.env.DROPBOX_APP_KEY;
  if (!appKey) return NextResponse.json({ error: 'Dropbox not configured' }, { status: 503 });

  const url = new URL(req.url);
  const returnTo = url.searchParams.get('returnTo') || '/tools';
  const origin = process.env.NEXT_PUBLIC_APP_URL || url.origin;
  const redirectUri = `${origin}/api/cloud/dropbox/callback`;
  const state = Buffer.from(JSON.stringify({ returnTo, userId })).toString('base64url');

  const authUrl = new URL('https://www.dropbox.com/oauth2/authorize');
  authUrl.searchParams.set('client_id', appKey);
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('token_access_type', 'offline');
  authUrl.searchParams.set('state', state);

  return NextResponse.redirect(authUrl.toString());
}
