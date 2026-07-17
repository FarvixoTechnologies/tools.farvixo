const FIREBASE_EVENTS = new Set<string>([
  'page_view',
  'session_start',
  'tool_open',
  'tool_complete',
  'login',
  'signup',
  'search',
  'download',
  'share',
  'favorite',
  'ai_request',
  'ai_response',
  'errors',
]);

/** Fire-and-forget client analytics — Supabase + Firebase (when configured). */
export function trackEvent(event: string, props?: Record<string, unknown>, userId?: string): void {
  void fetch('/api/analytics/track', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event, props, userId }),
  }).catch(() => {
    /* best-effort */
  });

  if (typeof window !== 'undefined' && FIREBASE_EVENTS.has(event)) {
    const flat: Record<string, string | number | boolean> = {};
    if (props) {
      for (const [k, v] of Object.entries(props)) {
        if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') {
          flat[k] = v;
        } else if (v != null) {
          flat[k] = String(v).slice(0, 100);
        }
      }
    }
    void import('@/lib/firebase/analytics').then(({ trackFirebaseEvent }) =>
      trackFirebaseEvent(event, flat),
    );
  }
}
