'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { useUI } from '@/components/GlobalUI';
import { useAuth } from '@/components/providers/AuthProvider';
import { adminFetch } from '@/lib/admin-client';
import { createClient } from '@/lib/supabase/client';
import { useAdminPermissions } from '@/components/admin/PermissionsProvider';
import Icon from '@/components/Icon';

type Tab = 'team' | 'roles' | 'matrix' | 'invites';

type TeamMember = { id: string; full_name: string | null; email: string; plan: string; role: string; created_at: string };
type Role = { key: string; name: string; description: string | null; is_system: boolean; inherits_from: string | null; permission_count: number; member_count: number };
type Perm = { key: string; resource: string; action: string; description: string | null; group_name: string };
type Invite = { id: string; email: string; role_key: string; status: string; expires_at: string; created_at: string; accepted_at: string | null };

const TABS: { key: Tab; label: string; icon: string }[] = [
  { key: 'team', label: 'Team', icon: 'users' },
  { key: 'roles', label: 'Roles', icon: 'shield' },
  { key: 'matrix', label: 'Permission Matrix', icon: 'grid' },
  { key: 'invites', label: 'Invitations', icon: 'mail' },
];

export default function AdminTeamPage() {
  const { toast } = useUI();
  const { user } = useAuth();
  const [tab, setTab] = useState<Tab>('team');

  return (
    <div>
      <AdminPageHeader title="Roles & Admins" subtitle="Enterprise RBAC — roles, permissions, team and invitations" />
      <div className="admin-seg mb-4" role="tablist">
        {TABS.map((t) => (
          <button key={t.key} type="button" role="tab" aria-selected={tab === t.key}
            className={`admin-seg-btn ${tab === t.key ? 'active' : ''}`} onClick={() => setTab(t.key)}>
            <Icon name={t.icon} size={13} /> {t.label}
          </button>
        ))}
      </div>

      {tab === 'team' && <TeamTab userId={user?.id} toast={toast} />}
      {tab === 'roles' && <RolesTab toast={toast} />}
      {tab === 'matrix' && <MatrixTab toast={toast} />}
      {tab === 'invites' && <InvitesTab toast={toast} />}
    </div>
  );
}

type Toast = (m: string, k?: 'info' | 'success' | 'error') => void;

