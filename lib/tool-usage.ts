'use client';

/** Client-side recents + pinned tools (localStorage). */

const RECENTS_KEY = 'tn-recent-tools';
const PINS_KEY = 'tn-pinned-tools';
const MAX_RECENTS = 8;

function read(key: string): string[] {
  try {
    const raw = localStorage.getItem(key);
    const arr = raw ? (JSON.parse(raw) as unknown) : [];
    return Array.isArray(arr) ? arr.filter((x): x is string => typeof x === 'string') : [];
  } catch {
    return [];
  }
}

function write(key: string, slugs: string[]): void {
  try { localStorage.setItem(key, JSON.stringify(slugs)); } catch { /* storage full/blocked */ }
}

export function getRecentTools(): string[] {
  return read(RECENTS_KEY);
}

export function addRecentTool(slug: string): void {
  const next = [slug, ...read(RECENTS_KEY).filter((s) => s !== slug)].slice(0, MAX_RECENTS);
  write(RECENTS_KEY, next);
}

export function getPinnedTools(): string[] {
  return read(PINS_KEY);
}

export function togglePinnedTool(slug: string): string[] {
  const cur = read(PINS_KEY);
  const next = cur.includes(slug) ? cur.filter((s) => s !== slug) : [...cur, slug];
  write(PINS_KEY, next);
  return next;
}
