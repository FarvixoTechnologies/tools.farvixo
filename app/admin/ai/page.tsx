'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { useUI } from '@/components/GlobalUI';
import { useAdminPermissions } from '@/components/admin/PermissionsProvider';
import { adminFetch } from '@/lib/admin-client';
import { createClient } from '@/lib/supabase/client';
import Icon from '@/components/Icon';

type Tab = 'overview' | 'models' | 'providers' | 'keys' | 'templates' | 'quotas' | 'logs';
type Toast = (m: string, k?: 'info' | 'success' | 'error') => void;

const TABS: { key: Tab; label: string; icon: string }[] = [
  { key: 'overview', label: 'Overview', icon: 'zap' },
  { key: 'models', label: 'Models', icon: 'sparkles' },
  { key: 'providers', label: 'Providers', icon: 'grid' },
  { key: 'keys', label: 'API Keys', icon: 'key' },
  { key: 'templates', label: 'Prompts', icon: 'file-text' },
  { key: 'quotas', label: 'Quotas', icon: 'shield' },
  { key: 'logs', label: 'Logs', icon: 'database' },
];

export default function AdminAiPage() {
  const { toast } = useUI();
  const { can } = useAdminPermissions();
  const [tab, setTab] = useState<Tab>('overview');
  const manage = can('ai.manage');

  return (
    <div>
      <AdminPageHeader title="AI Management" subtitle="Models, providers, keys, prompts, quotas & usage" />
      <div className="admin-seg mb-4" role="tablist">
        {TABS.map((t) => (
          <button key={t.key} type="button" role="tab" aria-selected={tab === t.key}
            className={`admin-seg-btn ${tab === t.key ? 'active' : ''}`} onClick={() => setTab(t.key)}>
            <Icon name={t.icon} size={13} /> {t.label}
          </button>
        ))}
      </div>
      {tab === 'overview' && <Overview toast={toast} />}
      {tab === 'models' && <Models toast={toast} manage={manage} />}
      {tab === 'providers' && <Providers toast={toast} manage={manage} />}
      {tab === 'keys' && <Keys toast={toast} manage={manage} />}
      {tab === 'templates' && <Templates toast={toast} manage={manage} />}
      {tab === 'quotas' && <Quotas toast={toast} manage={manage} />}
      {tab === 'logs' && <Logs toast={toast} />}
    </div>
  );
}

/* ─────────── Overview (realtime) ─────────── */
type OverviewData = {
  kpis: { day: { requests: number; tokens: number; cost: number; avg_latency: number; success: number; errors: number; successRate: number }; month: { requests: number; tokens: number; cost: number } };
  providers: { id: string; display_name: string; is_active: boolean }[];
  models: { id: string; is_active: boolean }[];
  recentUsage: { id: string; model_id: string | null; total_tokens: number; cost: number; latency_ms: number | null; status: string; created_at: string }[];
  recentLogs: { id: string; kind: string; level: string; message: string | null; model_id: string | null; created_at: string }[];
  byModel: { model_id: string; calls: number; tokens: number; cost: number; errors: number }[];
};

