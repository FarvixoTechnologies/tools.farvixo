'use client';

/**
 * Client-side session/device capture. Sends a lightweight fingerprint to the
 * server, which records the trusted IP/User-Agent. Best-effort: never throws.
 */

const DEVICE_KEY = 'farvixo:device-id';

function getDeviceId(): string {
  try {
    let id = localStorage.getItem(DEVICE_KEY);
    if (!id) {
      id =
        typeof crypto !== 'undefined' && 'randomUUID' in crypto
          ? crypto.randomUUID()
          : `dev_${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`;
      localStorage.setItem(DEVICE_KEY, id);
    }
    // Mirror to a cookie so middleware can identify this device's session.
    // Not a secret — just a stable per-device identifier.
    if (typeof document !== 'undefined' && !document.cookie.includes(`fv_device=${id}`)) {
      document.cookie = `fv_device=${id}; path=/; max-age=31536000; samesite=lax`;
    }
    return id;
  } catch {
    return 'web';
  }
}

/** Ensure the fv_device cookie exists as early as possible (called on mount). */
export function ensureDeviceCookie(): void {
  if (typeof window === 'undefined') return;
  try { getDeviceId(); } catch { /* ignore */ }
}

function detectPlatform(): string {
  if (typeof navigator === 'undefined') return 'web';
  const ua = navigator.userAgent;
  if (/android/i.test(ua)) return 'Android';
  if (/iphone|ipad|ipod/i.test(ua)) return 'iOS';
  if (/windows/i.test(ua)) return 'Windows';
  if (/mac os/i.test(ua)) return 'macOS';
  if (/linux/i.test(ua)) return 'Linux';
  return 'Web';
}

export function trackSession(event: string): void {
  if (typeof window === 'undefined') return;
  try {
    void (async () => {
      const res = await fetch('/api/auth/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        keepalive: true,
        body: JSON.stringify({
          device_id: getDeviceId(),
          platform: detectPlatform(),
          app_version: 'web',
          event,
        }),
      });
      const json = (await res.json().catch(() => null)) as { data?: { revoked?: boolean } } | null;
      // Admin revoked this session → sign the user out.
      if (json?.data?.revoked) {
        const { createClient } = await import('@/lib/supabase/client');
        const supabase = createClient();
        await supabase?.auth.signOut();
        window.location.href = '/login?revoked=1';
      }
    })().catch(() => {});
  } catch {
    /* best-effort */
  }
}
