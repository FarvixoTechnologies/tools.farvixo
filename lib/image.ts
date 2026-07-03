'use client';

/** Universal Image Engine — canvas-based helpers. */

export function loadImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('Could not read this image file.'));
    img.src = url;
  });
}

export function makeCanvas(w: number, h: number): [HTMLCanvasElement, CanvasRenderingContext2D] {
  const c = document.createElement('canvas');
  c.width = Math.max(1, Math.round(w));
  c.height = Math.max(1, Math.round(h));
  const ctx = c.getContext('2d');
  if (!ctx) throw new Error('Canvas is not supported in this browser.');
  return [c, ctx];
}

export function canvasToBlob(canvas: HTMLCanvasElement, type = 'image/png', quality = 0.92): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Failed to encode image.'))), type, quality);
  });
}

/** Encode JPEG repeatedly, lowering quality until under targetKB (best effort). */
export async function canvasToTargetSize(canvas: HTMLCanvasElement, targetKB: number): Promise<Blob> {
  let lo = 0.05;
  let hi = 0.95;
  let best: Blob = await canvasToBlob(canvas, 'image/jpeg', hi);
  if (best.size / 1024 <= targetKB) return best;
  for (let i = 0; i < 8; i++) {
    const mid = (lo + hi) / 2;
    const blob = await canvasToBlob(canvas, 'image/jpeg', mid);
    if (blob.size / 1024 <= targetKB) {
      best = blob;
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return best;
}

/** Draw image cover-cropped into w×h. */
export function drawCover(img: HTMLImageElement, w: number, h: number): HTMLCanvasElement {
  const [c, ctx] = makeCanvas(w, h);
  const scale = Math.max(w / img.width, h / img.height);
  const dw = img.width * scale;
  const dh = img.height * scale;
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, w, h);
  ctx.drawImage(img, (w - dw) / 2, (h - dh) / 2, dw, dh);
  return c;
}

/** Sharpen convolution (used by upscaler/enhancer). */
export function sharpen(canvas: HTMLCanvasElement, amount = 0.35): void {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const src = ctx.getImageData(0, 0, w, h);
  const out = ctx.createImageData(w, h);
  const s = src.data;
  const o = out.data;
  const kernel = [0, -amount, 0, -amount, 1 + 4 * amount, -amount, 0, -amount, 0];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      for (let ch = 0; ch < 3; ch++) {
        let acc = 0;
        for (let ky = -1; ky <= 1; ky++) {
          for (let kx = -1; kx <= 1; kx++) {
            const px = Math.min(w - 1, Math.max(0, x + kx));
            const py = Math.min(h - 1, Math.max(0, y + ky));
            acc += s[(py * w + px) * 4 + ch] * kernel[(ky + 1) * 3 + (kx + 1)];
          }
        }
        o[(y * w + x) * 4 + ch] = Math.min(255, Math.max(0, acc));
      }
      o[(y * w + x) * 4 + 3] = s[(y * w + x) * 4 + 3];
    }
  }
  ctx.putImageData(out, 0, 0);
}

/** Auto-enhance: histogram stretch + saturation + slight sharpen. */
export function autoEnhance(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  let min = 255;
  let max = 0;
  for (let i = 0; i < d.length; i += 4) {
    const lum = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
    if (lum < min) min = lum;
    if (lum > max) max = lum;
  }
  const range = Math.max(1, max - min);
  const sat = 1.15;
  for (let i = 0; i < d.length; i += 4) {
    for (let c = 0; c < 3; c++) {
      d[i + c] = Math.min(255, Math.max(0, ((d[i + c] - min) / range) * 255));
    }
    const avg = (d[i] + d[i + 1] + d[i + 2]) / 3;
    for (let c = 0; c < 3; c++) {
      d[i + c] = Math.min(255, Math.max(0, avg + (d[i + c] - avg) * sat));
    }
  }
  ctx.putImageData(img, 0, 0);
  sharpen(canvas, 0.2);
}

export function extFromMime(mime: string): string {
  const map: Record<string, string> = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp', 'image/bmp': 'bmp', 'image/gif': 'gif' };
  return map[mime] || 'png';
}
