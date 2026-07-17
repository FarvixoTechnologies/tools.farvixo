'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useRef, useState } from 'react';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { useAuth } from '@/components/providers/AuthProvider';
import { createClient } from '@/lib/supabase/client';
import { initials } from '@/lib/auth';

/* ------------------------------------------------------------------ */
/* Types                                                               */
/* ------------------------------------------------------------------ */

type TabKey = 'profile' | 'security' | 'preferences' | 'notifications' | 'data';

interface SettingsData {
  profile: { full_name: string; avatar_url: string | null };
  settings: {
    locale: string;
    theme: string;
    email_notifications: boolean;
    push_notifications: boolean;
    marketing_opt_in: boolean;
    bio: string;
  };
  socials: { github_username: string | null; twitter_handle: string | null; website: string | null };
  loginHistory: Array<{
    provider: string | null;
    success: boolean;
    ip: string | null;
    user_agent: string | null;
    created_at: string;
  }>;
}

const TABS: Array<{ key: TabKey; label: string; icon: string }> = [
  { key: 'profile', label: 'Profile', icon: 'user' },
  { key: 'security', label: 'Security', icon: 'shield' },
  { key: 'preferences', label: 'Preferences', icon: 'settings' },
  { key: 'notifications', label: 'Notifications', icon: 'bell' },
  { key: 'data', label: 'Privacy & Data', icon: 'lock' },
];

const LANGS: Array<{ code: string; label: string }> = [
  { code: 'en', label: 'English' },
  { code: 'hi', label: 'हिन्दी (Hindi)' },
  { code: 'bn', label: 'বাংলা (Bengali)' },
  { code: 'es', label: 'Español' },
  { code: 'pt', label: 'Português' },
  { code: 'fr', label: 'Français' },
  { code: 'de', label: 'Deutsch' },
  { code: 'ar', label: 'العربية' },
];

/* ------------------------------------------------------------------ */
/* Theme helper — matches GlobalUI (localStorage 'farvixo_theme')      */
/* ------------------------------------------------------------------ */

function applyTheme(theme: string) {
  if (typeof document === 'undefined') return;
  const resolved =
    theme === 'system'
      ? window.matchMedia('(prefers-color-scheme: light)').matches
        ? 'light'
        : 'dark'
      : theme;
  document.documentElement.setAttribute('data-theme', resolved);
  try {
    localStorage.setItem('farvixo_theme', resolved);
    localStorage.setItem('farvixo_theme_choice', theme);
  } catch {
    /* ignore */
  }
}

