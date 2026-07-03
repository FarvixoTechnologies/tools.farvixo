import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse } from 'next/server';
import { isAdminRoleString } from '@/lib/auth';
import { createAdminClient } from '@/lib/supabase/admin';
import { getSupabaseEnv } from '@/lib/supabase/env';

export const dynamic = 'force-dynamic';

type PendingCookie = { name: string; value: string; options: CookieOptions };

export async function POST(req: Request) {
  const env = getSupabaseEnv();
  if (!env) {
    return NextResponse.json(
      { success: false, data: null, error: 'Supabase not configured', meta: {} },
      { status: 503 },
    );
  }

  let body: { email?: string; password?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return NextResponse.json(
      { success: false, data: null, error: 'Invalid request body', meta: {} },
      { status: 400 },
    );
  }

  const email = body.email?.trim().toLowerCase() ?? '';
  const password = body.password ?? '';

  if (!email || !password) {
    return NextResponse.json(
      { success: false, data: null, error: 'Email and password are required', meta: {} },
      { status: 400 },
    );
  }

  const pending = new Map<string, PendingCookie>();

  const supabase = createServerClient(env.url, env.anonKey, {
    cookies: {
      getAll() {
        return [];
      },
      setAll(cookiesToSet: PendingCookie[]) {
        cookiesToSet.forEach((cookie) => pending.set(cookie.name, cookie));
      },
    },
  });

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error || !data.user) {
    return NextResponse.json(
      { success: false, data: null, error: error?.message || 'Invalid login credentials', meta: {} },
      { status: 401 },
    );
  }

  const admin = createAdminClient();
  let role: string | null = null;

  if (admin) {
    const { data: profile } = await admin
      .from('profiles')
      .select('role')
      .eq('id', data.user.id)
      .maybeSingle();
    role = profile?.role ?? null;
  }

  if (!isAdminRoleString(role)) {
    return NextResponse.json(
      { success: false, data: null, error: 'Admin access required. Use /login for user accounts.', meta: {} },
      { status: 403 },
    );
  }

  const res = NextResponse.json({
    success: true,
    data: { ok: true, role, email: data.user.email, redirectTo: '/admin' },
    error: null,
    meta: {},
  });

  pending.forEach(({ name, value, options }) => {
    res.cookies.set(name, value, {
      ...options,
      path: options?.path ?? '/',
      sameSite: options?.sameSite ?? 'lax',
      secure: options?.secure ?? process.env.NODE_ENV === 'production',
    });
  });

  return res;
}
