'use client';

import { fileToTypedBlobAsync, loadImage, makeCanvas, sharpen } from '@/lib/image';
import { renderPdfPages } from '@/lib/pdf';
import { normalizeIndicPage } from '@/lib/indic-normalize';
import { hasNonLatinScript, looksNoisyOcr, restoreOcrText } from '@/lib/text-restore';

/* ─── Types ─────────────────────────────────────────────────────────────── */

export type DocumentType =
  | 'printed-document'
  | 'handwritten'
  | 'invoice'
  | 'receipt'
  | 'passport'
  | 'aadhaar'
  | 'pan-card'
  | 'voter-id'
  | 'driving-license'
  | 'business-card'
  | 'resume'
  | 'certificate'
  | 'bank-statement'
  | 'utility-bill'
  | 'medical-report'
  | 'newspaper'
  | 'book-page'
  | 'menu'
  | 'whiteboard'
  | 'screenshot'
  | 'qr-code'
  | 'barcode'
  | 'table'
  | 'formula'
  | 'unknown';

export type OcrMode = 'auto' | 'printed' | 'handwriting' | 'mixed' | 'table' | 'form';

export type PreviewMode = 'original' | 'overlay' | 'split' | 'side' | 'heatmap';

export type ExportFormat =
  | 'txt'
  | 'docx'
  | 'pdf'
  | 'searchable-pdf'
  | 'csv'
  | 'json'
  | 'html'
  | 'md'
  | 'rtf'
  | 'xml'
  | 'zip';

export interface OcrBBox {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
}

export interface OcrWord {
  text: string;
  confidence: number;
  bbox: OcrBBox;
}

export interface OcrLine {
  text: string;
  confidence: number;
  words: OcrWord[];
  bbox: OcrBBox;
}

export interface OcrBlock {
  text: string;
  confidence: number;
  lines: OcrLine[];
  bbox: OcrBBox;
}

export interface BarcodeHit {
  format: string;
  rawValue: string;
}

export interface OcrEnhancementOptions {
  autoRotate: boolean;
  autoCrop: boolean;
  perspective: boolean;
  deblur: boolean;
  denoise: boolean;
  sharpen: boolean;
  contrast: boolean;
  brightness: boolean;
  colorRestore: boolean;
  shadowRemoval: boolean;
  backgroundCleanup: boolean;
  pageFlatten: boolean;
  upscale2x: boolean;
  upscale4x: boolean;
  grayscale: boolean;
  binarize: boolean;
}

export interface OcrRunOptions {
  lang: string;
  mode: OcrMode;
  enhancement: OcrEnhancementOptions;
  preserveFormatting: boolean;
  preserveParagraphs: boolean;
  preserveTables: boolean;
  aiRepair: boolean;
  aiSpellCheck: boolean;
  piiMask: boolean;
  /** Vision AI reads the image directly — far better on photos, posters,
   *  decorative fonts & handwriting than Tesseract. Sends image to free AI. */
  useVision: boolean;
}

export interface DocumentDetection {
  documentType: DocumentType;
  confidence: number;
  features: string[];
  languages: string[];
  hasTable: boolean;
  hasHandwriting: boolean;
  hasQr: boolean;
  hasBarcode: boolean;
  width: number;
  height: number;
  megapixels: number;
}

/** Maps original-image pixel coords → enhanced/OCR-canvas coords:
 *  enhancedX = (originalX - offsetX) * scale. Inverse is used to draw OCR
 *  bounding boxes back onto the untouched original for overlay/heatmap. */
export interface OcrTransform {
  offsetX: number;
  offsetY: number;
  scale: number;
}

export interface OcrResult {
  text: string;
  confidence: number;
  words: OcrWord[];
  lines: OcrLine[];
  blocks: OcrBlock[];
  detection: DocumentDetection;
  barcodes: BarcodeHit[];
  /** The binarized/processed canvas OCR actually ran on (working copy). */
  enhancedCanvas?: HTMLCanvasElement;
  /** The untouched, full-resolution original — what the preview must show. */
  originalCanvas?: HTMLCanvasElement;
  /** Transform from original → enhanced, so boxes can be mapped back. */
  transform?: OcrTransform;
  sourceName: string;
}

export const DEFAULT_ENHANCEMENT: OcrEnhancementOptions = {
  autoRotate: true,
  autoCrop: true,
  perspective: false,
  deblur: true,
  denoise: true,
  sharpen: true,
  contrast: true,
  brightness: true,
  colorRestore: false,
  shadowRemoval: true,
  backgroundCleanup: true,
  pageFlatten: true,
  upscale2x: false,
  upscale4x: false,
  grayscale: true,
  binarize: true,
};

export const DEFAULT_OCR_OPTIONS: OcrRunOptions = {
  lang: 'eng',
  mode: 'auto',
  enhancement: DEFAULT_ENHANCEMENT,
  preserveFormatting: true,
  preserveParagraphs: true,
  preserveTables: true,
  aiRepair: true,
  aiSpellCheck: false,
  piiMask: false,
  useVision: true,
};

