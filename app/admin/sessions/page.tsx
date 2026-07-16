'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { adminFetch } from '@/lib/admin-client';

type Payload = {
  sessions: { id: string; user_id: string; provider: string | null; ip: string | null; last_active_at: string; revoked_at: string | null }[];
  logins: { id: string; user_id: string | null; provider: string | null; success: boolean; ip: string | null; created_at: string }[];
  devices: { id: string; user_id: string; platform: string | null; device_id: string; last_seen_at: string }[];
  errors: Record<string, string | null>;
};

export default function AdminSessionsPage() {
  const [data, setData] = useState<Payload | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(await adminFetch<Payload>('/api/admin/sessions'));
    } catch {
      setData(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  if (loading) return <div className="spinner" style={{ margin: 60 }} />;

  return (
    <div>
      <AdminPageHeader
        title="Sessions & Devices"
        subtitle="Login history, devices, app sessions"
        action={<button type="button" className="btn btn-ghost btn-sm" onClick={() => void load()}>Refresh</button>}
      />
      {data?.errors && Object.values(data.errors).some(Boolean) && (
        <div className="admin-panel glass mb-4">
          <p className="muted">Some tables missing — run <code>08</code> + <code>09</code> SQL. {JSON.stringify(data.errors)}</p>
        </div>
      )}
      <div className="admin-panel glass mb-4">
        <h2>Login history</h2>
        <table className="admin-table">
          <thead><tr><th>When</th><th>User</th><th>Provider</th><th>OK</th><th>IP</th></tr></thead>
          <tbody>
            {(data?.logins ?? []).map((r) => (
              <tr key={r.id}>
                <td>{new Date(r.created_at).toLocaleString()}</td>
                <td className="muted">{r.user_id?.slice(0, 8) ?? '—'}…</td>
                <td>{r.provider}</td>
                <td>{r.success ? '✓' : '✗'}</td>
                <td>{r.ip ?? '—'}</td>
              </tr>
            ))}
            {!data?.logins?.length && <tr><td colSpan={5} className="muted">No login rows</td></tr>}
          </tbody>
        </table>
      </div>
      <div className="admin-split">
        <div className="admin-panel glass">
          <h2>Sessions</h2>
          <table className="admin-table">
            <thead><tr><th>User</th><th>Provider</th><th>Last active</th></tr></thead>
            <tbody>
              {(data?.sessions ?? []).map((s) => (
                <tr key={s.id}>
                  <td className="muted">{s.user_id.slice(0, 8)}…</td>
                  <td>{s.provider}</td>
                  <td>{new Date(s.last_active_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="admin-panel glass">
          <h2>Devices</h2>
          <table className="admin-table">
            <thead><tr><th>User</th><th>Platform</th><th>Last seen</th></tr></thead>
            <tbody>
              {(data?.devices ?? []).map((d) => (
                <tr key={d.id}>
                  <td className="muted">{d.user_id.slice(0, 8)}…</td>
                  <td>{d.platform ?? d.device_id}</td>
                  <td>{new Date(d.last_seen_at).toLocaleString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
