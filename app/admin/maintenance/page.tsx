'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader, AdminToggleRow } from '@/components/admin/AdminPage';
import { useUI } from '@/components/GlobalUI';
import { adminFetch } from '@/lib/admin-client';

type Maint = {
  is_active: boolean;
  message: string | null;
  starts_at: string | null;
  ends_at: string | null;
};

export default function AdminMaintenancePage() {
  const { toast } = useUI();
  const [maint, setMaint] = useState<Maint>({ is_active: false, message: '', starts_at: null, ends_at: null });
  const [flags, setFlags] = useState<{ key: string; enabled: boolean; rollout_pct: number }[]>([]);
  const [loading, setLoading] = useState(true);
  const [ready, setReady] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminFetch<{
        ready: boolean;
        maintenance: Maint;
        featureFlags: { key: string; enabled: boolean; rollout_pct: number }[];
        error?: string | null;
      }>('/api/admin/maintenance');
      setReady(data.ready);
      setMaint({
        is_active: !!data.maintenance?.is_active,
        message: data.maintenance?.message ?? '',
        starts_at: data.maintenance?.starts_at ?? null,
        ends_at: data.maintenance?.ends_at ?? null,
      });
      setFlags(data.featureFlags ?? []);
      if (data.error) toast(data.error, 'error');
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    try {
      await adminFetch('/api/admin/maintenance', {
        method: 'PATCH',
        body: JSON.stringify(maint),
      });
      toast('Maintenance saved', 'success');
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    }
  };

  if (loading) return <div className="spinner" style={{ margin: 60 }} />;

  return (
    <div>
      <AdminPageHeader title="Maintenance & Remote Config" subtitle="Force downtime banner and DB feature flags" />
      {!ready && (
        <div className="admin-panel glass mb-4">
          <p className="muted">Run <code>09_architecture_v3_foundation.sql</code> for maintenance table.</p>
        </div>
      )}
      <div className="admin-panel glass mb-4">
        <AdminToggleRow
          label="Maintenance mode"
          description="Show site-wide maintenance state (DB source of truth)"
          checked={maint.is_active}
          onChange={(v) => setMaint((m) => ({ ...m, is_active: v }))}
        />
        <div className="field mt-4">
          <label>Message</label>
          <textarea
            rows={3}
            value={maint.message ?? ''}
            onChange={(e) => setMaint((m) => ({ ...m, message: e.target.value }))}
            placeholder="We will be back shortly…"
          />
        </div>
        <button type="button" className="btn btn-primary mt-4" onClick={() => void save()}>Save</button>
      </div>
      <div className="admin-panel glass">
        <h2>DB Feature flags</h2>
        <p className="muted mb-4">Also see /admin/features for app-settings flags.</p>
        <ul className="admin-list">
          {flags.map((f) => (
            <li key={f.key}><b>{f.key}</b> · {f.enabled ? 'ON' : 'OFF'} · {f.rollout_pct}%</li>
          ))}
          {!flags.length && <li className="muted">No rows in feature_flags yet</li>}
        </ul>
      </div>
    </div>
  );
}