function timeAgo(iso: string): string {
  const s = Math.max(1, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return new Date(iso).toLocaleString();
}

/* ------------------------------------------------------------------ */
/* Toggle switch                                                       */
/* ------------------------------------------------------------------ */

function Toggle({ on, onChange, label, desc }: { on: boolean; onChange: (v: boolean) => void; label: string; desc: string }) {
  return (
    <div className="set-row">
      <div>
        <b>{label}</b>
        <span className="muted set-row-desc">{desc}</span>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-label={label}
        className={`set-switch ${on ? 'on' : ''}`}
        onClick={() => onChange(!on)}
      >
        <span className="set-switch-knob" />
      </button>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Page                                                                */
/* ------------------------------------------------------------------ */

export default function SettingsPage() {
  const router = useRouter();
  const { toast } = useUI();
  const { user, refresh, signOut } = useAuth();

  const [tab, setTab] = useState<TabKey>('profile');
  const [data, setData] = useState<SettingsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  // security inputs
  const [newEmail, setNewEmail] = useState('');
  const [pw1, setPw1] = useState('');
  const [pw2, setPw2] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/account/settings');
      const json = (await res.json()) as { success: boolean; data?: SettingsData; error?: string };
      if (json.success && json.data) setData(json.data);
      else toast(json.error || 'Could not load settings', 'error');
    } catch {
      toast('Could not load settings', 'error');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => { void load(); }, [load]);

  /* -------- generic PATCH -------- */
  const patch = useCallback(
    async (body: Record<string, unknown>, successMsg = 'Saved') => {
      setSaving(true);
      try {
        const res = await fetch('/api/account/settings', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
        const json = (await res.json()) as { success: boolean; error?: string };
        if (!json.success) throw new Error(json.error || 'Save failed');
        toast(successMsg, 'success');
        return true;
      } catch (err) {
        toast(err instanceof Error ? err.message : 'Save failed', 'error');
        return false;
      } finally {
        setSaving(false);
      }
    },
    [toast],
  );

  const setField = <K extends keyof SettingsData>(section: K, patchObj: Partial<SettingsData[K]>) => {
    setData((d) => (d ? { ...d, [section]: { ...d[section], ...patchObj } } : d));
  };

  /* -------- profile save -------- */
  const saveProfile = async () => {
    if (!data) return;
    if (!data.profile.full_name.trim()) { toast('Name cannot be empty', 'error'); return; }
    const ok = await patch(
      {
        profile: { full_name: data.profile.full_name.trim() },
        settings: { bio: data.settings.bio },
        socials: data.socials,
      },
      'Profile updated',
    );
    if (ok) await refresh();
  };

  /* -------- avatar upload -------- */
  const onAvatarPick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file || !user) return;
    if (file.size > 5 * 1024 * 1024) { toast('Image must be under 5MB', 'error'); return; }
    const supabase = createClient();
    if (!supabase) { toast('Account service unavailable', 'error'); return; }

    setSaving(true);
    try {
      const ext = (file.name.split('.').pop() || 'png').toLowerCase();
      const path = `${user.id}/avatar-${Date.now()}.${ext}`;
      const { error: upErr } = await supabase.storage.from('avatars').upload(path, file, { upsert: true, cacheControl: '3600' });
      if (upErr) throw upErr;
      const { data: pub } = supabase.storage.from('avatars').getPublicUrl(path);
      const url = pub.publicUrl;
      const ok = await patch({ profile: { avatar_url: url } }, 'Photo updated');
      if (ok) { setField('profile', { avatar_url: url }); await refresh(); }
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Upload failed', 'error');
    } finally {
      setSaving(false);
    }
  };

  const removeAvatar = async () => {
    const ok = await patch({ profile: { avatar_url: null } }, 'Photo removed');
    if (ok) { setField('profile', { avatar_url: null }); await refresh(); }
  };

  /* -------- security actions -------- */
  const changeEmail = async () => {
    const email = newEmail.trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { toast('Enter a valid email', 'error'); return; }
    const supabase = createClient();
    if (!supabase) { toast('Account service unavailable', 'error'); return; }
    setSaving(true);
    const { error } = await supabase.auth.updateUser({ email });
    setSaving(false);
    if (error) { toast(error.message, 'error'); return; }
    setNewEmail('');
    toast('Confirmation link sent to your new email address.', 'success');
  };

  const changePassword = async () => {
    if (pw1.length < 8) { toast('Password must be at least 8 characters', 'error'); return; }
    if (pw1 !== pw2) { toast('Passwords do not match', 'error'); return; }
    const supabase = createClient();
    if (!supabase) { toast('Account service unavailable', 'error'); return; }
    setSaving(true);
    const { error } = await supabase.auth.updateUser({ password: pw1 });
    setSaving(false);
    if (error) { toast(error.message, 'error'); return; }
    setPw1(''); setPw2('');
    toast('Password updated', 'success');
  };

  const signOutEverywhere = async () => {
    if (!confirm('Sign out of all devices and sessions?')) return;
    const supabase = createClient();
    if (supabase) { try { await supabase.auth.signOut({ scope: 'global' }); } catch { /* ignore */ } }
    await signOut();
    toast('Signed out of all devices', 'info');
    router.push('/');
    router.refresh();
  };

  /* -------- preferences -------- */
  const setTheme = async (theme: string) => {
    setField('settings', { theme });
    applyTheme(theme);
    await patch({ settings: { theme } }, 'Theme updated');
  };

  const setLocale = async (locale: string) => {
    setField('settings', { locale });
    await patch({ settings: { locale } }, 'Language updated');
  };

  /* -------- notifications -------- */
  const setNotif = async (key: 'email_notifications' | 'push_notifications' | 'marketing_opt_in', v: boolean) => {
    setField('settings', { [key]: v } as Partial<SettingsData['settings']>);
    await patch({ settings: { [key]: v } });
  };

  /* -------- data -------- */
  const exportData = async () => {
    try {
      const res = await fetch('/api/account/export');
      if (!res.ok) throw new Error('Export failed');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `farvixo-data-${new Date().toISOString().slice(0, 10)}.json`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      toast('Your data export has downloaded', 'success');
    } catch {
      toast('Could not export data', 'error');
    }
  };

  const logout = async () => {
    await signOut();
    toast('Signed out', 'info');
    router.push('/');
    router.refresh();
  };

  const deleteAccount = async () => {
    if (!confirm('Delete your account permanently? All your data (profile, history, files) will be erased. This cannot be undone.')) return;
    try {
      const res = await fetch('/api/account/delete', { method: 'POST' });
      const json = (await res.json()) as { success: boolean; error?: string | null };
      if (!json.success) throw new Error(json.error || 'Could not delete account');
      await signOut();
      toast('Your account has been permanently deleted.', 'success');
      router.push('/');
      router.refresh();
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Could not delete account', 'error');
    }
  };

  /* ---------------------------------------------------------------- */

  if (loading || !data) {
    return (
      <div className="dash-page">
        <h1 className="dash-title">Settings</h1>
        <div className="spinner" style={{ margin: '60px auto' }} />
      </div>
    );
  }

  return (
    <div className="dash-page">
      <header className="dash-header">
        <div>
          <h1>Settings</h1>
          <p className="muted">Manage your profile, security and preferences.</p>
        </div>
      </header>

      <div className="set-tabs" role="tablist">
        {TABS.map((t) => (
          <button
            key={t.key}
            role="tab"
            aria-selected={tab === t.key}
            className={`set-tab ${tab === t.key ? 'active' : ''}`}
            onClick={() => setTab(t.key)}
          >
            <Icon name={t.icon} size={15} /> <span>{t.label}</span>
          </button>
        ))}
      </div>

      {/* ---------------- PROFILE ---------------- */}
      {tab === 'profile' && (
        <div className="set-panel">
          <div className="glass settings-block">
            <h3>Photo</h3>
            <div className="set-avatar-row">
              <span className="user-avatar set-avatar-lg">
                {data.profile.avatar_url
                  ? <img src={data.profile.avatar_url} alt="" referrerPolicy="no-referrer" />
                  : initials(data.profile.full_name || user?.fullName || 'U')}
              </span>
              <div className="set-avatar-actions">
                <button className="btn btn-primary btn-sm" disabled={saving} onClick={() => fileRef.current?.click()}>
                  <Icon name="upload" size={14} /> Upload photo
                </button>
                {data.profile.avatar_url && (
                  <button className="btn btn-ghost btn-sm" disabled={saving} onClick={() => void removeAvatar()}>Remove</button>
                )}
                <span className="muted set-hint">JPG, PNG or WebP. Max 5MB.</span>
              </div>
              <input ref={fileRef} type="file" accept="image/png,image/jpeg,image/webp,image/gif" hidden onChange={(e) => void onAvatarPick(e)} />
            </div>
          </div>

          <div className="glass settings-block mt-4">
            <h3>Public profile</h3>
            <div className="field mb-4">
              <label>Full name</label>
              <input value={data.profile.full_name} maxLength={80} onChange={(e) => setField('profile', { full_name: e.target.value })} />
            </div>
            <div className="field mb-4">
              <label>Bio</label>
              <textarea
                rows={3}
                maxLength={280}
                placeholder="A short line about you"
                value={data.settings.bio}
                onChange={(e) => setField('settings', { bio: e.target.value })}
              />
              <span className="muted set-hint">{data.settings.bio.length}/280</span>
            </div>
            <div className="set-grid-2">
              <div className="field">
                <label><Icon name="github" size={13} /> GitHub username</label>
                <input value={data.socials.github_username ?? ''} placeholder="username" onChange={(e) => setField('socials', { github_username: e.target.value })} />
              </div>
              <div className="field">
                <label><Icon name="twitter" size={13} /> X / Twitter</label>
                <input value={data.socials.twitter_handle ?? ''} placeholder="handle" onChange={(e) => setField('socials', { twitter_handle: e.target.value })} />
              </div>
            </div>
            <div className="field mt-4">
              <label><Icon name="globe" size={13} /> Website</label>
              <input value={data.socials.website ?? ''} placeholder="https://yoursite.com" onChange={(e) => setField('socials', { website: e.target.value })} />
            </div>
            <button className="btn btn-primary btn-sm mt-4" disabled={saving} onClick={() => void saveProfile()}>
              {saving ? 'Saving…' : 'Save changes'}
            </button>
          </div>
        </div>
      )}

      {/* ---------------- SECURITY ---------------- */}
      {tab === 'security' && (
        <div className="set-panel">
          <div className="glass settings-block">
            <h3>Email address</h3>
            <p className="muted set-hint mb-4">Current: <b>{user?.email}</b></p>
            <div className="field mb-4">
              <label>New email</label>
              <input type="email" value={newEmail} placeholder="you@example.com" onChange={(e) => setNewEmail(e.target.value)} />
            </div>
            <button className="btn btn-primary btn-sm" disabled={saving} onClick={() => void changeEmail()}>Update email</button>
          </div>

          <div className="glass settings-block mt-4">
            <h3>Password</h3>
            <div className="set-grid-2">
              <div className="field">
                <label>New password</label>
                <input type="password" value={pw1} placeholder="Min 8 characters" onChange={(e) => setPw1(e.target.value)} />
              </div>
              <div className="field">
                <label>Confirm password</label>
                <input type="password" value={pw2} placeholder="Repeat password" onChange={(e) => setPw2(e.target.value)} />
              </div>
            </div>
            <button className="btn btn-primary btn-sm mt-4" disabled={saving} onClick={() => void changePassword()}>
              <Icon name="key" size={14} /> Change password
            </button>
          </div>

          <div className="glass settings-block mt-4">
            <h3>Recent login activity</h3>
            {data.loginHistory.length === 0 ? (
              <p className="muted set-hint">No recent activity recorded.</p>
            ) : (
              <div className="set-history">
                {data.loginHistory.map((h, i) => (
                  <div key={i} className="set-history-row">
                    <span className={`set-dot ${h.success ? 'ok' : 'bad'}`} />
                    <div className="set-history-main">
                      <b>{h.provider ? h.provider[0].toUpperCase() + h.provider.slice(1) : 'Sign-in'}{h.success ? '' : ' · failed'}</b>
                      <span className="muted set-hint">{h.ip ?? 'unknown IP'} · {(h.user_agent ?? '').slice(0, 48)}</span>
                    </div>
                    <span className="muted set-hint">{timeAgo(h.created_at)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="glass settings-block mt-4">
            <h3>Sessions</h3>
            <div className="admin-actions-row" style={{ marginTop: 0 }}>
              <button className="btn btn-ghost btn-sm" onClick={() => void logout()}><Icon name="lock" size={14} /> Sign out</button>
              <button className="btn btn-sm set-btn-warn" onClick={() => void signOutEverywhere()}>Sign out everywhere</button>
            </div>
          </div>
        </div>
      )}

      {/* ---------------- PREFERENCES ---------------- */}
      {tab === 'preferences' && (
        <div className="set-panel">
          <div className="glass settings-block">
            <h3>Appearance</h3>
            <label className="set-label">Theme</label>
            <div className="set-seg">
              {[
                { v: 'light', label: 'Light', icon: 'sun' },
                { v: 'dark', label: 'Dark', icon: 'moon' },
                { v: 'system', label: 'System', icon: 'settings' },
              ].map((o) => (
                <button
                  key={o.v}
                  className={`set-seg-btn ${data.settings.theme === o.v ? 'active' : ''}`}
                  onClick={() => void setTheme(o.v)}
                >
                  <Icon name={o.icon} size={15} /> {o.label}
                </button>
              ))}
            </div>
          </div>

          <div className="glass settings-block mt-4">
            <h3>Language</h3>
            <div className="field">
              <label>Interface language</label>
              <select value={data.settings.locale} onChange={(e) => void setLocale(e.target.value)}>
                {LANGS.map((l) => <option key={l.code} value={l.code}>{l.label}</option>)}
              </select>
            </div>
          </div>
        </div>
      )}

      {/* ---------------- NOTIFICATIONS ---------------- */}
      {tab === 'notifications' && (
        <div className="set-panel">
          <div className="glass settings-block">
            <h3>Notification channels</h3>
            <Toggle
              on={data.settings.email_notifications}
              onChange={(v) => void setNotif('email_notifications', v)}
              label="Email notifications"
              desc="Job completions, security alerts and account updates."
            />
            <Toggle
              on={data.settings.push_notifications}
              onChange={(v) => void setNotif('push_notifications', v)}
              label="Push notifications"
              desc="Real-time alerts in your browser and app."
            />
            <Toggle
              on={data.settings.marketing_opt_in}
              onChange={(v) => void setNotif('marketing_opt_in', v)}
              label="Product & marketing emails"
              desc="New tools, tips and offers. No spam, unsubscribe anytime."
            />
          </div>
        </div>
      )}

      {/* ---------------- DATA & PRIVACY ---------------- */}
      {tab === 'data' && (
        <div className="set-panel">
          <div className="glass settings-block">
            <h3>Export your data</h3>
            <p className="muted set-hint mb-4">Download a JSON copy of your profile, settings, history and jobs (GDPR).</p>
            <button className="btn btn-ghost btn-sm" onClick={() => void exportData()}><Icon name="download" size={14} /> Download my data</button>
          </div>

          <div className="glass settings-block mt-4 danger-zone">
            <h3>Danger zone</h3>
            <p className="muted set-hint mb-4">Permanently delete your account and all associated data. This cannot be undone.</p>
            <button className="btn btn-sm set-btn-danger" onClick={() => void deleteAccount()}>Delete account</button>
          </div>
        </div>
      )}
    </div>
  );
}
