import { createBrowserClient } from '@supabase/ssr';
import { getSupabaseEnv } from './env';

let warned = false;

/**
 * Browser Supabase client.
 *
 * Returns `null` when the public env vars are not configured (e.g. a build
 * where NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY were not
 * available). This lets the app render and degrade gracefully instead of
 * throwing a client-side exception that crashes the whole page.
 *
 * Callers MUST handle a `null` return (auth / account features are simply
 * disabled until the env vars are provided by the deployment platform).
 */
export function createClient() {
  const env = getSupabaseEnv();
  if (!env) {
    if (!warned && typeof window !== 'undefined') {
      warned = true;
      console.warn(
        'Supabase environment variables are missing. Auth and account features are disabled. ' +
          'Check your deployment platform environment configuration.',
      );
    }
    return null;
  }
  return createBrowserClient(env.url, env.anonKey);
}
