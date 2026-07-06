'use client';

/**
 * Free Pollinations image generation — no API key required.
 * Primary: server proxy → image.pollinations.ai (no CORS, no 401)
 * Fallback: direct image.pollinations.ai in browser
 * gen.pollinations.ai is skipped unless server has POLLINATIONS_API_KEY
 */

export interface PollinationsImageOptions {
  prompt: string;
  negative?: string;
  width?: number;
  height?: number;
  seed?: number;
  model?: string;
  enhance?: boolean;
  signal?: AbortSignal;
}

const BROWSER_HEADERS: Record<string, string> = {
  Accept: 'image/*,*/*',
};

function buildPromptBody(prompt: string, negative?: string): string {
  const p = prompt.trim().slice(0, 1800);
  if (!negative?.trim()) return p;
  return `${p} --no ${negative.trim().slice(0, 400)}`;
}

function buildQuery(opts: PollinationsImageOptions): URLSearchParams {
  const params = new URLSearchParams();
  params.set('width', String(opts.width ?? 1024));
  params.set('height', String(opts.height ?? 1024));
  if (opts.seed !== undefined) params.set('seed', String(opts.seed));
  if (opts.model) params.set('model', opts.model);
  params.set('nologo', 'true');
  if (opts.enhance) params.set('enhance', 'true');
  return params;
}

function isImageBlob(blob: Blob): boolean {
  if (blob.type.startsWith('image/')) return true;
  return blob.size > 800;
}

async function fetchImageUrl(url: string, signal?: AbortSignal): Promise<Blob> {
  const res = await fetch(url, { headers: BROWSER_HEADERS, signal, cache: 'no-store' });
  if (!res.ok) {
    const errText = await res.text().catch(() => '');
    throw new Error(`${res.status}${errText ? `: ${errText.slice(0, 100)}` : ''}`);
  }
  const blob = await res.blob();
  if (!isImageBlob(blob)) {
    throw new Error('invalid response — try a shorter prompt');
  }
  return blob;
}

/** Free legacy endpoint only — never hits gen.pollinations.ai (401 without key). */
export async function fetchPollinationsImageDirect(opts: PollinationsImageOptions): Promise<Blob> {
  const body = buildPromptBody(opts.prompt, opts.negative);
  const qs = buildQuery(opts).toString();
  const url = `https://image.pollinations.ai/prompt/${encodeURIComponent(body)}?${qs}`;
  return fetchImageUrl(url, opts.signal);
}

/** Server proxy — best path from browser (no CORS, retries server-side). */
export async function fetchPollinationsImageViaApi(opts: PollinationsImageOptions): Promise<Blob> {
  const res = await fetch('/api/ai/image-generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: opts.prompt,
      negative: opts.negative,
      width: opts.width ?? 1024,
      height: opts.height ?? 1024,
      seed: opts.seed,
      model: opts.model ?? 'flux',
      enhance: opts.enhance ?? false,
    }),
    signal: opts.signal,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(err.error || `server error ${res.status}`);
  }

  const blob = await res.blob();
  if (!isImageBlob(blob)) throw new Error('server returned invalid image');
  return blob;
}

/**
 * Full free chain for browsers:
 * 1. Server proxy (image.pollinations.ai)
 * 2. Direct legacy endpoint
 */
export async function generateFreePollinationsImage(opts: PollinationsImageOptions): Promise<Blob> {
  const errors: string[] = [];

  // Proxy first — avoids CORS and gen.pollinations 401
  try {
    return await fetchPollinationsImageViaApi(opts);
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    errors.push(`proxy: ${e instanceof Error ? e.message : 'failed'}`);
  }

  try {
    return await fetchPollinationsImageDirect(opts);
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    errors.push(`direct: ${e instanceof Error ? e.message : 'failed'}`);
  }

  throw new Error(
    `Could not generate image. ${errors.join(' · ')}. Try a shorter prompt or wait a moment.`,
  );
}

/** Map UI model ids → Pollinations model param. */
export function mapPollinationsModel(modelId: string): string {
  const map: Record<string, string> = {
    flux: 'flux',
    'flux-pro': 'flux',
    turbo: 'turbo',
    sdxl: 'turbo',
    sd3: 'flux',
    openai: 'turbo',
    imagen: 'flux',
    realistic: 'flux',
    juggernaut: 'flux',
    dreamshaper: 'turbo',
    epic: 'flux',
    anime: 'turbo',
    pony: 'turbo',
  };
  return map[modelId] || 'flux';
}
