'use client';

import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { adminFetch } from '@/lib/admin-client';

type Ctx = {
  role: string;
  permissions: Set<string>;
  isSuperAdmin: boolean;
  loading: boolean;
  can: (perm: string) => boolean;
  canAny: (perms: string[]) => boolean;
};

const PermissionsContext = createContext<Ctx | null>(null);

export function AdminPermissionsProvider({ children }: { children: React.ReactNode }) {
  const [role, setRole] = useState('');
  const [permissions, setPermissions] = useState<Set<string>>(new Set());
  const [isSuperAdmin, setIsSuperAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const d = await adminFetch<{ role: string; permissions: string[]; isSuperAdmin: boolean }>('/api/admin/context');
        if (cancelled) return;
        setRole(d.role);
        setPermissions(new Set(d.permissions));
        setIsSuperAdmin(d.isSuperAdmin);
      } catch {
        /* not an admin / not signed in — leave empty */
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const value = useMemo<Ctx>(() => ({
    role,
    permissions,
    isSuperAdmin,
    loading,
    can: (perm) => isSuperAdmin || permissions.has(perm),
    canAny: (perms) => isSuperAdmin || perms.some((p) => permissions.has(p)),
  }), [role, permissions, isSuperAdmin, loading]);

  return <PermissionsContext.Provider value={value}>{children}</PermissionsContext.Provider>;
}

export function useAdminPermissions(): Ctx {
  const ctx = useContext(PermissionsContext);
  if (!ctx) {
    // Safe fallback outside the provider: deny everything (until loaded).
    return { role: '', permissions: new Set(), isSuperAdmin: false, loading: true, can: () => false, canAny: () => false };
  }
  return ctx;
}