/* ─────────── Team ─────────── */
function TeamTab({ userId, toast }: { userId?: string; toast: Toast }) {
  const [team, setTeam] = useState<TeamMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [promoteId, setPromoteId] = useState('');
  const [promoteRole, setPromoteRole] = useState('ADMIN');

  const load = useCallback(async () => {
    setLoading(true);
    try { setTeam((await adminFetch<{ team: TeamMember[] }>('/api/admin/team')).team); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    finally { setLoading(false); }
  }, [toast]);
  useEffect(() => { void load(); }, [load]);

  const promote = async () => {
    if (!promoteId.trim()) return toast('Enter user UUID', 'error');
    try {
      await adminFetch('/api/admin/team', { method: 'POST', body: JSON.stringify({ action: 'promote', user_id: promoteId.trim(), role: promoteRole }) });
      toast('Role updated', 'success'); setPromoteId(''); void load();
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };

  return (
    <>
      <div className="admin-panel glass mb-4">
        <h2>Team members</h2>
        {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
          <div className="admin-table-scroll">
            <table className="admin-table admin-table-cards">
              <thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Plan</th><th>Joined</th></tr></thead>
              <tbody>
                {team.map((m) => (
                  <tr key={m.id}>
                    <td data-label="Name"><b>{m.full_name || '—'}</b>{m.id === userId && <span className="pill pill-sm"> you</span>}</td>
                    <td data-label="Email">{m.email}</td>
                    <td data-label="Role"><span className="pill pill-admin">{m.role}</span></td>
                    <td data-label="Plan">{m.plan}</td>
                    <td data-label="Joined" className="muted">{new Date(m.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
                {!team.length && <tr><td colSpan={5} className="muted">No admins yet</td></tr>}
              </tbody>
            </table>
          </div>
        )}
      </div>
      <div className="admin-panel glass">
        <h2>Assign role to existing user</h2>
        <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginTop: 12 }}>
          <input className="admin-input" placeholder="User UUID…" value={promoteId} onChange={(e) => setPromoteId(e.target.value)} />
          <select className="admin-select" value={promoteRole} onChange={(e) => setPromoteRole(e.target.value)}>
            <option value="ADMIN">ADMIN</option>
            <option value="SUPER_ADMIN">SUPER_ADMIN</option>
            <option value="USER">USER (demote)</option>
          </select>
          <button type="button" className="btn btn-primary btn-sm" onClick={() => void promote()}>Apply</button>
        </div>
      </div>
    </>
  );
}

/* ─────────── Roles ─────────── */
function RolesTab({ toast }: { toast: Toast }) {
  const { can } = useAdminPermissions();
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState('');
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ key: '', name: '', description: '', inherits_from: '' });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const p = new URLSearchParams({ page: String(page) });
      if (q) p.set('q', q);
      if (filter) p.set('system', filter);
      const d = await adminFetch<{ roles: Role[]; pages: number }>(`/api/admin/roles?${p}`);
      setRoles(d.roles); setPages(d.pages);
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    finally { setLoading(false); }
  }, [q, filter, page, toast]);
  useEffect(() => { void load(); }, [load]);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) return;
    const ch = supabase.channel('rbac-roles')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'roles' }, () => void load())
      .subscribe();
    return () => { void supabase.removeChannel(ch); };
  }, [load]);

  const create = async () => {
    try {
      await adminFetch('/api/admin/roles', { method: 'POST', body: JSON.stringify(form) });
      toast('Role created', 'success'); setCreating(false); setForm({ key: '', name: '', description: '', inherits_from: '' }); void load();
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const del = async (key: string) => {
    if (!window.confirm(`Delete role ${key}?`)) return;
    try { await adminFetch(`/api/admin/roles?key=${key}`, { method: 'DELETE' }); toast('Role deleted', 'success'); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };

  return (
    <div className="admin-panel glass">
      <div className="admin-panel-head">
        <h2>Roles</h2>
        {can('roles.write') && <button type="button" className="btn btn-primary btn-sm" onClick={() => setCreating((v) => !v)}><Icon name="pen" size={13} /> New role</button>}
      </div>

      {creating && (
        <div className="admin-panel" style={{ background: 'var(--bg-surface-2)', marginBottom: 12 }}>
          <div className="admin-toolbar" style={{ padding: 0, background: 'none', flexWrap: 'wrap' }}>
            <input className="admin-input" placeholder="KEY (e.g. EDITOR)" value={form.key} onChange={(e) => setForm({ ...form, key: e.target.value.toUpperCase() })} />
            <input className="admin-input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            <select className="admin-select" value={form.inherits_from} onChange={(e) => setForm({ ...form, inherits_from: e.target.value })}>
              <option value="">Inherits: none</option>
              {roles.map((r) => <option key={r.key} value={r.key}>Inherits {r.key}</option>)}
            </select>
            <input className="admin-input" placeholder="Description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
            <button type="button" className="btn btn-primary btn-sm" onClick={() => void create()}>Create</button>
          </div>
        </div>
      )}

      <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginBottom: 12 }}>
        <input className="admin-input" placeholder="Search roles…" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} />
        <select className="admin-select" value={filter} onChange={(e) => { setFilter(e.target.value); setPage(1); }}>
          <option value="">All roles</option>
          <option value="true">System</option>
          <option value="false">Custom</option>
        </select>
      </div>

      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>Role</th><th>Inherits</th><th>Permissions</th><th>Members</th><th>Type</th><th></th></tr></thead>
            <tbody>
              {roles.map((r) => (
                <tr key={r.key}>
                  <td data-label="Role"><b>{r.name}</b><div className="mono muted" style={{ fontSize: 10 }}>{r.key}</div></td>
                  <td data-label="Inherits">{r.inherits_from ? <span className="pill pill-sm">{r.inherits_from}</span> : <span className="muted">—</span>}</td>
                  <td data-label="Permissions">{r.permission_count}</td>
                  <td data-label="Members">{r.member_count}</td>
                  <td data-label="Type">{r.is_system ? <span className="pill pill-sm">System</span> : <span className="pill pill-sm pill-nav-new">Custom</span>}</td>
                  <td data-label="Actions">
                    {!r.is_system && can('roles.delete') && <button type="button" className="btn btn-ghost btn-sm admin-actions-danger" onClick={() => void del(r.key)}><Icon name="ban" size={13} /></button>}
                  </td>
                </tr>
              ))}
              {!roles.length && <tr><td colSpan={6} className="muted">No roles found</td></tr>}
            </tbody>
          </table>
        </div>
      )}
      <Pager page={page} pages={pages} setPage={setPage} />
    </div>
  );
}