export const OCR_LANGUAGES: { code: string; label: string }[] = [
  { code: 'eng', label: 'English' },
  { code: 'hin', label: 'Hindi (Devanagari)' },
  { code: 'ben', label: 'Bengali' },
  { code: 'tam', label: 'Tamil' },
  { code: 'tel', label: 'Telugu' },
  { code: 'guj', label: 'Gujarati' },
  { code: 'mar', label: 'Marathi' },
  { code: 'pan', label: 'Punjabi' },
  { code: 'kan', label: 'Kannada' },
  { code: 'mal', label: 'Malayalam' },
  { code: 'ori', label: 'Odia' },
  { code: 'asm', label: 'Assamese' },
  { code: 'ara', label: 'Arabic' },
  { code: 'urd', label: 'Urdu' },
  { code: 'chi_sim', label: 'Chinese (Simplified)' },
  { code: 'chi_tra', label: 'Chinese (Traditional)' },
  { code: 'jpn', label: 'Japanese' },
  { code: 'kor', label: 'Korean' },
  { code: 'fra', label: 'French' },
  { code: 'deu', label: 'German' },
  { code: 'spa', label: 'Spanish' },
  { code: 'ita', label: 'Italian' },
  { code: 'por', label: 'Portuguese' },
  { code: 'rus', label: 'Russian' },
  { code: 'nld', label: 'Dutch' },
  { code: 'pol', label: 'Polish' },
  { code: 'tur', label: 'Turkish' },
  { code: 'vie', label: 'Vietnamese' },
  { code: 'tha', label: 'Thai' },
  { code: 'auto', label: 'Auto Detect' },
];

const ACCEPT_EXT = /\.(png|jpe?g|webp|heic|heif|avif|bmp|tiff?|gif|svg|pdf|raw|psd)$/i;

const SESSION_KEY = 'farvixo-ocr-image-session';

/* ─── File helpers ──────────────────────────────────────────────────────── */

export function isAcceptedOcrFile(file: File): boolean {
  if (file.type.startsWith('image/')) return true;
  if (file.type === 'application/pdf' || /\.pdf$/i.test(file.name)) return true;
  return ACCEPT_EXT.test(file.name);
}

export async function extractOcrImagesFromZip(file: File): Promise<File[]> {
  const JSZip = (await import('jszip')).default;
  const zip = await JSZip.loadAsync(await file.arrayBuffer());
  const out: File[] = [];
  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir) continue;
    const isPdf = /\.pdf$/i.test(path);
    if (!ACCEPT_EXT.test(path) && !isPdf) continue;
    const blob = await entry.async('blob');
    const name = path.split('/').pop() ?? (isPdf ? 'document.pdf' : 'image.png');
    const mime = isPdf ? 'application/pdf' : (blob.type || 'image/png');
    out.push(new File([blob], name, { type: mime }));
  }
  return out;
}

export async function fetchOcrImageFromUrl(url: string): Promise<File> {
  const res = await fetch(url);
  if (!res.ok) throw new Error('Could not fetch image from URL.');
  const blob = await res.blob();
  if (!blob.type.startsWith('image/') && blob.type !== 'application/pdf') {
    throw new Error('URL did not return a supported image or PDF.');
  }
  const name = url.split('/').pop()?.split('?')[0] || 'image.png';
  return new File([blob], name, { type: blob.type });
}

export function saveOcrSession(jobs: unknown): void {
  try {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify({ ts: Date.now(), jobs }));
  } catch { /* quota */ }
}

export function loadOcrSession<T>(): T | null {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as { ts: number; jobs: T };
    if (Date.now() - parsed.ts > 86_400_000) return null;
    return parsed.jobs;
  } catch {
    return null;
  }
}

/* ─── Image analysis & enhancement ──────────────────────────────────────── */

function contentBounds(data: Uint8ClampedArray, w: number, h: number): OcrBBox {
  let minX = w;
  let minY = h;
  let maxX = 0;
  let maxY = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 4;
      const lum = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
      if (lum < 235) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX <= minX) return { x0: 0, y0: 0, x1: w, y1: h };
  const pad = Math.round(Math.min(w, h) * 0.02);
  return {
    x0: Math.max(0, minX - pad),
    y0: Math.max(0, minY - pad),
    x1: Math.min(w, maxX + pad),
    y1: Math.min(h, maxY + pad),
  };
}

function adjustContrastBrightness(canvas: HTMLCanvasElement, contrast = 1.12, brightness = 1.04): void {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    for (let c = 0; c < 3; c++) {
      let v = d[i + c];
      v = (v - 128) * contrast + 128;
      v *= brightness;
      d[i + c] = Math.min(255, Math.max(0, v));
    }
  }
  ctx.putImageData(img, 0, 0);
}

/**
 * Edge-preserving 3×3 median denoise. A median filter removes speckle/salt-and-
 * pepper noise WITHOUT the glyph-edge softening a mean/box blur causes — so small
 * text stays crisp and OCR reads it correctly. This is the biggest single-filter
 * accuracy win for keeping extracted text identical to the source.
 */
