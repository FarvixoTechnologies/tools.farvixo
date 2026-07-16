import { createClient } from '@/lib/supabase/client';
import { getAppOrigin, getAuthCallbackUrl } from '@/lib/supabase/auth-url';

type OAuthProvider = 'google' | 'github';

/** Start OAuth in the browser so PKCE verifier is stored in cookies before leaving the site. */
export async function startOAuth(provider: OAuthProvider, next = '/dashboard'): Promise<void> {
  const origin = typeof window !== 'undefined' ? window.location.origin : getAppOrigin();
  const supabase = createClient();
  if (!supabase) throw new Error('Sign-in is temporarily unavailable — please try again later.');

  const { error } = await supabase.auth.signInWithOAuth({
    provider,
    options: {
      redirectTo: getAuthCallbackUrl(origin, next),
    },
  });

  if (error) throw error;
}

/** Passwordless email magic link — redirects to /auth/callback after the user clicks the link. */
export async function startEmailMagicLink(email: string, next = '/dashboard'): Promise<void> {
  const origin = typeof window !== 'undefined' ? window.location.origin : getAppOrigin();
  const supabase = createClient();
  if (!supabase) throw new Error('Sign-in is temporarily unavailable — please try again later.');

  const { error } = await supabase.auth.signInWithOtp({
    email: email.trim(),
    options: {
      emailRedirectTo: getAuthCallbackUrl(origin, next),
    },
  });

  if (error) throw error;
}

/** Email confirmation / signup redirect URL (same callback as magic link + OAuth). */
export function getEmailRedirectUrl(next = '/dashboard'): string {
  const origin = typeof window !== 'undefined' ? window.location.origin : getAppOrigin();
  return getAuthCallbackUrl(origin, next);
}
