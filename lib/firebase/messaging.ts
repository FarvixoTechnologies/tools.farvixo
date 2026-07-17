'use client';

import {
  getMessaging,
  getToken,
  isSupported,
  onMessage,
  type Messaging,
} from 'firebase/messaging';
import { ensureFirebaseReady } from '@/lib/firebase/app';
import { firebaseVapidKey } from '@/lib/firebase/config';

let messaging: Messaging | null = null;

async function getMessagingInstance(): Promise<Messaging | null> {
  if (typeof window === 'undefined') return null;
  if (messaging) return messaging;
  if (!(await isSupported())) return null;
  const app = await ensureFirebaseReady();
  if (!app) return null;
  messaging = getMessaging(app);
  return messaging;
}

/** Request permission, return FCM token (or null). */
export async function getFcmToken(): Promise<string | null> {
  try {
    const vapidKey = firebaseVapidKey;
    if (!vapidKey) {
      console.info('[firebase] FCM skipped — NEXT_PUBLIC_FIREBASE_VAPID_KEY not set');
      return null;
    }
    if (!('Notification' in window)) return null;
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return null;

    const m = await getMessagingInstance();
    if (!m) return null;

    const registration = await navigator.serviceWorker.register(
      '/firebase-messaging-sw.js',
    );
    const token = await getToken(m, {
      vapidKey,
      serviceWorkerRegistration: registration,
    });
    return token || null;
  } catch (e) {
    console.warn('[firebase] FCM token failed:', e);
    return null;
  }
}

/** Persist FCM token to Supabase via API (authenticated user). */
export async function registerFcmTokenWithSupabase(): Promise<string | null> {
  const token = await getFcmToken();
  if (!token) return null;
  try {
    await fetch('/api/push/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token, platform: 'web' }),
    });
  } catch (e) {
    console.warn('[firebase] push token sync failed:', e);
  }
  return token;
}

export async function listenForegroundMessages(
  handler: (payload: unknown) => void,
): Promise<(() => void) | null> {
  const m = await getMessagingInstance();
  if (!m) return null;
  return onMessage(m, handler);
}
