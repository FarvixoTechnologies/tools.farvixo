'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { adminFetch } from '@/lib/admin-client';

type AiPayload = {
  ready: boolean;
  error: string | null;
  providers: { id: string; display_name: string; is_active: boolean }[];
  models: { id: string; provider_id: string; display_name: string; is_active: boolean }[];
  totals: { usageRows: number; feedback: number };
  recentUsage: {
    id: string;
    user_id: string | null;
    provider_id: string | null;
    model_id: string | null;
    prompt_tokens: number;
    completion_tokens: number;
    created_at: string;
  }[];
  byModel: { model_id: string; calls: number; tokens: number }[];
};

export default function AdminAiPage() {
  const [data, setData] = useState<AiPayload | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setData(await adminFetch<AiPayload>('/api/admin/ai'));
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
  if (!data) {
    return (
      <div>
        <AdminPageHeader title="AI Management" subtitle="Providers, models & usage" />
        <div className="admin-panel glass"><p className="muted">Failed to load AI stats.</p></div>
      </div>
    );
  }

  return (
    <div>
      <AdminPageHeader
        title="AI Management"
        subtitle="Providers, models, tokens & usage (from ai_* tables)"
        action={
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => void load()}>
            Refresh
          </button>
        }
      />

      {!data.ready && (
        <div className="admin-panel glass mb-4">
          <p className="muted">Run <code>09_architecture_v3_foundation.sql</code> to enable AI tables. {data.error}</p>
        </div>
      )}

      <div className="admin-kpi-row">
        <div className="admin-panel glass"><b>{data.totals.usageRows}</b><span className="muted">Usage rows</span></div>
        <div className="admin-panel glass"><b>{data.totals.feedback}</b><span className="muted">Feedback</span></div>
        <div className="admin-panel glass"><b>{data.providers.length}</b><span className="muted">Providers</span></div>
        <div className="admin-panel glass"><b>{data.models.length}</b><span className="muted">Models</span></div>
      </div>

      <div className="admin-split mt-4">
        <div className="admin-panel glass">
          <h2>Providers</h2>
          <ul className="admin-list">
            {data.providers.map((p) => (
              <li key={p.id}><b>{p.display_name}</b> <span className="muted">({p.id})</span> · {p.is_active ? 'ON' : 'OFF'}</li>
            ))}
            {!data.providers.length && <li className="muted">No providers seeded</li>}
          </ul>
          <h2 className="mt-4">Models</h2>
          <ul className="admin-list">
            {data.models.map((m) => (
              <li key={m.id}><b>{m.display_name}</b> <span className="muted">{m.provider_id}</span></li>
            ))}
          </ul>
        </div>
        <div className="admin-panel glass">
          <h2>By model</h2>
          <table className="admin-table">
            <thead><tr><th>Model</th><th>Calls</th><th>Tokens</th></tr></thead>
            <tbody>
              {data.byModel.map((r) => (
                <tr key={r.model_id}><td>{r.model_id}</td><td>{r.calls}</td><td>{r.tokens}</td></tr>
              ))}
              {!data.byModel.length && <tr><td colSpan={3} className="muted">No usage yet</td></tr>}
            </tbody>
          </table>
          <h2 className="mt-4">Recent usage</h2>
          <table className="admin-table">
            <thead><tr><th>When</th><th>Model</th><th>Tokens</th></tr></thead>
            <tbody>
              {data.recentUsage.map((r) => (
                <tr key={r.id}>
                  <td>{new Date(r.created_at).toLocaleString()}</td>
                  <td>{r.model_id}</td>
                  <td>{(r.prompt_tokens ?? 0) + (r.completion_tokens ?? 0)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
