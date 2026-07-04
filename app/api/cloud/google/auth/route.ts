import { NextResponse } from 'next/server';
import { getCallerPlan, isProPlan } from '@/lib/share';

export const dynamic = 'force-dynamic';

const SCOPES = [
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/drive.readonly',
].join(' ');

/** GET /api/cloud/google/auth — start Google OAuth (Pro). */
export async function GET(req: Request) {
  const { userId, plan } = await getCallerPlan();
  if (!userId || !isProPlan(plan)) {
    return NextResponse.redirect(new URL('/dashboard/billing?feature=google-drive', req.url));
  }

  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) return NextResponse.json({ error: 'Google Drive not configured' }, { status: 503 });

  const url = new URL(req.url);
  const returnTo = url.searchParams.get('returnTo') || '/tools';
  const origin = process.env.NEXT_PUBLIC_APP_URL || url.origin;
  const redirectUri = `${origin}/api/cloud/google/callback`;

  const state = Buffer.from(JSON.stringify({ returnTo, userId })).toString('base64url');
  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  authUrl.searchParams.set('client_id', clientId);
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', SCOPES);
  authUrl.searchParams.set('access_type', 'offline');
  authUrl.searchParams.set('prompt', 'consent');
  authUrl.searchParams.set('state', state);

  return NextResponse.redirect(authUrl.toString());
}
