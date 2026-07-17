'use client';

import { type FirebaseApp, getApp, getApps, initializeApp } from 'firebase/app';
import { firebaseConfig, isFirebaseConfigured } from '@/lib/firebase/config';

let app: FirebaseApp | null = null;
let initPromise: Promise<FirebaseApp | null> | null = null;

/**
 * Single Firebase app instance for the whole SPA.
 * App Check must be activated via `ensureFirebaseReady()` before using other products.
 */
export function getFirebaseAppSync(): FirebaseApp | null {
  if (typeof window === 'undefined') return null;
  if (!isFirebaseConfigured()) return null;
  if (app) return app;
  if (getApps().length) {
    app = getApp();
    return app;
  }
  app = initializeApp(firebaseConfig);
  return app;
}

export async function getFirebaseApp(): Promise<FirebaseApp | null> {
  if (typeof window === 'undefined') return null;
  if (!isFirebaseConfigured()) return null;
  if (app) return app;
  if (initPromise) return initPromise;

  initPromise = (async () => {
    const instance = getFirebaseAppSync();
    if (!instance) return null;
    const { activateAppCheck } = await import('@/lib/firebase/appCheck');
    await activateAppCheck(instance);
    return instance;
  })();

  return initPromise;
}

/** Alias used by older imports. */
export async function ensureFirebaseReady(): Promise<FirebaseApp | null> {
  return getFirebaseApp();
}
