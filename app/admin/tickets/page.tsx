'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { useUI } from '@/components/GlobalUI';
import { adminFetch } from '@/lib/admin-client';

type Ticket = {
  id: string;
  user_id: string;
  subject: string;
  status: string;
  priority: string;
  created_at: string;
  updated_at: string;
};

export default function AdminTicketsPage() {
  const { toast } = useUI();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [loading, setLoading] = useState(true);
  const [ready, setReady] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page) });
      if (status) params.set('status', status);
      const data = await adminFetch<{ tickets: Ticket[]; pages: number; ready: boolean; error?: string }>(
        `/api/admin/tickets?${params}`,
      );
      setTickets(data.tickets);
      setPages(data.pages || 1);
      setReady(data.ready);
      setError(data.error ?? null);
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    } finally {
      setLoading(false);
    }
  }, [page, status, toast]);

  useEffect(() => {
    void load();
  }, [load]);

  const patch = async (id: string, body: { status?: string; priority?: string }) => {
    try {
      await adminFetch('/api/admin/tickets', { method: 'PATCH', body: JSON.stringify({ id, ...body }) });
      toast('Updated', 'success');
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    }
  };

  return (
    <div>
      <AdminPageHeader title="Support Tickets" subtitle="User support queue" />
      {!ready && (
        <div className="admin-panel glass mb-4">
          <p className="muted">Tickets table missing — run <code>09_architecture_v3_foundation.sql</code>. {error}</p>
        </div>
      )}
      <div className="admin-toolbar glass">
        <select className="admin-select" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
          <option value="">All</option>
          <option value="open">Open</option>
          <option value="pending">Pending</option>
          <option value="resolved">Resolved</option>
          <option value="closed">Closed</option>
        </select>
      </div>
      <div className="admin-panel glass">
        {loading ? <div className="spinner" style={{ margin: 40 }} /> : (
          <table className="admin-table">
            <thead>
              <tr><th>Subject</th><th>Status</th><th>Priority</th><th>Updated</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {tickets.map((t) => (
                <tr key={t.id}>
                  <td><b>{t.subject}</b><div className="muted" style={{ fontSize: 12 }}>{t.user_id.slice(0, 8)}…</div></td>
                  <td><span className={`status-pill status-${t.status}`}>{t.status}</span></td>
                  <td>{t.priority}</td>
                  <td>{new Date(t.updated_at).toLocaleString()}</td>
                  <td className="admin-actions-row">
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => void patch(t.id, { status: 'pending' })}>Pending</button>
                    <button type="button" className="btn btn-primary btn-sm" onClick={() => void patch(t.id, { status: 'resolved' })}>Resolve</button>
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => void patch(t.id, { status: 'closed' })}>Close</button>
                  </td>
                </tr>
              ))}
              {!tickets.length && <tr><td colSpan={5} className="muted">No tickets</td></tr>}
            </tbody>
          </table>
        )}
        {pages > 1 && (
          <div className="admin-actions-row mt-4">
            <button type="button" className="btn btn-ghost btn-sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Prev</button>
            <span className="muted">Page {page}/{pages}</span>
            <button type="button" className="btn btn-ghost btn-sm" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next</button>
          </div>
        )}
      </div>
    </div>
  );
}
