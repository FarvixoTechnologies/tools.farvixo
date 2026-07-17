'use client';

/**
 * Backward-compatible entry — prefer `@/lib/firebase` or specific modules.
 */
export { getFirebaseApp as getFirebaseAppAsync, ensureFirebaseReady } from '@/lib/firebase/app';
export { getFirebaseAnalytics } from '@/lib/firebase/analytics';
export { firebaseConfig, isFirebaseConfigured } from '@/lib/firebase/config';

import { getFirebaseAppSync } from '@/lib/firebase/app';

/** Sync accessor used by early bootstrap (returns null until ready). */
export function getFirebaseApp() {
  return getFirebaseAppSync();
}
