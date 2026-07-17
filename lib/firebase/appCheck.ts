'use client';

import { type FirebaseApp } from 'firebase/app';
import {
  initializeAppCheck,
  ReCaptchaV3Provider,
  type AppCheck,
} from 'firebase/app-check';
import { firebaseRecaptchaSiteKey } from '@/lib/firebase/config';

let appCheck: AppCheck | null = null;
let activated = false;

/**
 * Activate App Check (reCAPTCHA v3) once, before other Firebase product calls.
 * Skips silently when site key is missing (local/dev without Console setup).
 */
export async function activateAppCheck(app: FirebaseApp): Promise<AppCheck | null> {
  if (typeof window === 'undefined') return null;
  if (activated) return appCheck;
  activated = true;

  const siteKey = firebaseRecaptchaSiteKey;
  if (!siteKey) {
    console.info('[firebase] App Check skipped — NEXT_PUBLIC_FIREBASE_RECAPTCHA_SITE_KEY not set');
    return null;
  }

  try {
    if (process.env.NODE_ENV !== 'production') {
      const g = globalThis as unknown as {
        FIREBASE_APPCHECK_DEBUG_TOKEN?: boolean | string;
      };
      g.FIREBASE_APPCHECK_DEBUG_TOKEN =
        process.env.NEXT_PUBLIC_FIREBASE_APPCHECK_DEBUG_TOKEN || true;
    }

    appCheck = initializeAppCheck(app, {
      provider: new ReCaptchaV3Provider(siteKey),
      isTokenAutoRefreshEnabled: true,
    });
    return appCheck;
  } catch (e) {
    console.warn('[firebase] App Check init failed:', e);
    return null;
  }
}

export function getAppCheck(): AppCheck | null {
  return appCheck;
}
