'use client';

import { useCallback, useEffect, useState } from 'react';
import { AdminPageHeader } from '@/components/admin/AdminPage';
import { useUI } from '@/components/GlobalUI';
import { adminFetch } from '@/lib/admin-client';

type Promo = {
  code: string;
  discount_pct: number | null;
  credit_bonus: number | null;
  max_redemptions: number | null;
  redemptions: number;
  expires_at: string | null;
  is_active: boolean;
};

export default function AdminPromoPage() {
  const { toast } = useUI();
  const [codes, setCodes] = useState<Promo[]>([]);
  const [ready, setReady] = useState(true);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ code: '', discount_pct: '', credit_bonus: '', max_redemptions: '' });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await adminFetch<{ codes: Promo[]; ready: boolean; error?: string }>('/api/admin/promo');
      setCodes(data.codes);
      setReady(data.ready);
      if (!data.ready && data.error) toast(data.error, 'error');
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
      await adminFetch('/api/admin/promo', {
        method: 'POST',
        body: JSON.stringify({
          code: form.code,
          discount_pct: form.discount_pct ? Number(form.discount_pct) : undefined,
          credit_bonus: form.credit_bonus ? Number(form.credit_bonus) : undefined,
          max_redemptions: form.max_redemptions ? Number(form.max_redemptions) : undefined,
        }),
      });
      toast('Saved', 'success');
      setForm({ code: '', discount_pct: '', credit_bonus: '', max_redemptions: '' });
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    }
  };

  const toggle = async (code: string, is_active: boolean) => {
    try {
      await adminFetch('/api/admin/promo', { method: 'PATCH', body: JSON.stringify({ code, is_active }) });
      void load();
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Failed', 'error');
    }
  };

  return (
    <div>
      <AdminPageHeader title="Promo & Coupons" subtitle="Discount codes and credit bonuses" />
      {!ready && (
        <div className="admin-panel glass mb-4">
          <p className="muted">Run <code>09_architecture_v3_foundation.sql</code> for promo_codes.</p>
        </div>
      )}
      <div className="admin-panel glass mb-4">
        <h2>Create / update</h2>
        <div className="admin-form-grid">
          <div className="field"><label>Code</label><input value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} placeholder="WELCOME25" /></div>
          <div className="field"><label>Discount %</label><input value={form.discount_pct} onChange={(e) => setForm({ ...form, discount_pct: e.target.value })} placeholder="25" /></div>
          <div className="field"><label>Credit bonus</label><input value={form.credit_bonus} onChange={(e) => setForm({ ...form, credit_bonus: e.target.value })} placeholder="50" /></div>
          <div className="field"><label>Max redemptions</label><input value={form.max_redemptions} onChange={(e) => setForm({ ...form, max_redemptions: e.target.value })} /></div>
        </div>
        <button type="button" className="btn btn-primary mt-4" onClick={() => void save()}>Save code</button>
      </div>
      <div className="admin-panel glass">
        {loading ? <div className="spinner" style={{ margin: 40 }} /> : (
          <table className="admin-table">
            <thead><tr><th>Code</th><th>% / Credits</th><th>Used</th><th>Active</th><th></th></tr></thead>
            <tbody>
              {codes.map((c) => (
                <tr key={c.code}>
                  <td><b>{c.code}</b></td>
                  <td>{c.discount_pct ?? '—'}% / {c.credit_bonus ?? '—'} cr</td>
                  <td>{c.redemptions}{c.max_redemptions != null ? ` / ${c.max_redemptions}` : ''}</td>
                  <td>{c.is_active ? 'Yes' : 'No'}</td>
                  <td>
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => void toggle(c.code, !c.is_active)}>
                      {c.is_active ? 'Disable' : 'Enable'}
                    </button>
                  </td>
                </tr>
              ))}
              {!codes.length && <tr><td colSpan={5} className="muted">No promo codes</td></tr>}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
