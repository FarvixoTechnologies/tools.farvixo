'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { useAuth } from '@/components/providers/AuthProvider';
import { startOAuth } from '@/lib/auth-oauth';

export default function AdminLoginForm() {
  const router = useRouter();
  const { toast } = useUI();
  const { refresh } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  const login = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail || !password) {
      toast('Enter email and password', 'error');
      return;
    }

    setBusy(true);
    try {
      const res = await fetch('/api/admin/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: cleanEmail, password }),
      });
      const json = (await res.json()) as {
        success: boolean;
        error?: string | null;
        data?: { redirectTo?: string };
      };

      if (!json.success) {
        toast(json.error || 'Invalid login credentials', 'error');
        return;
      }

      await refresh();
      toast('Welcome, Admin!', 'success');
      router.replace(json.data?.redirectTo || '/admin');
      router.refresh();
    } catch {
      toast('Network error — try again', 'error');
    } finally {
      setBusy(false);
    }
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
          <p className="muted">Farvixo Control Center — authorized staff only</p>
        </div>
        <form onSubmit={(e) => void login(e)} autoComplete="on">
          <div className="field mb-4">
            <label htmlFor="admin-email">Email</label>
            <input
              id="admin-email"
              name="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@farvixo.com"
              autoComplete="username"
              required
            />
          </div>
          <div className="field mb-4">
            <label htmlFor="admin-password">Password</label>
            <input
              id="admin-password"
              name="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              autoComplete="current-password"
              required
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