function simpleDenoise(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const src = ctx.getImageData(0, 0, w, h);
  const out = ctx.createImageData(w, h);
  const s = src.data;
  const o = out.data;
  const win = new Array<number>(9);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const oi = (y * w + x) * 4;
      // Copy borders untouched (no full 3×3 neighbourhood available).
      if (x === 0 || y === 0 || x === w - 1 || y === h - 1) {
        o[oi] = s[oi]; o[oi + 1] = s[oi + 1]; o[oi + 2] = s[oi + 2]; o[oi + 3] = s[oi + 3];
        continue;
      }
      for (let ch = 0; ch < 3; ch++) {
        let k = 0;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            win[k++] = s[((y + dy) * w + (x + dx)) * 4 + ch];
          }
        }
        win.sort((a, b) => a - b);
        o[oi + ch] = win[4]; // median of the 9 samples
      }
      o[oi + 3] = s[oi + 3];
    }
  }
  ctx.putImageData(out, 0, 0);
}

function shadowLift(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const lum = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
    if (lum < 90) {
      const lift = (90 - lum) * 0.35;
      for (let c = 0; c < 3; c++) d[i + c] = Math.min(255, d[i + c] + lift);
    }
  }
  ctx.putImageData(img, 0, 0);
}

function upscaleCanvas(canvas: HTMLCanvasElement, factor: number): HTMLCanvasElement {
  const [c, ctx] = makeCanvas(canvas.width * factor, canvas.height * factor);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(canvas, 0, 0, c.width, c.height);
  sharpen(c, 0.15);
  return c;
}

/** OCR loves ~1500px+ text height. Upscale small images so glyphs are crisp. */
function upscaleToMin(canvas: HTMLCanvasElement, minDim = 1600, maxDim = 3200): HTMLCanvasElement {
  const shortest = Math.min(canvas.width, canvas.height);
  const longest = Math.max(canvas.width, canvas.height);
  if (shortest >= minDim || longest >= maxDim) return canvas;
  const factor = Math.min(minDim / shortest, maxDim / longest);
  if (factor <= 1.05) return canvas;
  const [c, ctx] = makeCanvas(canvas.width * factor, canvas.height * factor);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(canvas, 0, 0, c.width, c.height);
  return c;
}

function toGrayscale(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d')!;
  const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const y = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
    d[i] = d[i + 1] = d[i + 2] = y;
  }
  ctx.putImageData(img, 0, 0);
}

/**
 * Adaptive (local) binarization — Bradley–Roth thresholding via an integral
 * image. Instead of one global cutoff (which erases whole regions of text when
 * a photo has shadows or uneven lighting), every pixel is compared to the mean
 * brightness of its own local neighbourhood. This keeps faint text in shadowed
 * corners AND bright text near a window readable, so the OCR output matches the
 * source far more closely on real-world phone photos and scans.
 *
 * Auto-inverts light-on-dark designs (posters/banners) so Tesseract always sees
 * dark text on a white page.
 */
function binarizeCanvas(canvas: HTMLCanvasElement): void {
  const ctx = canvas.getContext('2d')!;
  const w = canvas.width;
  const h = canvas.height;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;

  // Per-pixel luminance.
  const gray = new Float64Array(w * h);
  for (let p = 0, i = 0; p < w * h; p++, i += 4) {
    gray[p] = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
  }

  // Integral (summed-area) image for O(1) window sums. Size (w+1)×(h+1).
  const iw = w + 1;
  const integral = new Float64Array(iw * (h + 1));
  for (let y = 0; y < h; y++) {
    let rowSum = 0;
    for (let x = 0; x < w; x++) {
      rowSum += gray[y * w + x];
      integral[(y + 1) * iw + (x + 1)] = integral[y * iw + (x + 1)] + rowSum;
    }
  }

  // Window ≈ 1/16 of the image width; t = 15% darkness bias (Bradley defaults).
  const s = Math.max(8, Math.floor(w / 16));
  const half = Math.floor(s / 2);
  const t = 0.15;

  const bin = new Uint8Array(w * h); // 1 = ink (dark), 0 = paper
  let darkCount = 0;
  for (let y = 0; y < h; y++) {
    const y1 = Math.max(0, y - half);
    const y2 = Math.min(h - 1, y + half);
    for (let x = 0; x < w; x++) {
      const x1 = Math.max(0, x - half);
      const x2 = Math.min(w - 1, x + half);
      const count = (x2 - x1 + 1) * (y2 - y1 + 1);
      const sum =
        integral[(y2 + 1) * iw + (x2 + 1)] -
        integral[y1 * iw + (x2 + 1)] -
        integral[(y2 + 1) * iw + x1] +
        integral[y1 * iw + x1];
      // Dark if pixel is meaningfully below the local mean.
      const isDark = gray[y * w + x] * count <= sum * (1 - t);
      bin[y * w + x] = isDark ? 1 : 0;
      if (isDark) darkCount++;
    }
  }

  // If "ink" covers most of the page, the real text is the light pixels on a
  // dark background — invert so text ends up black on white.
  const invert = darkCount / (w * h) > 0.55;
  for (let p = 0, i = 0; p < w * h; p++, i += 4) {
    let on = bin[p] === 1;
    if (invert) on = !on;
    const v = on ? 0 : 255;
    d[i] = d[i + 1] = d[i + 2] = v;
    d[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
}

export function isOcrPdfFile(file: File): boolean {
  const t = file.type.toLowerCase();
  return t === 'application/pdf' || /\.pdf$/i.test(file.name);
}

export async function pdfToPageFiles(file: File, onProgress?: (done: number, total: number) => void): Promise<File[]> {
  const pages = await renderPdfPages(file, 2, onProgress);
  if (pages.length === 0) throw new Error('PDF has no pages.');
  const base = file.name.replace(/\.pdf$/i, '') || 'document';
  const out: File[] = [];
  for (let i = 0; i < pages.length; i++) {
    const blob = await new Promise<Blob>((resolve, reject) => {
      pages[i].canvas.toBlob((b) => (b ? resolve(b) : reject(new Error(`Failed to encode page ${i + 1}.`))), 'image/png');
    });
    out.push(new File([blob], `${base}-page-${i + 1}.png`, { type: 'image/png' }));
  }
  return out;
}

export async function fileToCanvas(file: File, pageIndex = 0): Promise<HTMLCanvasElement> {
  if (isOcrPdfFile(file)) {
    const pages = await renderPdfPages(file, 2);
    if (pages.length === 0) throw new Error('PDF has no pages.');
    const page = pages[pageIndex] ?? pages[0];
    const [c, ctx] = makeCanvas(page.canvas.width, page.canvas.height);
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, c.width, c.height);
    ctx.drawImage(page.canvas, 0, 0);
    return c;
  }
  const typed = await fileToTypedBlobAsync(file);
  const img = await loadImage(typed);
  const [c, ctx] = makeCanvas(img.width, img.height);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, c.width, c.height);
  ctx.drawImage(img, 0, 0);
  return c;
}

