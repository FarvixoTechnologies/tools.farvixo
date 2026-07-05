'use client';

/** Fire-and-forget: record a tool run in the signed-in user's history. */

import { addRecentTool } from '@/lib/tool-usage';

const recordedThisSession = new Set<string>();

export function recordJob(toolSlug: string, status: 'used' | 'completed' | 'failed' = 'used'): void {
  addRecentTool(toolSlug); // local "Recently Used" rail — works logged-out too
  // Only record "used" once per tool per session to avoid noise.
  if (status === 'used') {
    if (recordedThisSession.has(toolSlug)) return;
    recordedThisSession.add(toolSlug);
  }
  void fetch('/api/jobs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ toolSlug, status }),
    keepalive: true,
  }).catch(() => {
    /* history is best-effort — never break the tool */
  });
}
