import { type NextRequest, NextResponse } from 'next/server';
import { resolvePostLoginPath } from '@/lib/auth';
import { getAppOrigin } from '@/lib/supabase/auth-url';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';

export async function GET(request: NextRequest) {
  const origin = getAppOrigin(request.nextUrl.origin);
  const code = request.nextUrl.searchParams.get('code');
  const next = request.nextUrl.searchParams.get('next') ?? '/dashboard';
  const authError =
    request.nextUrl.searchParams.get('error_description') || request.nextUrl.searchParams.get('error');

  if (authError) {
    return NextResponse.redirect(`${origin}/login?error=${encodeURIComponent(authError)}`);
  }

  if (!code) {
    return NextResponse.redirect(`${origin}/login?error=missing_auth_code`);
  }

  const { supabase } = await createRouteHandlerClient();

  const { data, error } = await supabase.auth.exchangeCodeForSession(code);

  if (error || !data.user) {
    return NextResponse.redirect(
      `${origin}/login?error=${encodeURIComponent(error?.message || 'auth_callback_failed')}`,
    );
  }

  const user = data.user;
  const fullName =
    (user.user_metadata?.full_name as string | undefined) ||
    (user.user_metadata?.name as string | undefined) ||
    user.email?.split('@')[0] ||
    'User';

  // Do NOT overwrite plan/role — only fill profile identity fields
  const { data: existing } = await supabase
    .from('profiles')
    .select('id, role, plan')
    .eq('id', user.id)
    .maybeSingle();

  if (!existing) {
    await supabase.from('profiles').insert({
      id: user.id,
      full_name: fullName,
      avatar_url: (user.user_metadata?.avatar_url as string | undefined) ?? null,
      plan: 'FREE',
      role: 'USER',
      updated_at: new Date().toISOString(),
    });
  } else {
    await supabase
      .from('profiles')
      .update({
        full_name: fullName,
        avatar_url: (user.user_metadata?.avatar_url as string | undefined) ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', user.id);
  }

  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle();
  const dest = resolvePostLoginPath(next, profile?.role ?? existing?.role);

  return NextResponse.redirect(`${origin}${dest}`);
}
