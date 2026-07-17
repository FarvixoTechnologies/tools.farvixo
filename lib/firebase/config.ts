/**
 * Farvixo Tools — Firebase Production 2026 (Web)
 * Project: farvixo-production-2026
 *
 * Auth SoT = Supabase. Firebase = Analytics, App Check, RC, FCM, Firestore, Storage.
 * Client values must be NEXT_PUBLIC_* (browser-safe). Never put service-account secrets here.
 *
 * IMPORTANT: env vars are referenced with STATIC `process.env.NEXT_PUBLIC_*`
 * property access. Next.js inlines NEXT_PUBLIC_* values into the client bundle
 * only for static references — dynamic `process.env[key]` lookups resolve to
 * undefined in the browser and silently disable Firebase.
 */

const val = (v: string | undefined): string => (v || '').trim();

export const firebaseConfig = {
  apiKey: val(process.env.NEXT_PUBLIC_FIREBASE_API_KEY),
  authDomain: val(process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN),
  projectId: val(process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID),
  storageBucket: val(process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET),
  messagingSenderId: val(process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID),
  appId: val(process.env.NEXT_PUBLIC_FIREBASE_APP_ID),
  measurementId: val(process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID),
} as const;

export const firebaseRecaptchaSiteKey = val(process.env.NEXT_PUBLIC_FIREBASE_RECAPTCHA_SITE_KEY);
export const firebaseVapidKey = val(process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY);

export function isFirebaseConfigured(): boolean {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.projectId &&
      firebaseConfig.appId &&
      firebaseConfig.messagingSenderId,
  );
}
