import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { isAdminRoleString, resolvePostLoginPath } from '@/lib/auth';
import { auditDenial, checkSessionGate, gateMessage } from '@/lib/session-gate';
import { getSupabaseEnv } from './env';

/** Clears all Supabase auth cookies (including chunked .0/.1 variants). */
function clearAuthCookies(request: NextRequest, response: NextResponse): void {
  for (const c of request.cookies.getAll()) {
    if (c.name.startsWith('sb-')) response.cookies.set(c.name, '', { maxAge: 0, path: '/' });
  }
}

export async function updateSession(request: NextRequest) {
  const env = getSupabaseEnv();
  if (!env) return NextResponse.next({ request });

  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(env.url, env.anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        supabaseResponse = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => supabaseResponse.cookies.set(name, value, options));
      },
    },
  });

  const { data: { user } } = await supabase.auth.getUser();
  const pathname = request.nextUrl.pathname;
  const isAdminRoute = pathname === '/admin' || pathname.startsWith('/admin/');

  // ── Immediate session enforcement ──────────────────────────────────────
  // For any authenticated request, verify the session hasn't been revoked and
  // the account isn't banned/suspended/deleted. One cached lightweight lookup.
  if (user) {
    const deviceId = request.cookies.get('fv_device')?.value ?? '';
    const reason = await checkSessionGate(supabase, user.id, deviceId);
    if (reason) {
      auditDenial(user.id, reason, pathname);
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      url.search = '';
      url.searchParams.set('reason', reason);
      const redirect = NextResponse.redirect(url);
      clearAuthCookies(request, redirect);
      // Best-effort server-side sign-out so the refresh token can't be reused.
      try { await supabase.auth.signOut(); } catch { /* cookies already cleared */ }
      return redirect;
    }
  }

  // User dashboard still requires login
  if (!user && pathname.startsWith('/dashboard')) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('redirect', pathname);
    return NextResponse.redirect(url);
  }

  // /admin is public login gate — do NOT redirect to /login
  // Unauthenticated users see AdminLoginForm on /admin itself

  if (user && (pathname === '/login' || pathname === '/signup')) {
    const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    const dest = resolvePostLoginPath(null, profile?.role);
    const url = request.nextUrl.clone();
    url.pathname = dest;
    url.search = '';
    return NextResponse.redirect(url);
  }

  // Logged-in non-admins cannot use admin panel pages
  if (user && isAdminRoute) {
    const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
    if (!isAdminRoleString(profile?.role)) {
      const url = request.nextUrl.clone();
      url.pathname = '/dashboard';
      url.search = '';
      return NextResponse.redirect(url);
    }
  }

  return supabaseResponse;
}
