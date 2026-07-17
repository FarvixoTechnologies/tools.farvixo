'use client';

import { useEffect, useRef } from 'react';
import { usePathname } from 'next/navigation';
import { isFirebaseConfigured } from '@/lib/firebase/config';
import { useAuth } from '@/components/providers/AuthProvider';

/**
 * Boots Firebase once: App Check → Analytics → Remote Config → FCM → Performance.
 * Lazy-imports modules for tree-shaking / smaller initial JS.
 */
export default function FirebaseProvider() {
  const pathname = usePathname();
  const { user } = useAuth();
  const booted = useRef(false);

  useEffect(() => {
    if (booted.current || !isFirebaseConfigured()) return;
    booted.current = true;

    void (async () => {
      const { ensureFirebaseReady } = await import('@/lib/firebase/app');
      const app = await ensureFirebaseReady();
      if (!app) return;

      const [{ trackSessionStart, setFirebaseUserId }, { initRemoteConfig }, perfMod] =
        await Promise.all([
          import('@/lib/firebase/analytics'),
          import('@/lib/firebase/remoteConfig'),
          import('@/lib/firebase/performance'),
        ]);

      await Promise.all([
        trackSessionStart(),
        initRemoteConfig(),
        perfMod.getFirebasePerformance(),
      ]);

      if (user?.id) {
        await setFirebaseUserId(user.id);
        const { registerFcmTokenWithSupabase } = await import('@/lib/firebase/messaging');
        void registerFcmTokenWithSupabase();
      }
    })().catch((e) => console.warn('[firebase] boot failed:', e));
  }, [user?.id]);

  useEffect(() => {
    if (!isFirebaseConfigured() || !pathname) return;
    void import('@/lib/firebase/analytics').then(({ trackPageView }) =>
      trackPageView(pathname),
    );
  }, [pathname]);

  useEffect(() => {
    if (!user?.id || !isFirebaseConfigured()) return;
    void import('@/lib/firebase/analytics').then(({ setFirebaseUserId }) =>
      setFirebaseUserId(user.id),
    );
    void import('@/lib/firebase/messaging').then(({ registerFcmTokenWithSupabase }) =>
      registerFcmTokenWithSupabase(),
    );
  }, [user?.id]);

  return null;
}
