'use client';

import type { ApiResponse } from '@/lib/api-response';

export async function adminFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, { ...init, headers: { 'Content-Type': 'application/json', ...init?.headers } });
  const json = (await res.json()) as ApiResponse<T>;
  if (!json.success || json.data === null) {
    const msg =
      json.error ||
      json.errorDetail?.message ||
      json.message ||
      'Request failed';
    throw new Error(msg);
  }
  return json.data;
}
