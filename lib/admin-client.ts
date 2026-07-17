'use client';

import type { ApiResponse } from '@/lib/api-response';

export async function adminFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, { ...init, headers: { 'Content-Type': 'application/json', ...init?.headers } });

  // Never assume the body is JSON: on a 5xx/HTML error page, a Cloudflare
  // Worker error (e.g. 1102), or an auth HTML redirect, res.json() throws
  // "Unexpected token '<'" and crashes the page. Read text, then parse safely.
  const raw = await res.text();
  let json: ApiResponse<T> | null = null;
  try {
    json = raw ? (JSON.parse(raw) as ApiResponse<T>) : null;
  } catch {
    json = null;
  }

  if (!json) {
    throw new Error(
      res.ok
        ? 'Server returned an unexpected (non-JSON) response.'
        : `Request failed (${res.status} ${res.statusText || 'error'}).`,
    );
  }

  if (!json.success || json.data === null) {
    const msg =
      json.error ||
      json.errorDetail?.message ||
      json.message ||
      `Request failed (${res.status}).`;
    throw new Error(msg);
  }

  return json.data;
}
