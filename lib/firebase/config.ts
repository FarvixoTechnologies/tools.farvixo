/**
 * Farvixo Tools — Firebase Production 2026 (Web)
 * Project: farvixo-production-2026
 *
 * Auth SoT = Supabase. Firebase = Analytics, App Check, RC, FCM, Firestore, Storage.
 * Client values must be NEXT_PUBLIC_* (browser-safe). Never put service-account secrets here.
 */

function env(name: string): string {
  const nextPublic = process.env[`NEXT_PUBLIC_${name}`];
  const plain = process.env[name];
  return (nextPublic || plain || '').trim();
}

export const firebaseConfig = {
  apiKey: env('FIREBASE_API_KEY'),
  authDomain: env('FIREBASE_AUTH_DOMAIN'),
  projectId: env('FIREBASE_PROJECT_ID'),
  storageBucket: env('FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: env('FIREBASE_MESSAGING_SENDER_ID'),
  appId: env('FIREBASE_APP_ID'),
  measurementId: env('FIREBASE_MEASUREMENT_ID'),
} as const;

export const firebaseRecaptchaSiteKey = env('FIREBASE_RECAPTCHA_SITE_KEY');
export const firebaseVapidKey = env('FIREBASE_VAPID_KEY');

export function isFirebaseConfigured(): boolean {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.projectId &&
      firebaseConfig.appId &&
      firebaseConfig.messagingSenderId,
  );
}
