/**
 * Farvixo Tools — Firebase Production 2026 (Web)
 * Project: farvixo-production-2026
 *
 * Auth SoT = Supabase. Firebase = Analytics, App Check, RC, FCM, Firestore, Storage.
 * Client values must be NEXT_PUBLIC_* (browser-safe). Never put service-account secrets here.
 *
 * IMPORTANT (Cloudflare / OpenNext):
 * Next only inlines `process.env.NEXT_PUBLIC_*` when those vars exist at **build** time.
 * Live production bundle was observed with non-inlined `process.env.NEXT_PUBLIC_FIREBASE_*`
 * (empty in browser) → `isFirebaseConfigured()` false → Analytics never boots.
 * Public web config fallback below matches Firebase Console client keys (not secrets).
 */

const val = (v: string | undefined): string => (v || '').trim();

/** Public Firebase web config — safe to ship in client bundles. */
const PUBLIC_WEB_FALLBACK = {
  apiKey: 'AIzaSyCW6-ik0yBIkrHH2ScoZFEFD3u5qhUS5SU',
  authDomain: 'farvixo-production-2026.firebaseapp.com',
  projectId: 'farvixo-production-2026',
  storageBucket: 'farvixo-production-2026.firebasestorage.app',
  messagingSenderId: '282376161241',
  appId: '1:282376161241:web:d0bca9dcc89c299e1f7bc8',
  measurementId: 'G-VTGV5YE47C',
} as const;

function pick(envVal: string | undefined, fallback: string): string {
  const v = val(envVal);
  return v || fallback;
}

export const firebaseConfig = {
  apiKey: pick(process.env.NEXT_PUBLIC_FIREBASE_API_KEY, PUBLIC_WEB_FALLBACK.apiKey),
  authDomain: pick(process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN, PUBLIC_WEB_FALLBACK.authDomain),
  projectId: pick(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID, PUBLIC_WEB_FALLBACK.projectId),
  storageBucket: pick(process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET, PUBLIC_WEB_FALLBACK.storageBucket),
  messagingSenderId: pick(
    process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    PUBLIC_WEB_FALLBACK.messagingSenderId,
  ),
  appId: pick(process.env.NEXT_PUBLIC_FIREBASE_APP_ID, PUBLIC_WEB_FALLBACK.appId),
  measurementId: pick(process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID, PUBLIC_WEB_FALLBACK.measurementId),
} as const;

export const firebaseRecaptchaSiteKey = val(process.env.NEXT_PUBLIC_FIREBASE_RECAPTCHA_SITE_KEY);
export const firebaseVapidKey = val(process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY);

export function isFirebaseConfigured(): boolean {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.projectId &&
      firebaseConfig.appId &&
      firebaseConfig.messagingSenderId &&
      firebaseConfig.measurementId,
  );
}
