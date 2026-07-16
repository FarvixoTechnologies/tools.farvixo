'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { useUI } from '@/components/GlobalUI';
import { adminFetch } from '@/lib/admin-client';

type Payload = {
  blockedIps: { ip: string; reason: string | null; created_at: string }[];
  failedLogins: { id: string; email: string | null; ip: string | null; reason: string | null; created_at: string }[];
  securityEvents: { id: string; event: string; severity: string; created_at: string }[];
  ready: boolean;
  errors: Record<string, string | null>;
};

export default function AdminSecurityPage() {
  const { toast } = useUI();
  const [data, setData] = useState<Payload | null>(null);
  const [ip, setIp] = useState('');
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(await adminFetch<Payload>('/api/admin/security'));
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    void load();
  }, [load]);

  const block = async () => {
    try {
      await adminFetch('/api/admin/security', { method: 'POST', body: JSON.stringify({ ip, reason }) });
      toast('IP blocked', 'success');
      setIp('');
      setReason('');
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    }
  };

  const unblock = async (blocked: string) => {
    try {
      await adminFetch(`/api/admin/security?ip=${encodeURIComponent(blocked)}`, { method: 'DELETE' });
      toast('Unblocked', 'success');
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    }
  };

  if (loading) return <div className="spinner" style={{ margin: 60 }} />;

  return (
    <div>
      <AdminPageHeader title="Security" subtitle="Blocked IPs, failed logins, security events" />
      {!data?.ready && (
        <div className="admin-panel glass mb-4">
          <p className="muted">Run <code>09</code> SQL for security tables. {JSON.stringify(data?.errors)}</p>
        </div>
      )}
      <div className="admin-panel glass mb-4">
        <h2>Block IP / CIDR</h2>
        <div className="admin-form-grid">
          <div className="field"><label>IP</label><input value={ip} onChange={(e) => setIp(e.target.value)} placeholder="1.2.3.4 or 10.0.0.0/8" /></div>
          <div className="field"><label>Reason</label><input value={reason} onChange={(e) => setReason(e.target.value)} /></div>
        </div>
        <button type="button" className="btn btn-primary mt-4" onClick={() => void block()}>Block</button>
      </div>
      <div className="admin-split">
        <div className="admin-panel glass">
          <h2>Blocked IPs</h2>
          <table className="admin-table">
            <thead><tr><th>IP</th><th>Reason</th><th></th></tr></thead>
            <tbody>
              {(data?.blockedIps ?? []).map((r) => (
                <tr key={r.ip}>
                  <td><code>{r.ip}</code></td>
                  <td>{r.reason ?? '—'}</td>
                  <td><button type="button" className="btn btn-ghost btn-sm" onClick={() => void unblock(r.ip)}>Remove</button></td>
                </tr>
              ))}
              {!data?.blockedIps?.length && <tr><td colSpan={3} className="muted">None</td></tr>}
            </tbody>
          </table>
        </div>
        <div className="admin-panel glass">
          <h2>Failed logins</h2>
          <table className="admin-table">
            <thead><tr><th>When</th><th>Email</th><th>IP</th></tr></thead>
            <tbody>
              {(data?.failedLogins ?? []).map((r) => (
                <tr key={r.id}>
                  <td>{new Date(r.created_at).toLocaleString()}</td>
                  <td>{r.email ?? '—'}</td>
                  <td>{r.ip ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <h2 className="mt-4">Events</h2>
          <ul className="admin-list">
            {(data?.securityEvents ?? []).map((e) => (
              <li key={e.id}><b>{e.event}</b> · {e.severity} · {new Date(e.created_at).toLocaleString()}</li>
            ))}
            {!data?.securityEvents?.length && <li className="muted">No events</li>}
          </ul>
        </div>
      </div>
    </div>
  );
}