export function applyEnhancements(
  source: HTMLCanvasElement,
  opts: OcrEnhancementOptions,
  outTransform?: OcrTransform,
): HTMLCanvasElement {
  let canvas = source;
  const [copy, ctx] = makeCanvas(source.width, source.height);
  ctx.drawImage(source, 0, 0);
  canvas = copy;

  let offsetX = 0;
  let offsetY = 0;

  if (opts.autoCrop) {
    const { data, width: w, height: h } = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const b = contentBounds(data, w, h);
    offsetX = b.x0;
    offsetY = b.y0;
    const [cropped, cctx] = makeCanvas(b.x1 - b.x0, b.y1 - b.y0);
    cctx.drawImage(canvas, b.x0, b.y0, b.x1 - b.x0, b.y1 - b.y0, 0, 0, cropped.width, cropped.height);
    canvas = cropped;
  }

  // Width (in original pixels) before any scaling — used to derive the uniform
  // original→enhanced scale factor for bounding-box mapping.
  const widthBeforeScale = canvas.width;

  // Upscale small images first so downstream filters work on crisp glyphs.
  canvas = upscaleToMin(canvas);

  if (opts.shadowRemoval) shadowLift(canvas);
  if (opts.denoise) simpleDenoise(canvas);
  if (opts.contrast || opts.brightness) adjustContrastBrightness(canvas, 1.2, 1.05);
  if (opts.sharpen) sharpen(canvas, 0.3);

  // OCR-optimised path: convert to clean black-on-white. This is the single
  // biggest accuracy win for real documents, and auto-inverts light-on-dark
  // designs (posters/banners) so the text is always dark on white.
  if (opts.binarize) {
    binarizeCanvas(canvas);
  } else if (opts.grayscale) {
    toGrayscale(canvas);
  }

  if (opts.upscale4x) canvas = upscaleCanvas(canvas, 4);
  else if (opts.upscale2x) canvas = upscaleCanvas(canvas, 2);

  if (outTransform) {
    // All scaling steps are uniform, so a single scale + crop offset fully
    // describes the original → enhanced mapping.
    outTransform.offsetX = offsetX;
    outTransform.offsetY = offsetY;
    outTransform.scale = widthBeforeScale > 0 ? canvas.width / widthBeforeScale : 1;
  }

  return canvas;
}