/* ─────────── Permission Matrix ─────────── */
function MatrixTab({ toast }: { toast: Toast }) {
  const { can } = useAdminPermissions();
  const canEdit = can('roles.write');
  const [roles, setRoles] = useState<Role[]>([]);
  const [active, setActive] = useState('');
  const [groups, setGroups] = useState<Record<string, Perm[]>>({});
  const [direct, setDirect] = useState<Set<string>>(new Set());
  const [effective, setEffective] = useState<Set<string>>(new Set());
  const [isSystem, setIsSystem] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void (async () => {
      try {
        const [r, p] = await Promise.all([
          adminFetch<{ roles: Role[] }>('/api/admin/roles?page=1'),
          adminFetch<{ groups: Record<string, Perm[]> }>('/api/admin/permissions'),
        ]);
        setRoles(r.roles); setGroups(p.groups);
        if (r.roles[0]) setActive(r.roles[0].key);
      } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    })();
  }, [toast]);

  const loadRole = useCallback(async (key: string) => {
    if (!key) return;
    setLoading(true);
    try {
      const d = await adminFetch<{ role: { is_system: boolean }; direct: string[]; effective: string[] }>(`/api/admin/roles/${key}`);
      setDirect(new Set(d.direct)); setEffective(new Set(d.effective)); setIsSystem(d.role.is_system);
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    finally { setLoading(false); }
  }, [toast]);
  useEffect(() => { if (active) void loadRole(active); }, [active, loadRole]);

  const toggle = (key: string) => {
    setDirect((prev) => { const n = new Set(prev); if (n.has(key)) n.delete(key); else n.add(key); return n; });
  };
  const save = async () => {
    setSaving(true);
    try {
      await adminFetch(`/api/admin/roles/${active}`, { method: 'PUT', body: JSON.stringify({ permissions: [...direct] }) });
      toast('Permissions saved', 'success'); void loadRole(active);
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    finally { setSaving(false); }
  };

  const groupNames = useMemo(() => Object.keys(groups), [groups]);

  return (
    <div className="admin-panel glass">
      <div className="admin-panel-head">
        <h2>Permission Matrix</h2>
        <div className="admin-inline-actions">
          <select className="admin-select" value={active} onChange={(e) => setActive(e.target.value)}>
            {roles.map((r) => <option key={r.key} value={r.key}>{r.name} ({r.key})</option>)}
          </select>
          <button type="button" className="btn btn-primary btn-sm" onClick={() => void save()} disabled={saving || isSystem || !canEdit}>
            {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
      {isSystem && <p className="muted mb-4" style={{ fontSize: 12 }}><Icon name="shield" size={12} /> System role — permissions shown read-only. Create a custom role to edit.</p>}
      <p className="muted mb-4" style={{ fontSize: 12 }}>Checked = direct grant. <span style={{ color: 'var(--brand-primary-hover)' }}>Highlighted</span> = inherited from a parent role.</p>

      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="rbac-matrix">
          {groupNames.map((g) => (
            <div key={g} className="rbac-group">
              <div className="rbac-group-title">{g}</div>
              {groups[g].map((perm) => {
                const inherited = effective.has(perm.key) && !direct.has(perm.key);
                return (
                  <label key={perm.key} className={`rbac-perm ${inherited ? 'inherited' : ''}`}>
                    <input type="checkbox" checked={direct.has(perm.key)} disabled={isSystem || !canEdit} onChange={() => toggle(perm.key)} />
                    <span className="rbac-perm-text">
                      <b>{perm.description || perm.key}</b>
                      <span className="mono muted">{perm.key}</span>
                    </span>
                    {inherited && <span className="pill pill-sm">inherited</span>}
                  </label>
                );
              })}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ─────────── Invitations ─────────── */
function InvitesTab({ toast }: { toast: Toast }) {
  const { can } = useAdminPermissions();
  const canInvite = can('roles.invite');
  const [invites, setInvites] = useState<Invite[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('');
  const [email, setEmail] = useState('');
  const [roleKey, setRoleKey] = useState('ADMIN');
  const [link, setLink] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const p = new URLSearchParams();
      if (q) p.set('q', q); if (status) p.set('status', status);
      const d = await adminFetch<{ invitations: Invite[] }>(`/api/admin/invitations?${p}`);
      setInvites(d.invitations);
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
    finally { setLoading(false); }
  }, [q, status, toast]);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => { void adminFetch<{ roles: Role[] }>('/api/admin/roles?page=1').then((d) => setRoles(d.roles)).catch(() => {}); }, []);

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) return;
    const ch = supabase.channel('rbac-invites')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'admin_invitations' }, () => void load())
      .subscribe();
    return () => { void supabase.removeChannel(ch); };
  }, [load]);

  const invite = async () => {
    setLink('');
    try {
      const d = await adminFetch<{ invite_link: string | null }>('/api/admin/invitations', { method: 'POST', body: JSON.stringify({ email, role_key: roleKey }) });
      toast('Invitation sent', 'success'); setEmail('');
      if (d.invite_link) setLink(d.invite_link);
      void load();
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };
  const revoke = async (id: string) => {
    if (!window.confirm('Revoke this invitation?')) return;
    try { await adminFetch('/api/admin/invitations', { method: 'PATCH', body: JSON.stringify({ id, action: 'revoke' }) }); toast('Revoked', 'success'); void load(); }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', 'error'); }
  };

  const badge = (s: string) => s === 'pending' ? 'status-suspended' : s === 'accepted' ? 'status-completed' : 'status-failed';

  return (
    <div className="admin-panel glass">
      <div className="admin-panel-head"><h2>Admin invitations</h2></div>

      {canInvite && (
        <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginBottom: 12, flexWrap: 'wrap' }}>
          <input className="admin-input" type="email" placeholder="admin@company.com" value={email} onChange={(e) => setEmail(e.target.value)} />
          <select className="admin-select" value={roleKey} onChange={(e) => setRoleKey(e.target.value)}>
            {roles.filter((r) => r.key !== 'USER').map((r) => <option key={r.key} value={r.key}>{r.name}</option>)}
          </select>
          <button type="button" className="btn btn-primary btn-sm" onClick={() => void invite()}><Icon name="mail" size={13} /> Invite</button>
        </div>
      )}
      {link && (
        <div className="admin-alert mb-4" style={{ wordBreak: 'break-all' }}>
          Email delivery is off — share this invite link manually:<br /><code>{link}</code>
        </div>
      )}

      <div className="admin-toolbar" style={{ padding: 0, background: 'none', marginBottom: 12 }}>
        <input className="admin-input" placeholder="Search email…" value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="admin-select" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="accepted">Accepted</option>
          <option value="revoked">Revoked</option>
          <option value="expired">Expired</option>
        </select>
      </div>

      {loading ? <div className="spinner" style={{ margin: 30 }} /> : (
        <div className="admin-table-scroll">
          <table className="admin-table admin-table-cards">
            <thead><tr><th>Email</th><th>Role</th><th>Status</th><th>Expires</th><th></th></tr></thead>
            <tbody>
              {invites.map((i) => (
                <tr key={i.id}>
                  <td data-label="Email">{i.email}</td>
                  <td data-label="Role"><span className="pill pill-sm">{i.role_key}</span></td>
                  <td data-label="Status"><span className={`status-pill ${badge(i.status)}`}>{i.status}</span></td>
                  <td data-label="Expires" className="muted">{new Date(i.expires_at).toLocaleDateString()}</td>
                  <td data-label="Actions">
                    {i.status === 'pending' && canInvite && <button type="button" className="btn btn-ghost btn-sm admin-actions-danger" onClick={() => void revoke(i.id)}>Revoke</button>}
                  </td>
                </tr>
              ))}
              {!invites.length && <tr><td colSpan={5} className="muted">No invitations</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function Pager({ page, pages, setPage }: { page: number; pages: number; setPage: (n: number) => void }) {
  if (pages <= 1) return null;
  return (
    <div className="admin-pager">
      <button type="button" className="btn btn-ghost btn-sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Prev</button>
      <span className="muted">Page {page} / {pages}</span>
      <button type="button" className="btn btn-ghost btn-sm" disabled={page >= pages} onClick={() => setPage(page + 1)}>Next</button>
    </div>
  );
}
