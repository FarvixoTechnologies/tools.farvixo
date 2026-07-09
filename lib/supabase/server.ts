import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { getSupabaseEnv } from './env';

export async function createClient() {
  const env = getSupabaseEnv();
  if (!env) {
    throw new Error(
      'Supabase environment variables are missing. Check your deployment platform environment configuration.',
    );
  }
  const cookieStore = await cookies();

  return createServerClient(env.url, env.anonKey, {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            /* set from Server Component — middleware handles refresh */
          }
        },
      },
    },
  );
}
