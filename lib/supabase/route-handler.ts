import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';
import { getSupabaseEnv } from './env';

type PendingCookie = { name: string; value: string; options: CookieOptions };

/** Supabase client for Route Handlers — PKCE verifier stored in httpOnly cookies. */
export function createRouteHandlerClient(request: NextRequest) {
  const env = getSupabaseEnv();
  if (!env) throw new Error('Missing Supabase environment variables.');

  const pending = new Map<string, PendingCookie>();

  const supabase = createServerClient(env.url, env.anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: PendingCookie[]) {
        cookiesToSet.forEach((cookie) => {
          request.cookies.set(cookie.name, cookie.value);
          pending.set(cookie.name, cookie);
        });
      },
    },
  });

  function applyCookies<T extends NextResponse>(response: T): T {
    pending.forEach(({ name, value, options }) => {
      response.cookies.set(name, value, {
        ...options,
        path: options?.path ?? '/',
        sameSite: options?.sameSite ?? 'lax',
        secure: options?.secure ?? process.env.NODE_ENV === 'production',
      });
    });
    return response;
  }

  return { supabase, applyCookies };
}