function Overview({ toast }: { toast: Toast }) {
  const [d, setD] = useState<OverviewData | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try { setD(await adminFetch<OverviewData>('/api/admin/ai')); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    finally { setLoading(false); }
  }, [toast]);
  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    const s = createClient();
    if (!s) return;
    const ch = s.channel('ai-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'ai_usage' }, () => void load())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'ai_logs' }, () => void load())
      .subscribe();
    return () => { void s.removeChannel(ch); };
  }, [load]);

  if (loading) return <div className="spinner" style={{ margin: 60 }} />;
  if (!d) return null;
  const k = d.kpis.day;
  const cards = [
    { label: 'Requests (24h)', value: k.requests.toLocaleString() },
    { label: 'Tokens (24h)', value: k.tokens.toLocaleString() },
    { label: 'Cost (24h)', value: `$${Number(k.cost).toFixed(4)}` },
    { label: 'Avg latency', value: `${k.avg_latency} ms` },
    { label: 'Success rate', value: `${k.successRate}%` },
    { label: 'Errors (24h)', value: k.errors.toLocaleString() },
    { label: 'Active models', value: `${d.models.filter((m) => m.is_active).length}/${d.models.length}` },
    { label: 'Cost (30d)', value: `$${Number(d.kpis.month.cost).toFixed(2)}` },
  ];

  return (
    <>
      <div className="admin-stats-grid mb-4">
        {cards.map((c) => (
          <div key={c.label} className="admin-stat-card glass"><span className="muted">{c.label}</span><b>{c.value}</b></div>
        ))}
      </div>
      <div className="admin-split">
        <div className="admin-panel glass">
          <h2>Top models</h2>
          <div className="admin-table-scroll">
            <table className="admin-table admin-table-cards">
              <thead><tr><th>Model</th><th>Calls</th><th>Tokens</th><th>Cost</th><th>Err</th></tr></thead>
              <tbody>
                {d.byModel.map((m) => (
                  <tr key={m.model_id}>
                    <td data-label="Model">{m.model_id}</td>
                    <td data-label="Calls">{m.calls}</td>
                    <td data-label="Tokens">{m.tokens.toLocaleString()}</td>
                    <td data-label="Cost">${m.cost.toFixed(4)}</td>
                    <td data-label="Err">{m.errors}</td>
                  </tr>
                ))}
                {!d.byModel.length && <tr><td colSpan={5} className="muted">No usage yet</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
        <div className="admin-panel glass">
          <h2>Recent activity</h2>
          <div className="admin-table-scroll">
            <table className="admin-table admin-table-cards">
              <thead><tr><th>When</th><th>Model</th><th>Tokens</th><th>Status</th></tr></thead>
              <tbody>
                {d.recentUsage.map((u) => (
                  <tr key={u.id}>
                    <td data-label="When" className="muted">{new Date(u.created_at).toLocaleTimeString()}</td>
                    <td data-label="Model">{u.model_id ?? '—'}</td>
                    <td data-label="Tokens">{u.total_tokens}</td>
                    <td data-label="Status"><span className={`status-pill ${u.status === 'error' ? 'status-failed' : 'status-completed'}`}>{u.status}</span></td>
                  </tr>
                ))}
                {!d.recentUsage.length && <tr><td colSpan={4} className="muted">No requests yet</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </>
  );
}

/* ─────────── Providers ─────────── */
function Providers({ toast, manage }: { toast: Toast; manage: boolean }) {
  const [rows, setRows] = useState<{ id: string; display_name: string; is_active: boolean; base_url: string | null; docs_url: string | null }[]>([]);
  const [loading, setLoading] = useState(true);
  const load = useCallback(async () => {
    try { setRows((await adminFetch<{ providers: typeof rows }>('/api/admin/ai/providers')).providers); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } finally { setLoading(false); }
  }, [toast]);
  useEffect(() => { void load(); }, [load]);
  const toggle = async (id: string, is_active: boolean) => {
    try { await adminFetch('/api/admin/ai/providers', { method: 'PATCH', body: JSON.stringify({ id, is_active }) }); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  if (loading) return <div className="spinner" style={{ margin: 40 }} />;
  return (
    <div className="admin-panel glass">
      <h2>Providers</h2>
      <div className="admin-table-scroll">
        <table className="admin-table admin-table-cards">
          <thead><tr><th>Provider</th><th>Endpoint</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {rows.map((p) => (
              <tr key={p.id}>
                <td data-label="Provider"><b>{p.display_name}</b><div className="mono muted" style={{ fontSize: 10 }}>{p.id}</div></td>
                <td data-label="Endpoint" className="mono muted" style={{ fontSize: 11 }}>{p.base_url}</td>
                <td data-label="Status"><span className={`status-pill ${p.is_active ? 'status-completed' : 'status-failed'}`}>{p.is_active ? 'Active' : 'Off'}</span></td>
                <td data-label="Actions">{manage && <button type="button" className="btn btn-ghost btn-sm" onClick={() => void toggle(p.id, !p.is_active)}>{p.is_active ? 'Disable' : 'Enable'}</button>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

/* ─────────── Models ─────────── */
type Model = { id: string; provider_id: string; display_name: string; category: string; is_active: boolean; priority: number; input_cost_per_1k: number; output_cost_per_1k: number; context_window: number | null };
function Models({ toast, manage }: { toast: Toast; manage: boolean }) {
  const [rows, setRows] = useState<Model[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [provider, setProvider] = useState('');
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ id: '', provider_id: 'gemini', display_name: '', category: 'chat', priority: 100, input_cost_per_1k: 0, output_cost_per_1k: 0 });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const p = new URLSearchParams(); if (q) p.set('q', q); if (provider) p.set('provider', provider);
      setRows((await adminFetch<{ models: Model[] }>(`/api/admin/ai/models?${p}`)).models);
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } finally { setLoading(false); }
  }, [q, provider, toast]);
  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    const s = createClient(); if (!s) return;
    const ch = s.channel('ai-models').on('postgres_changes', { event: '*', schema: 'public', table: 'ai_models' }, () => void load()).subscribe();
    return () => { void s.removeChannel(ch); };
  }, [load]);

  const patch = async (body: Record<string, unknown>) => {
    try { await adminFetch('/api/admin/ai/models', { method: 'PATCH', body: JSON.stringify(body) }); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const create = async () => {
    try { await adminFetch('/api/admin/ai/models', { method: 'POST', body: JSON.stringify(form) }); toast('Model added', 'success'); setCreating(false); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const del = async (id: string) => {
    if (!window.confirm(`Delete model ${id}?`)) return;
    try { await adminFetch(`/api/admin/ai/models?id=${encodeURIComponent(id)}`, { method: 'DELETE' }); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };

  return (
    <div className="admin-panel glass">
      <div className="admin-panel-head">
        <h2>Models</h2>
        {manage && <button type="button" className="btn btn-primary btn-sm" onClick={() => setCreating((v) => !v)}><Icon name="pen" size={13} /> Add model</button>}
      </div>
      {creating && manage && (
        <div className="admin-panel" style={{ background: 'var(--bg-surface-2)', marginBottom: 12 }}>
          <div className="admin-toolbar" style={{ padding: 0, background: 'none', flexWrap: 'wrap' }}>
            <input className="admin-input" placeholder="model-id" value={form.id} onChange={(e) => setForm({ ...form, id: e.target.value })} />
            <input className="admin-input" placeholder="Display name" value={form.display_name} onChange={(e) => setForm({ ...form, display_name: e.target.value })} />
            <select className="admin-select" value={form.provider_id} onChange={(e) => setForm({ ...form, provider_id: e.target.value })}>
              {['gemini', 'openai', 'anthropic', 'groq', 'openrouter', 'ollama'].map((p) => <option key={p} value={p}>{p}</option>)}
            </select>
            <select className="admin-select" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
              {['chat', 'image', 'embedding', 'audio'].map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
            <input className="admin-input" type="number" placeholder="priority" value={form.priority} onChange={(e) => setForm({ ...form, priority: Number(e.target.value) })} style={{ minWidth: 90 }} />
            <button type="button" className="btn btn-primary btn-sm" onClick={() => void create()}>Create</button>
          </div>
        </div>
      )}
      <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginBottom: 12 }}>
        <input className="admin-input" placeholder="Search models…" value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="admin-select" value={provider} onChange={(e) => setProvider(e.target.value)}>
          <option value="">All providers</option>
          {['gemini', 'openai', 'anthropic', 'groq', 'openrouter', 'ollama'].map((p) => <option key={p} value={p}>{p}</option>)}
        </select>
      </div>
      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>Model</th><th>Provider</th><th>Cat</th><th>Priority</th><th>Cost /1k (in/out)</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {rows.map((m) => (
                <tr key={m.id}>
                  <td data-label="Model"><b>{m.display_name}</b><div className="mono muted" style={{ fontSize: 10 }}>{m.id}</div></td>
                  <td data-label="Provider">{m.provider_id}</td>
                  <td data-label="Cat">{m.category}</td>
                  <td data-label="Priority">{manage ? <input type="number" className="admin-input" style={{ minWidth: 70, padding: '4px 8px' }} defaultValue={m.priority} onBlur={(e) => { const v = Number(e.target.value); if (v !== m.priority) void patch({ id: m.id, priority: v }); }} /> : m.priority}</td>
                  <td data-label="Cost">${m.input_cost_per_1k} / ${m.output_cost_per_1k}</td>
                  <td data-label="Status"><span className={`status-pill ${m.is_active ? 'status-completed' : 'status-failed'}`}>{m.is_active ? 'On' : 'Off'}</span></td>
                  <td data-label="Actions">
                    {manage && (
                      <div className="admin-inline-actions">
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => void patch({ id: m.id, is_active: !m.is_active })}>{m.is_active ? 'Disable' : 'Enable'}</button>
                        <button type="button" className="btn btn-ghost btn-sm admin-actions-danger" onClick={() => void del(m.id)}><Icon name="ban" size={13} /></button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={7} className="muted">No models</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

/* ─────────── API Keys ─────────── */
type KeyRow = { id: string; provider_id: string; label: string; key_masked: string; status: string; validation_ok: boolean | null; last_validated_at: string | null; created_at: string };
function Keys({ toast, manage }: { toast: Toast; manage: boolean }) {
  const [rows, setRows] = useState<KeyRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ provider_id: 'gemini', label: '', key: '' });

  const load = useCallback(async () => {
    try { setRows((await adminFetch<{ keys: KeyRow[] }>('/api/admin/ai/keys')).keys); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } finally { setLoading(false); }
  }, [toast]);
  useEffect(() => { void load(); }, [load]);

  const add = async () => {
    if (!form.key.trim()) return toast('Enter a key', 'error');
    try { const d = await adminFetch<{ validation: boolean | null }>('/api/admin/ai/keys', { method: 'POST', body: JSON.stringify({ ...form, validate: true }) }); toast(d.validation === false ? 'Added, but validation failed' : 'Key added', d.validation === false ? 'error' : 'success'); setForm({ ...form, label: '', key: '' }); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const act = async (id: string, action: string, key?: string) => {
    try { await adminFetch('/api/admin/ai/keys', { method: 'PATCH', body: JSON.stringify({ id, action, key }) }); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const del = async (id: string) => { if (!window.confirm('Delete this key?')) return; try { await adminFetch(`/api/admin/ai/keys?id=${id}`, { method: 'DELETE' }); void load(); } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } };

  return (
    <div className="admin-panel glass">
      <h2>API Keys</h2>
      <p className="muted mb-4" style={{ fontSize: 12 }}>Keys are stored server-side and never returned to the browser — only a masked preview is shown.</p>
      {manage && (
        <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginBottom: 12, flexWrap: 'wrap' }}>
          <select className="admin-select" value={form.provider_id} onChange={(e) => setForm({ ...form, provider_id: e.target.value })}>
            {['gemini', 'openai', 'anthropic', 'groq', 'openrouter', 'ollama'].map((p) => <option key={p} value={p}>{p}</option>)}
          </select>
          <input className="admin-input" placeholder="Label" value={form.label} onChange={(e) => setForm({ ...form, label: e.target.value })} />
          <input className="admin-input" type="password" placeholder="Paste key…" value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} style={{ minWidth: 220 }} />
          <button type="button" className="btn btn-primary btn-sm" onClick={() => void add()}>Add & validate</button>
        </div>
      )}
      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>Provider</th><th>Label</th><th>Key</th><th>Valid</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {rows.map((k) => (
                <tr key={k.id}>
                  <td data-label="Provider">{k.provider_id}</td>
                  <td data-label="Label">{k.label}</td>
                  <td data-label="Key" className="mono">{k.key_masked}</td>
                  <td data-label="Valid">{k.validation_ok === null ? <span className="muted">—</span> : <span className={`status-pill ${k.validation_ok ? 'status-completed' : 'status-failed'}`}>{k.validation_ok ? 'OK' : 'Fail'}</span>}</td>
                  <td data-label="Status"><span className={`status-pill ${k.status === 'active' ? 'status-completed' : 'status-failed'}`}>{k.status}</span></td>
                  <td data-label="Actions">
                    {manage && (
                      <div className="admin-inline-actions">
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => void act(k.id, 'validate')}>Validate</button>
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => { const nk = window.prompt('New key for rotation:'); if (nk) void act(k.id, 'rotate', nk); }}>Rotate</button>
                        <button type="button" className="btn btn-ghost btn-sm admin-actions-danger" onClick={() => void del(k.id)}><Icon name="ban" size={13} /></button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={6} className="muted">No keys stored</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

/* ─────────── Templates ─────────── */
type Tpl = { id: string; key: string; name: string; category: string; is_active: boolean; current_version: number };
function Templates({ toast, manage }: { toast: Toast; manage: boolean }) {
  const [rows, setRows] = useState<Tpl[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ key: '', name: '', category: 'General', content: '' });

  const load = useCallback(async () => {
    setLoading(true);
    try { const p = new URLSearchParams(); if (q) p.set('q', q); setRows((await adminFetch<{ templates: Tpl[] }>(`/api/admin/ai/templates?${p}`)).templates); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } finally { setLoading(false); }
  }, [q, toast]);
  useEffect(() => { void load(); }, [load]);

  const create = async () => {
    try { await adminFetch('/api/admin/ai/templates', { method: 'POST', body: JSON.stringify(form) }); toast('Template created', 'success'); setCreating(false); setForm({ key: '', name: '', category: 'General', content: '' }); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const newVersion = async (id: string) => { const c = window.prompt('New version content:'); if (!c) return; try { await adminFetch('/api/admin/ai/templates', { method: 'PATCH', body: JSON.stringify({ id, action: 'new_version', content: c }) }); toast('New version saved', 'success'); void load(); } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } };
  const del = async (id: string) => { if (!window.confirm('Delete template?')) return; try { await adminFetch(`/api/admin/ai/templates?id=${id}`, { method: 'DELETE' }); void load(); } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } };

  return (
    <div className="admin-panel glass">
      <div className="admin-panel-head">
        <h2>Prompt Templates</h2>
        {manage && <button type="button" className="btn btn-primary btn-sm" onClick={() => setCreating((v) => !v)}><Icon name="pen" size={13} /> New template</button>}
      </div>
      {creating && manage && (
        <div className="admin-panel" style={{ background: 'var(--bg-surface-2)', marginBottom: 12 }}>
          <div className="admin-toolbar" style={{ padding: 0, background: 'none', flexWrap: 'wrap', marginBottom: 8 }}>
            <input className="admin-input" placeholder="key" value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value })} />
            <input className="admin-input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            <input className="admin-input" placeholder="Category" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
          </div>
          <textarea className="admin-input" style={{ width: '100%', minHeight: 90 }} placeholder="Prompt content…" value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} />
          <button type="button" className="btn btn-primary btn-sm mt-2" onClick={() => void create()}>Create v1</button>
        </div>
      )}
      <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginBottom: 12 }}>
        <input className="admin-input" placeholder="Search templates…" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>Template</th><th>Category</th><th>Version</th><th>Status</th><th></th></tr></thead>
            <tbody>
              {rows.map((t) => (
                <tr key={t.id}>
                  <td data-label="Template"><b>{t.name}</b><div className="mono muted" style={{ fontSize: 10 }}>{t.key}</div></td>
                  <td data-label="Category">{t.category}</td>
                  <td data-label="Version">v{t.current_version}</td>
                  <td data-label="Status"><span className={`status-pill ${t.is_active ? 'status-completed' : 'status-failed'}`}>{t.is_active ? 'Active' : 'Off'}</span></td>
                  <td data-label="Actions">{manage && (
                    <div className="admin-inline-actions">
                      <button type="button" className="btn btn-ghost btn-sm" onClick={() => void newVersion(t.id)}>+ Version</button>
                      <button type="button" className="btn btn-ghost btn-sm admin-actions-danger" onClick={() => void del(t.id)}><Icon name="ban" size={13} /></button>
                    </div>
                  )}</td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={5} className="muted">No templates</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

/* ─────────── Quotas ─────────── */
type Quota = { id: string; scope: string; scope_key: string; daily_limit: number | null; monthly_limit: number | null };
function Quotas({ toast, manage }: { toast: Toast; manage: boolean }) {
  const [rows, setRows] = useState<Quota[]>([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ scope: 'plan', scope_key: '', daily_limit: '', monthly_limit: '' });

  const load = useCallback(async () => {
    try { setRows((await adminFetch<{ quotas: Quota[] }>('/api/admin/ai/quotas')).quotas); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } finally { setLoading(false); }
  }, [toast]);
  useEffect(() => { void load(); }, [load]);

  const save = async (scope: string, scope_key: string, daily: string, monthly: string) => {
    try {
      await adminFetch('/api/admin/ai/quotas', { method: 'PUT', body: JSON.stringify({
        scope, scope_key,
        daily_limit: daily === '' ? null : Number(daily),
        monthly_limit: monthly === '' ? null : Number(monthly),
      }) });
      toast('Quota saved', 'success'); void load();
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };

  if (loading) return <div className="spinner" style={{ margin: 40 }} />;
  return (
    <div className="admin-panel glass">
      <h2>Quotas</h2>
      <p className="muted mb-4" style={{ fontSize: 12 }}>Per-plan or per-user request limits. Blank = unlimited.</p>
      <div className="admin-table-scroll">
        <table className="admin-table admin-table-cards">
          <thead><tr><th>Scope</th><th>Key</th><th>Daily</th><th>Monthly</th><th></th></tr></thead>
          <tbody>
            {rows.map((qrow) => (
              <QuotaRow key={qrow.id} q={qrow} manage={manage} onSave={save} />
            ))}
          </tbody>
        </table>
      </div>
      {manage && (
        <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginTop: 16, flexWrap: 'wrap' }}>
          <select className="admin-select" value={form.scope} onChange={(e) => setForm({ ...form, scope: e.target.value })}>
            <option value="plan">plan</option><option value="user">user</option>
          </select>
          <input className="admin-input" placeholder={form.scope === 'plan' ? 'FREE / PRO / …' : 'user uuid'} value={form.scope_key} onChange={(e) => setForm({ ...form, scope_key: e.target.value })} />
          <input className="admin-input" type="number" placeholder="daily" value={form.daily_limit} onChange={(e) => setForm({ ...form, daily_limit: e.target.value })} style={{ minWidth: 100 }} />
          <input className="admin-input" type="number" placeholder="monthly" value={form.monthly_limit} onChange={(e) => setForm({ ...form, monthly_limit: e.target.value })} style={{ minWidth: 100 }} />
          <button type="button" className="btn btn-primary btn-sm" onClick={() => { if (form.scope_key) void save(form.scope, form.scope_key, form.daily_limit, form.monthly_limit); }}>Add / update</button>
        </div>
      )}
    </div>
  );
}
function QuotaRow({ q, manage, onSave }: { q: Quota; manage: boolean; onSave: (s: string, k: string, d: string, m: string) => void }) {
  const [d, setD] = useState(q.daily_limit?.toString() ?? '');
  const [m, setM] = useState(q.monthly_limit?.toString() ?? '');
  return (
    <tr>
      <td data-label="Scope">{q.scope}</td>
      <td data-label="Key"><b>{q.scope_key}</b></td>
      <td data-label="Daily">{manage ? <input className="admin-input" style={{ minWidth: 80, padding: '4px 8px' }} value={d} onChange={(e) => setD(e.target.value)} /> : (q.daily_limit ?? '∞')}</td>
      <td data-label="Monthly">{manage ? <input className="admin-input" style={{ minWidth: 80, padding: '4px 8px' }} value={m} onChange={(e) => setM(e.target.value)} /> : (q.monthly_limit ?? '∞')}</td>
      <td data-label="Actions">{manage && <button type="button" className="btn btn-ghost btn-sm" onClick={() => onSave(q.scope, q.scope_key, d, m)}>Save</button>}</td>
    </tr>
  );
}

/* ─────────── Logs ─────────── */
type LogRow = { id: string; kind: string; level: string; message: string | null; model_id: string | null; created_at: string };
function Logs({ toast }: { toast: Toast }) {
  const [rows, setRows] = useState<LogRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [kind, setKind] = useState('');
  const [level, setLevel] = useState('');
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const p = new URLSearchParams({ page: String(page) });
      if (q) p.set('q', q); if (kind) p.set('kind', kind); if (level) p.set('level', level);
      const d = await adminFetch<{ logs: LogRow[]; pages: number }>(`/api/admin/ai/logs?${p}`);
      setRows(d.logs); setPages(d.pages);
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); } finally { setLoading(false); }
  }, [q, kind, level, page, toast]);
  useEffect(() => { void load(); }, [load]);

  return (
    <div className="admin-panel glass">
      <h2>AI Logs</h2>
      <div className="admin-toolbar" style={{ padding: 0, background: 'none', margin: '12px 0', flexWrap: 'wrap' }}>
        <input className="admin-input" placeholder="Search…" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} />
        <select className="admin-select" value={kind} onChange={(e) => { setKind(e.target.value); setPage(1); }}>
          <option value="">All kinds</option><option value="request">Request</option><option value="error">Error</option><option value="moderation">Moderation</option>
        </select>
        <select className="admin-select" value={level} onChange={(e) => { setLevel(e.target.value); setPage(1); }}>
          <option value="">All levels</option><option value="info">Info</option><option value="warn">Warn</option><option value="error">Error</option>
        </select>
      </div>
      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>When</th><th>Kind</th><th>Level</th><th>Model</th><th>Message</th></tr></thead>
            <tbody>
              {rows.map((l) => (
                <tr key={l.id}>
                  <td data-label="When" className="muted">{new Date(l.created_at).toLocaleString()}</td>
                  <td data-label="Kind">{l.kind}</td>
                  <td data-label="Level"><span className={`status-pill ${l.level === 'error' ? 'status-failed' : l.level === 'warn' ? 'status-suspended' : 'status-completed'}`}>{l.level}</span></td>
                  <td data-label="Model">{l.model_id ?? '—'}</td>
                  <td data-label="Message">{l.message ?? '—'}</td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={5} className="muted">No logs</td></tr>}
            </tbody>
          </table>
        </div>
      )}
      {pages > 1 && (
        <div className="admin-pager">
          <button type="button" className="btn btn-ghost btn-sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Prev</button>
          <span className="muted">Page {page} / {pages}</span>
          <button type="button" className="btn btn-ghost btn-sm" disabled={page >= pages} onClick={() => setPage(page + 1)}>Next</button>
        </div>
      )}
    </div>
  );
}