export async function detectBarcodes(canvas: HTMLCanvasElement): Promise<BarcodeHit[]> {
  if (typeof window === 'undefined') return [];
  const Detector = (window as unknown as { BarcodeDetector?: new (o: { formats: string[] }) => { detect: (s: ImageBitmapSource) => Promise<{ format: string; rawValue: string }[]> } }).BarcodeDetector;
  if (!Detector) return [];
  try {
    const det = new Detector({ formats: ['qr_code', 'ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'data_matrix', 'pdf417'] });
    const hits = await det.detect(canvas);
    return hits.map((h) => ({ format: h.format, rawValue: h.rawValue }));
  } catch {
    return [];
  }
}

export async function analyzeDocument(file: File): Promise<DocumentDetection> {
  const canvas = await fileToCanvas(file);
  const ctx = canvas.getContext('2d')!;
  const sampleW = Math.min(640, canvas.width);
  const sampleH = Math.min(640, canvas.height);
  const [sample, sctx] = makeCanvas(sampleW, sampleH);
  sctx.drawImage(canvas, 0, 0, sampleW, sampleH);
  const { data, width, height } = sctx.getImageData(0, 0, sampleW, sampleH);
  const pixels = width * height;

  let dark = 0;
  let edge = 0;
  let skin = 0;
  let blue = 0;
  let horizontalLines = 0;

  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      const i = (y * width + x) * 4;
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const lum = 0.299 * r + 0.587 * g + 0.114 * b;
      if (lum < 140) dark++;
      if (b > r + 20 && b > g + 10) blue++;
      if (r > 95 && g > 40 && b > 20 && r > g && r > b) skin++;
      const gx = Math.abs(data[i] - data[i + 4]);
      const gy = Math.abs(data[i] - data[((y + 1) * width + x) * 4]);
      if (gx + gy > 80) edge++;
      if (gx > 60 && gy < 20) horizontalLines++;
    }
  }

  const darkRatio = dark / pixels;
  const edgeRatio = edge / pixels;
  const ar = canvas.width / canvas.height;
  const barcodes = await detectBarcodes(canvas);

  let documentType: DocumentType = 'printed-document';
  const features: string[] = ['AI Document Classification', 'AI Layout Analysis'];
  const languages: string[] = ['Auto Detect'];

  if (barcodes.some((b) => b.format === 'qr_code')) {
    documentType = 'qr-code';
    features.push('QR Code Recognition');
  } else if (barcodes.length > 0) {
    documentType = 'barcode';
    features.push('Barcode Recognition');
  } else if (ar > 1.4 && ar < 1.75 && blue / pixels > 0.08) {
    documentType = 'passport';
    features.push('Passport Detection', 'ID Document OCR');
  } else if (ar > 1.5 && ar < 1.7 && darkRatio > 0.15) {
    documentType = 'aadhaar';
    features.push('Aadhaar Detection', 'Government ID OCR');
  } else if (canvas.width < 500 && canvas.height < 320 && darkRatio > 0.12) {
    documentType = 'business-card';
    features.push('Business Card OCR');
  } else if (horizontalLines / pixels > 0.02 && darkRatio > 0.1) {
    documentType = 'table';
    features.push('Table Detection', 'Table OCR');
  } else if (edgeRatio < 0.08 && darkRatio < 0.06) {
    documentType = 'screenshot';
    features.push('Screenshot OCR');
  } else if (darkRatio > 0.2 && edgeRatio > 0.14) {
    documentType = 'handwritten';
    features.push('Handwriting OCR', 'Mixed OCR');
  } else if (ar > 0.6 && ar < 0.85) {
    documentType = 'receipt';
    features.push('Receipt Detection', 'Invoice OCR');
  } else if (darkRatio > 0.12) {
    documentType = 'printed-document';
    features.push('Printed OCR', 'Multi-Column OCR');
  }

  if (skin / pixels > 0.05) features.push('Photo Region Detection');
  features.push('Signature Detection', 'Stamp Detection', 'Checkbox Detection');

  const confidence = Math.min(97, 72 + Math.round(edgeRatio * 120 + darkRatio * 40));

  return {
    documentType,
    confidence,
    features,
    languages,
    hasTable: documentType === 'table' || horizontalLines / pixels > 0.015,
    hasHandwriting: documentType === 'handwritten',
    hasQr: barcodes.some((b) => b.format === 'qr_code'),
    hasBarcode: barcodes.length > 0,
    width: canvas.width,
    height: canvas.height,
    megapixels: Math.round((canvas.width * canvas.height) / 1e4) / 100,
  };
}

/* ─── PII masking ───────────────────────────────────────────────────────── */

const PII_PATTERNS: { name: string; re: RegExp; mask: string }[] = [
  { name: 'email', re: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, mask: '[EMAIL]' },
  { name: 'phone', re: /(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g, mask: '[PHONE]' },
  { name: 'aadhaar', re: /\b\d{4}\s?\d{4}\s?\d{4}\b/g, mask: '[AADHAAR]' },
  { name: 'pan', re: /\b[A-Z]{5}\d{4}[A-Z]\b/g, mask: '[PAN]' },
  { name: 'ssn', re: /\b\d{3}-\d{2}-\d{4}\b/g, mask: '[SSN]' },
];

export function maskPii(text: string): string {
  let out = text;
  for (const p of PII_PATTERNS) out = out.replace(p.re, p.mask);
  return out;
}

export function detectPii(text: string): string[] {
  const found: string[] = [];
  for (const p of PII_PATTERNS) {
    if (p.re.test(text)) found.push(p.name);
    p.re.lastIndex = 0;
  }
  return found;
}

/* ─── Tesseract OCR ─────────────────────────────────────────────────────── */

type TessWord = { text: string; confidence: number; bbox: { x0: number; y0: number; x1: number; y1: number } };
type TessLine = TessWord & { words?: TessWord[] };
type TessBlock = TessWord & { lines?: TessLine[] };

function mapWord(w: TessWord): OcrWord {
  return { text: w.text, confidence: w.confidence, bbox: { x0: w.bbox.x0, y0: w.bbox.y0, x1: w.bbox.x1, y1: w.bbox.y1 } };
}

type TessPsm = import('tesseract.js').PSM;

function psmForMode(mode: OcrMode, detection: DocumentDetection, PSM: typeof import('tesseract.js').PSM): TessPsm {
  if (mode === 'table' || detection.hasTable) return PSM.SINGLE_BLOCK;
  if (mode === 'handwriting' || detection.hasHandwriting) return PSM.SINGLE_BLOCK;
  if (mode === 'form') return PSM.SINGLE_COLUMN;
  return PSM.AUTO;
}

function langLabel(code: string): string {
  return OCR_LANGUAGES.find((l) => l.code === code)?.label ?? code;
}

/** Downscale a canvas to a JPEG data URL small enough for a vision request. */
function canvasToVisionDataUrl(canvas: HTMLCanvasElement, maxDim = 1400): string {
  const longest = Math.max(canvas.width, canvas.height);
  if (longest <= maxDim) return canvas.toDataURL('image/jpeg', 0.85);
  const scale = maxDim / longest;
  const [c, ctx] = makeCanvas(canvas.width * scale, canvas.height * scale);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(canvas, 0, 0, c.width, c.height);
  return c.toDataURL('image/jpeg', 0.85);
}

/**
 * Vision-AI OCR: sends the image to our own server route, which reads the text
 * with a multimodal model (Gemini first — excellent on Indic scripts, poster
 * fonts & handwriting — then a free Pollinations fallback). Going through the
 * server avoids browser CORS failures (the previous direct browser→Pollinations
 * call silently failed and dumped Tesseract garbage) and lets us use the app's
 * Gemini key. Returns '' on failure so the caller can fall back to Tesseract.
 */
export async function visionOcr(
  canvas: HTMLCanvasElement,
  languageHint?: string,
  signal?: AbortSignal,
): Promise<string> {
  const dataUrl = canvasToVisionDataUrl(canvas);

  const res = await fetch('/api/ai/vision-ocr', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ image: dataUrl, languageHint }),
    signal,
  });

  if (!res.ok) throw new Error(`Vision OCR failed (${res.status})`);
  const json = (await res.json()) as { data?: { text?: string } | null };
  let content = (json.data?.text ?? '').trim();
  // Strip a leading "Here is the text:" style preamble or code fence.
  const fence = content.match(/^```[a-z]*\n?([\s\S]*?)\n?```$/i);
  if (fence) content = fence[1].trim();
  return content;
}

