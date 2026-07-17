'use client';

import { type FirebasePerformance, getPerformance } from 'firebase/performance';
import { ensureFirebaseReady } from '@/lib/firebase/app';

let perf: FirebasePerformance | null = null;

/** Optional — only loads in production browsers that support Performance Monitoring. */
export async function getFirebasePerformance(): Promise<FirebasePerformance | null> {
  if (typeof window === 'undefined') return null;
  if (process.env.NODE_ENV !== 'production') return null;
  if (perf) return perf;
  const app = await ensureFirebaseReady();
  if (!app) return null;
  try {
    perf = getPerformance(app);
    return perf;
  } catch (e) {
    console.warn('[firebase] Performance init failed:', e);
    return null;
  }
}
