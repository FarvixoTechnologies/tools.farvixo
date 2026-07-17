'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { adminFetch } from '@/lib/admin-client';
import { useUI } from '@/components/GlobalUI';
import Icon from '@/components/Icon';

type SessionRow = {
  id: string; user_id: string; device_id: string | null; provider: string | null;
  ip: string | null; user_agent: string | null; last_active_at: string; revoked_at: string | null;
  email: string | null; full_name: string | null;
};
type LoginRow = {
  id: string; user_id: string | null; provider: string | null; success: boolean;
  ip: string | null; user_agent: string | null; created_at: string; email: string | null;
};
type DeviceRow = {
  id: string; user_id: string; device_id: string; platform: string | null;
  app_version: string | null; last_seen_at: string; email: string | null;
};
type Payload = { sessions: SessionRow[]; logins: LoginRow[]; devices: DeviceRow[] };

const VIEWS = [
  { key: 'all', label: 'All' },
  { key: 'active', label: 'Active' },
  { key: 'revoked', label: 'Revoked' },
] as const;

function userLabel(email: string | null, name: string | null, id: string | null): string {
  return email || name || (id ? `${id.slice(0, 8)}…` : '—');
}
function when(ts: string): string {
  return new Date(ts).toLocaleString();
}

export default function AdminSessionsPage() {
  const { toast } = useUI();
  const [data, setData] = useState<Payload | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [view, setView] = useState<'all' | 'active' | 'revoked'>('all');
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      setData(await adminFetch<Payload>(`/api/admin/sessions?view=${view}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, [view]);

  useEffect(() => { void load(); }, [load]);

  const act = async (action: 'revoke_session' | 'force_logout', payload: Record<string, string>, confirmMsg: string) => {
    if (!window.confirm(confirmMsg)) return;
    setBusy(payload.session_id || payload.user_id || 'x');
    try {
      const res = await adminFetch<{ revoked?: number }>('/api/admin/sessions', {
        method: 'POST',
        body: JSON.stringify({ action, ...payload }),
      });
      toast(action === 'force_logout' ? `Revoked ${res.revoked ?? 0} session(s)` : 'Session revoked', 'success');
      await load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Action failed', 'error');
    } finally {
      setBusy(null);
    }
  };

  if (loading) return <div className="spinner" style={{ margin: 60 }} />;

  return (
    <div>
      <AdminPageHeader
        title="Sessions & Devices"
        subtitle="Active sessions, device history and login audit"
        action={<button type="button" className="btn btn-ghost btn-sm" onClick={() => void load()}><Icon name="refresh" size={14} /> Refresh</button>}
      />

      {error && <div className="admin-alert error mb-4">{error}</div>}

      {/* Active sessions */}
      <div className="admin-panel glass mb-4">
        <div className="admin-panel-head">
          <h2>Active sessions</h2>
          <div className="admin-seg">
            {VIEWS.map((v) => (
              <button key={v.key} type="button" className={`admin-seg-btn ${view === v.key ? 'active' : ''}`} onClick={() => setView(v.key)}>{v.label}</button>
            ))}
          </div>
        </div>
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>User</th><th>Provider</th><th>IP</th><th>Last active</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {data?.sessions.map((s) => (
                <tr key={s.id}>
                  <td data-label="User"><b>{userLabel(s.email, s.full_name, s.user_id)}</b><div className="mono muted" style={{ fontSize: 10 }}>{s.device_id ?? '—'}</div></td>
                  <td data-label="Provider">{s.provider ?? '—'}</td>
                  <td data-label="IP" className="mono">{s.ip ?? '—'}</td>
                  <td data-label="Last active" className="muted">{when(s.last_active_at)}</td>
                  <td data-label="Status">
                    {s.revoked_at
                      ? <span className="status-pill status-failed">Revoked</span>
                      : <span className="status-pill status-completed">Active</span>}
                  </td>
                  <td data-label="Actions">
                    <div className="admin-inline-actions">
                      {!s.revoked_at && (
                        <button type="button" className="btn btn-ghost btn-sm" disabled={busy === s.id}
                          onClick={() => void act('revoke_session', { session_id: s.id }, 'Revoke this session? The user is signed out on next token refresh (~1h).')}>
                          Revoke
                        </button>
                      )}
                      <button type="button" className="btn btn-ghost btn-sm admin-actions-danger" disabled={busy === s.user_id}
                        onClick={() => void act('force_logout', { user_id: s.user_id }, 'Force logout ALL sessions for this user?')}>
                        Force logout
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!data?.sessions.length && <tr><td colSpan={6} className="muted">No sessions</td></tr>}
            </tbody>
          </table>
        </div>
      </div>

      <div className="admin-split">
        {/* Login history */}
        <div className="admin-panel glass">
          <h2>Login history</h2>
          <div className="admin-table-scroll">
            <table className="admin-table admin-table-cards">
              <thead><tr><th>When</th><th>User</th><th>Provider</th><th>OK</th><th>IP</th></tr></thead>
              <tbody>
                {data?.logins.map((r) => (
                  <tr key={r.id}>
                    <td data-label="When" className="muted">{when(r.created_at)}</td>
                    <td data-label="User">{userLabel(r.email, null, r.user_id)}</td>
                    <td data-label="Provider">{r.provider ?? '—'}</td>
                    <td data-label="OK">{r.success ? <span className="status-pill status-completed">✓</span> : <span className="status-pill status-failed">✗</span>}</td>
                    <td data-label="IP" className="mono">{r.ip ?? '—'}</td>
                  </tr>
                ))}
                {!data?.logins.length && <tr><td colSpan={5} className="muted">No login rows yet</td></tr>}
              </tbody>
            </table>
          </div>
        </div>

        {/* Devices */}
        <div className="admin-panel glass">
          <h2>Devices</h2>
          <div className="admin-table-scroll">
            <table className="admin-table admin-table-cards">
              <thead><tr><th>User</th><th>Platform</th><th>Version</th><th>Last seen</th></tr></thead>
              <tbody>
                {data?.devices.map((d) => (
                  <tr key={d.id}>
                    <td data-label="User">{userLabel(d.email, null, d.user_id)}</td>
                    <td data-label="Platform">{d.platform ?? '—'}</td>
                    <td data-label="Version" className="muted">{d.app_version ?? '—'}</td>
                    <td data-label="Last seen" className="muted">{when(d.last_seen_at)}</td>
                  </tr>
                ))}
                {!data?.devices.length && <tr><td colSpan={4} className="muted">No devices yet</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