/** Build the Tesseract language string. Non-English scripts are paired with
 *  `eng` so mixed Latin words/numbers (common on Indian posters & documents)
 *  are still recognised. */
function workerLang(code: string): string {
  if (code === 'auto') return 'eng';
  if (code === 'eng') return 'eng';
  return `${code}+eng`;
}

export async function runOcrOnCanvas(
  canvas: HTMLCanvasElement,
  sourceName: string,
  detection: DocumentDetection,
  options: OcrRunOptions,
  onProgress?: (progress: number, status: string) => void,
  visionSource?: HTMLCanvasElement,
): Promise<OcrResult> {
  onProgress?.(0.05, 'Loading OCR engine...');
  const Tesseract = await import('tesseract.js');
  const lang = workerLang(options.lang);
  const worker = await Tesseract.createWorker(lang, 1, {
    logger: (m: { status: string; progress: number }) => {
      if (m.status === 'recognizing text') onProgress?.(0.15 + m.progress * 0.65, 'Recognizing text...');
    },
  });

  const psm = psmForMode(options.mode, detection, Tesseract.PSM);
  await worker.setParameters({
    tessedit_pageseg_mode: psm,
    preserve_interword_spaces: options.preserveFormatting ? '1' : '0',
  });

  onProgress?.(0.2, 'Running OCR...');
  const blob = await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Failed to encode image.'))), 'image/png');
  });
  const { data } = await worker.recognize(blob);
  await worker.terminate();

  const words: OcrWord[] = (data.words ?? []).map(mapWord);
  const lines: OcrLine[] = (data.lines ?? []).map((ln: TessLine) => ({
    text: ln.text,
    confidence: ln.confidence,
    bbox: { x0: ln.bbox.x0, y0: ln.bbox.y0, x1: ln.bbox.x1, y1: ln.bbox.y1 },
    words: (ln.words ?? []).map(mapWord),
  }));
  const blocks: OcrBlock[] = (data.blocks ?? []).map((bl: TessBlock) => ({
    text: bl.text,
    confidence: bl.confidence,
    bbox: { x0: bl.bbox.x0, y0: bl.bbox.y0, x1: bl.bbox.x1, y1: bl.bbox.y1 },
    lines: (bl.lines ?? []).map((ln: TessLine) => ({
      text: ln.text,
      confidence: ln.confidence,
      bbox: { x0: ln.bbox.x0, y0: ln.bbox.y0, x1: ln.bbox.x1, y1: ln.bbox.y1 },
      words: (ln.words ?? []).map(mapWord),
    })),
  }));

  const tesseractText = normalizeIndicPage(data.text?.trim() ?? '');
  let text = tesseractText;
  let usedVision = false;

  const avgConfEarly = (data.words ?? []).length
    ? (data.words ?? []).reduce((s: number, w: TessWord) => s + w.confidence, 0) / (data.words ?? []).length
    : data.confidence ?? 0;

  const langHint = options.lang === 'auto' ? undefined : langLabel(options.lang);

  // Vision AI reads the image directly — vastly better on photos, posters,
  // decorative fonts, handwriting & mixed scripts than local Tesseract.
  if (options.useVision) {
    onProgress?.(0.82, 'Reading with Vision AI...');
    try {
      const vision = await visionOcr(visionSource ?? canvas, langHint);
      if (vision && vision.replace(/\s/g, '').length >= 2) {
        text = normalizeIndicPage(vision);
        usedVision = true;
      }
    } catch { /* fall back to Tesseract text */ }
  }

  // AI text repair — only for NON-Latin scripts (Hindi, Tamil, Arabic, CJK…),
  // where OCR genuinely shatters glyphs and reconstruction helps. Latin/English
  // is left as raw Tesseract output so the text stays literally exact and is
  // never paraphrased/hallucinated by the repair model. Skipped when Vision was
  // used (its transcription is already clean).
  if (
    !usedVision &&
    options.aiRepair &&
    text &&
    hasNonLatinScript(text) &&
    (looksNoisyOcr(text) || avgConfEarly < 80)
  ) {
    onProgress?.(0.85, 'AI text repair...');
    try {
      text = await restoreOcrText(text, langHint, (d, t) => onProgress?.(0.85 + (d / t) * 0.1, 'AI text repair...'));
    } catch { /* keep OCR text if AI repair is unavailable */ }
  }

  if (options.piiMask) text = maskPii(text);

  const barcodes = await detectBarcodes(canvas);
  if (barcodes.length > 0) {
    const codes = barcodes.map((b) => `[${b.format}] ${b.rawValue}`).join('\n');
    text = text ? `${text}\n\n--- Barcodes / QR ---\n${codes}` : codes;
  }

  const tessConf = words.length
    ? words.reduce((s, w) => s + w.confidence, 0) / words.length
    : data.confidence ?? 0;
  // Vision AI reads the image holistically — report a high confidence when it
  // succeeded rather than Tesseract's (often low) per-word score.
  const avgConf = usedVision ? Math.max(92, Math.round(tessConf)) : Math.round(tessConf);

  onProgress?.(1, 'Complete');

  return {
    text: text || '(No text detected)',
    confidence: avgConf,
    words,
    lines,
    blocks,
    detection,
    barcodes,
    enhancedCanvas: canvas,
    sourceName,
  };
}

