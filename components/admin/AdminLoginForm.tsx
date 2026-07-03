'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { useAuth } from '@/components/providers/AuthProvider';
import { isAdminRoleString } from '@/lib/auth';
import { startOAuth } from '@/lib/auth-oauth';
import { createClient } from '@/lib/supabase/client';

export default function AdminLoginForm() {
  const router = useRouter();
  const { toast } = useUI();
  const { refresh } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  const login = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password.trim()) {
      toast('Enter email and password', 'error');
      return;
    }
    setBusy(true);
    const supabase = createClient();
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error || !data.user) {
      setBusy(false);
      toast(error?.message || 'Sign in failed', 'error');
      return;
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', data.user.id)
      .maybeSingle();

    if (!isAdminRoleString(profile?.role)) {
      await supabase.auth.signOut();
      setBusy(false);
      toast('Admin access required. Use the user login page.', 'error');
      return;
    }

    await refresh();
    setBusy(false);
    toast('Welcome, Admin!', 'success');
    router.replace('/admin');
    router.refresh();
  };

  const oauth = async (provider: 'google' | 'github') => {
    setBusy(true);
    try {
      await startOAuth(provider, '/admin');
    } catch (err) {
      toast(err instanceof Error ? err.message : 'OAuth failed', 'error');
      setBusy(false);
    }
  };

  return (
    <div className="admin-login-page">
      <div className="admin-login-card glass">
        <div className="admin-login-head">
          <span className="logo-mark admin-mark"><Icon name="crown" size={22} /></span>
          <h1>Admin Login</h1>
          <p className="muted">ToolNest Control Center — authorized staff only</p>
        </div>
        <form onSubmit={(e) => void login(e)}>
          <div className="field mb-4">
            <label htmlFor="admin-email">Email</label>
            <input
              id="admin-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@toolnestfm.com"
              autoComplete="email"
            />
          </div>
          <div className="field mb-4">
            <label htmlFor="admin-password">Password</label>
            <input
              id="admin-password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              autoComplete="current-password"
            />
          </div>
          <button type="submit" className="btn btn-primary w-full" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in to Admin'}
          </button>
        </form>
        <div className="auth-divider"><span>or continue with</span></div>
        <div className="auth-oauth">
          <button type="button" className="btn btn-ghost" disabled={busy} onClick={() => void oauth('google')}>Google</button>
          <button type="button" className="btn btn-ghost" disabled={busy} onClick={() => void oauth('github')}>GitHub</button>
        </div>
        <p className="auth-foot muted">
          User account? <Link href="/login">User login</Link>
          {' · '}
          <Link href="/">Back to site</Link>
        </p>
      </div>
    </div>
  );
}
