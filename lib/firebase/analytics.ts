'use client';

import { type Analytics, getAnalytics, isSupported, logEvent, setUserId } from 'firebase/analytics';
import { ensureFirebaseReady } from '@/lib/firebase/app';

let analytics: Analytics | null = null;

export async function getFirebaseAnalytics(): Promise<Analytics | null> {
  if (typeof window === 'undefined') return null;
  if (analytics) return analytics;
  const app = await ensureFirebaseReady();
  if (!app) return null;
  try {
    if (!(await isSupported())) return null;
    analytics = getAnalytics(app);
    return analytics;
  } catch (e) {
    console.warn('[firebase] Analytics init failed:', e);
    return null;
  }
}

export type AnalyticsEventName =
  | 'page_view'
  | 'session_start'
  | 'tool_open'
  | 'tool_complete'
  | 'login'
  | 'signup'
  | 'search'
  | 'download'
  | 'share'
  | 'favorite'
  | 'ai_request'
  | 'ai_response'
  | 'errors';

export async function trackFirebaseEvent(
  name: AnalyticsEventName | string,
  params?: Record<string, string | number | boolean>,
): Promise<void> {
  try {
    const a = await getFirebaseAnalytics();
    if (!a) return;
    logEvent(a, name as string, params);
  } catch {
    /* best-effort */
  }
}

export async function setFirebaseUserId(userId: string | null): Promise<void> {
  try {
    const a = await getFirebaseAnalytics();
    if (!a) return;
    setUserId(a, userId);
  } catch {
    /* best-effort */
  }
}

export async function trackPageView(path: string): Promise<void> {
  await trackFirebaseEvent('page_view', {
    page_path: path,
    page_title: typeof document !== 'undefined' ? document.title : path,
  });
}

export async function trackSessionStart(): Promise<void> {
  await trackFirebaseEvent('session_start');
}