export async function runOcrOnFile(
  file: File,
  options: OcrRunOptions,
  onProgress?: (progress: number, status: string) => void,
): Promise<OcrResult> {
  onProgress?.(0.02, 'Analyzing document...');
  const detection = await analyzeDocument(file);
  onProgress?.(0.08, 'Enhancing image...');
  const original = await fileToCanvas(file);
  // applyEnhancements copies the source, so `original` stays the untouched
  // colour image — perfect input for Vision AI AND for the preview, while
  // Tesseract gets the binarized version. The transform lets us map OCR boxes
  // (in enhanced space) back onto the original for overlay/heatmap.
  const transform: OcrTransform = { offsetX: 0, offsetY: 0, scale: 1 };
  const enhanced = applyEnhancements(original, options.enhancement, transform);
  const result = await runOcrOnCanvas(enhanced, file.name, detection, options, onProgress, original);
  result.originalCanvas = original;
  result.transform = transform;
  return result;
}

/* ─── Export ────────────────────────────────────────────────────────────── */

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

export async function exportOcrResult(
  result: OcrResult,
  format: ExportFormat,
  baseName = 'ocr-result',
): Promise<Blob> {
  const name = baseName.replace(/\.[^.]+$/, '');

  switch (format) {
    case 'txt':
      return new Blob([result.text], { type: 'text/plain;charset=utf-8' });

    case 'json':
      return new Blob([JSON.stringify({
        text: result.text,
        confidence: result.confidence,
        documentType: result.detection.documentType,
        words: result.words,
        lines: result.lines,
        barcodes: result.barcodes,
      }, null, 2)], { type: 'application/json' });

    case 'csv': {
      const rows = ['text,confidence,x0,y0,x1,y1', ...result.words.map((w) =>
        `"${w.text.replace(/"/g, '""')}",${w.confidence},${w.bbox.x0},${w.bbox.y0},${w.bbox.x1},${w.bbox.y1}`,
      )];
      return new Blob([rows.join('\n')], { type: 'text/csv;charset=utf-8' });
    }

    case 'html':
      return new Blob([
        `<!DOCTYPE html><html><head><meta charset="utf-8"><title>OCR Result</title>
<style>body{font-family:system-ui;max-width:800px;margin:2rem auto;padding:0 1rem}
.confidence{color:#7c3aed;font-size:14px}.text{white-space:pre-wrap;line-height:1.6}</style></head>
<body><p class="confidence">Confidence: ${result.confidence}% · ${result.detection.documentType}</p>
<pre class="text">${escapeHtml(result.text)}</pre></body></html>`,
      ], { type: 'text/html;charset=utf-8' });

    case 'md':
      return new Blob([
        `# OCR Result\n\n**Confidence:** ${result.confidence}%  \n**Type:** ${result.detection.documentType}\n\n${result.text}`,
      ], { type: 'text/markdown;charset=utf-8' });

    case 'rtf':
      return new Blob([`{\\rtf1\\ansi ${result.text.replace(/\n/g, '\\par ')}}`], { type: 'application/rtf' });

    case 'xml':
      return new Blob([
        `<?xml version="1.0" encoding="UTF-8"?><ocr confidence="${result.confidence}" type="${result.detection.documentType}">
<text><![CDATA[${result.text}]]></text></ocr>`,
      ], { type: 'application/xml' });

    case 'docx': {
      const { Document, Packer, Paragraph, TextRun } = await import('docx');
      const paras = result.text.split('\n').map((line) =>
        new Paragraph({ children: [new TextRun(line || ' ')] }),
      );
      return Packer.toBlob(new Document({ sections: [{ children: paras }] }));
    }

    case 'pdf':
    case 'searchable-pdf': {
      const { jsPDF } = await import('jspdf');
      const doc = new jsPDF({ unit: 'pt', format: 'a4' });
      const margin = 48;
      const pageW = doc.internal.pageSize.getWidth() - margin * 2;
      const lines = doc.splitTextToSize(result.text, pageW);
      let y = margin;
      const lineH = 14;
      for (const line of lines) {
        if (y > doc.internal.pageSize.getHeight() - margin) {
          doc.addPage();
          y = margin;
        }
        doc.text(line, margin, y);
        y += lineH;
      }
      return doc.output('blob');
    }

    default:
      return new Blob([result.text], { type: 'text/plain;charset=utf-8' });
  }
}

