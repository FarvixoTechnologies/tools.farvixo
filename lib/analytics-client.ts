/** Fire-and-forget client analytics — never blocks UI. */
export function trackEvent(event: string, props?: Record<string, unknown>, userId?: string): void {
  void fetch('/api/analytics/track', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event, props, userId }),
  }).catch(() => { /* best-effort */ });
}