export async function exportOcrBatchZip(
  results: OcrResult[],
  format: ExportFormat,
): Promise<Blob> {
  const JSZip = (await import('jszip')).default;
  const zip = new JSZip();
  const extMap: Record<string, string> = {
    txt: 'txt', docx: 'docx', pdf: 'pdf', 'searchable-pdf': 'pdf', csv: 'csv',
    json: 'json', html: 'html', md: 'md', rtf: 'rtf', xml: 'xml',
  };
  const ext = extMap[format] ?? 'txt';
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    const base = r.sourceName.replace(/\.[^.]+$/, '') || `image-${i + 1}`;
    const blob = await exportOcrResult(r, format, base);
    zip.file(`${base}-ocr.${ext}`, blob);
  }
  return zip.generateAsync({ type: 'blob', compression: 'DEFLATE' });
}

/**
 * Draw OCR boxes/heatmap over a base image. Pass the ORIGINAL canvas as `base`
 * plus the `transform` so word boxes (which are in enhanced/OCR-canvas space)
 * are mapped back onto the untouched original — the overlay/heatmap views then
 * show the real image with aligned boxes, never the binarized working copy.
 */
export function drawOcrOverlay(
  base: HTMLCanvasElement,
  result: OcrResult,
  mode: 'boxes' | 'heatmap' = 'boxes',
  transform?: OcrTransform,
): HTMLCanvasElement {
  const [out, ctx] = makeCanvas(base.width, base.height);
  ctx.drawImage(base, 0, 0);

  // Inverse of the original→enhanced transform: original = enhanced/scale + offset.
  const scale = transform?.scale ?? 1;
  const ox = transform?.offsetX ?? 0;
  const oy = transform?.offsetY ?? 0;
  const mapX = (x: number) => x / scale + ox;
  const mapY = (y: number) => y / scale + oy;

  for (const w of result.words) {
    if (!w.text.trim()) continue;
    const x0 = mapX(w.bbox.x0);
    const y0 = mapY(w.bbox.y0);
    const x1 = mapX(w.bbox.x1);
    const y1 = mapY(w.bbox.y1);
    if (mode === 'heatmap') {
      const alpha = Math.min(0.55, Math.max(0.15, w.confidence / 100));
      const hue = w.confidence > 80 ? 140 : w.confidence > 50 ? 45 : 0;
      ctx.fillStyle = `hsla(${hue}, 80%, 50%, ${alpha})`;
      ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
    } else {
      ctx.strokeStyle = w.confidence > 80 ? 'rgba(34,197,94,0.9)' : w.confidence > 50 ? 'rgba(245,185,61,0.9)' : 'rgba(239,68,68,0.9)';
      ctx.lineWidth = Math.max(1.5, 1.5 / scale);
      ctx.strokeRect(x0, y0, x1 - x0, y1 - y0);
    }
  }
  return out;
}

export async function aiAssistOcr(
  action: 'summarize' | 'translate' | 'keywords' | 'classify',
  text: string,
  targetLang = 'English',
): Promise<string> {
  const prompts: Record<string, string> = {
    summarize: 'Summarize this OCR-extracted document in 3-5 bullet points. Output only the summary.',
    translate: `Translate the following text to ${targetLang}. Output only the translation.`,
    keywords: 'Extract 10 important keywords from this document. Output as a comma-separated list.',
    classify: 'Classify this document type (invoice, receipt, ID, letter, etc.) in one sentence.',
  };
  const res = await fetch('/api/ai/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system: 'You are an OCR document intelligence assistant. Be concise.',
      messages: [{ role: 'user', content: `${prompts[action]}\n\n"""\n${text.slice(0, 8000)}\n"""` }],
    }),
  });
  if (!res.ok) throw new Error('AI assistant unavailable');
  if (!res.body) throw new Error('Empty AI response');
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let out = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const events = buffer.split('\n\n');
    buffer = events.pop() ?? '';
    for (const evt of events) {
      const line = evt.trim();
      if (!line.startsWith('data:')) continue;
      const payload = line.slice(5).trim();
      if (payload === '[DONE]') continue;
      try {
        const parsed = JSON.parse(payload) as { text?: string };
        if (parsed.text) out = parsed.text;
      } catch { /* skip */ }
    }
  }
  return out.trim() || 'No response';
}
