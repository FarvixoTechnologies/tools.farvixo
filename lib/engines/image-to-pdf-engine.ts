'use client';

import { autoEnhance, canvasToBlob, loadImageToCanvas, makeCanvas, sharpen } from '@/lib/image';

export type PageSizePreset = 'auto' | 'a4' | 'a3' | 'a5' | 'letter' | 'legal' | 'tabloid' | 'custom';
export type PageOrientation = 'auto' | 'portrait' | 'landscape';
export type MarginPreset = 'none' | 'small' | 'medium' | 'large';
export type FitMode = 'contain' | 'fill' | 'stretch' | 'center' | 'original';
export type AlignV = 'top' | 'center' | 'bottom';
export type LayoutMode = 'one-per-page' | 'merge' | 'grid-2' | 'grid-4';

export interface Img2PdfAnalysis {
  width: number;
  height: number;
  orientation: 'portrait' | 'landscape' | 'square';
  blurScore: number;
  isBlurry: boolean;
  brightness: number;
  isDark: boolean;
  isBright: boolean;
  qualityScore: number;
  suggestedRotation: 0 | 90 | 180 | 270;
  hasText: boolean;
  isDocument: boolean;
  duplicateOf?: string;
  perceptualHash?: string;
}

export interface Img2PdfItem {
  id: string;
  file: File;
  name: string;
  thumbUrl: string;
  rotation: 0 | 90 | 180 | 270;
  contentHash?: string;
  analysis?: Img2PdfAnalysis;
}

export interface Img2PdfOptimize {
  autoRotate: boolean;
  smartCompression: boolean;
  autoEnhance: boolean;
  sharpen: boolean;
  jpegQuality: number;
}

export interface Img2PdfAdvanced {
  layout: LayoutMode;
  watermark: string;
  password: string;
  pageNumbers: boolean;
  header: string;
  footer: string;
  title: string;
  author: string;
  subject: string;
  keywords: string;
}

export interface Img2PdfSettings {
  pageSize: PageSizePreset;
  customWidthMm: number;
  customHeightMm: number;
  orientation: PageOrientation;
  margin: MarginPreset;
  fit: FitMode;
  align: AlignV;
  optimize: Img2PdfOptimize;
  advanced: Img2PdfAdvanced;
}

export const DEFAULT_IMG2PDF_SETTINGS: Img2PdfSettings = {
  pageSize: 'a4',
  customWidthMm: 210,
  customHeightMm: 297,
  orientation: 'auto',
  margin: 'medium',
  fit: 'contain',
  align: 'center',
  optimize: {
    autoRotate: true,
    smartCompression: true,
    autoEnhance: false,
    sharpen: false,
    jpegQuality: 0.88,
  },
  advanced: {
    layout: 'one-per-page',
    watermark: '',
    password: '',
    pageNumbers: false,
    header: '',
    footer: '',
    title: '',
    author: 'Farvixo Tools',
    subject: '',
    keywords: 'image to pdf, farvixo',
  },
};

const PAGE_PT: Record<Exclude<PageSizePreset, 'auto' | 'custom'>, [number, number]> = {
  a4: [595.28, 841.89],
  a3: [841.89, 1190.55],
  a5: [419.53, 595.28],
  letter: [612, 792],
  legal: [612, 1008],
  tabloid: [792, 1224],
};

const MARGIN_PT: Record<MarginPreset, number> = {
  none: 0,
  small: 18,
  medium: 36,
  large: 54,
};

export function uid(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

function mmToPt(mm: number): number {
  return (mm / 25.4) * 72;
}

export function resolvePageSize(settings: Img2PdfSettings, imgW: number, imgH: number): [number, number] {
  let w: number;
  let h: number;
  if (settings.pageSize === 'auto') {
    w = imgW;
    h = imgH;
  } else if (settings.pageSize === 'custom') {
    w = mmToPt(settings.customWidthMm);
    h = mmToPt(settings.customHeightMm);
  } else {
    [w, h] = PAGE_PT[settings.pageSize];
  }
  if (settings.orientation === 'landscape' || (settings.orientation === 'auto' && imgW > imgH && settings.pageSize !== 'auto')) {
    if (w < h) [w, h] = [h, w];
  } else if (settings.orientation === 'portrait' && w > h) {
    [w, h] = [h, w];
  }
  return [w, h];
}

function laplacianVariance(ctx: CanvasRenderingContext2D, w: number, h: number): number {
  const small = makeCanvas(Math.min(256, w), Math.min(256, h));
  const [sc, sctx] = small;
  sctx.drawImage(ctx.canvas, 0, 0, sc.width, sc.height);
  const { data, width: sw, height: sh } = sctx.getImageData(0, 0, sc.width, sc.height);
  let sum = 0;
  let sumSq = 0;
  let n = 0;
  for (let y = 1; y < sh - 1; y++) {
    for (let x = 1; x < sw - 1; x++) {
      const i = (y * sw + x) * 4;
      const lum =
        -data[i - sw * 4] - data[i - 4] + 4 * data[i] - data[i + 4] - data[i + sw * 4];
      sum += lum;
      sumSq += lum * lum;
      n++;
    }
  }
  const mean = sum / n;
  return sumSq / n - mean * mean;
}

function avgBrightness(ctx: CanvasRenderingContext2D, w: number, h: number): number {
  const sample = makeCanvas(Math.min(128, w), Math.min(128, h));
  const [, sctx] = sample;
  sctx.drawImage(ctx.canvas, 0, 0, sample[0].width, sample[0].height);
  const d = sctx.getImageData(0, 0, sample[0].width, sample[0].height).data;
  let t = 0;
  for (let i = 0; i < d.length; i += 4) {
    t += 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
  }
  return t / (d.length / 4);
}

function thumbHash(ctx: CanvasRenderingContext2D): string {
  const [c, tctx] = makeCanvas(8, 8);
  tctx.drawImage(ctx.canvas, 0, 0, 8, 8);
  const d = tctx.getImageData(0, 0, 8, 8).data;
  let bits = '';
  let avg = 0;
  for (let i = 0; i < d.length; i += 4) avg += d[i];
  avg /= d.length / 4;
  for (let i = 0; i < d.length; i += 4) bits += d[i] > avg ? '1' : '0';
  return bits;
}

export async function analyzeImageFile(file: File): Promise<Img2PdfAnalysis> {
  const canvas = await loadImageToCanvas(file);
  const ctx = canvas.getContext('2d')!;
  const { width, height } = canvas;
  const blurScore = laplacianVariance(ctx, width, height);
  const brightness = avgBrightness(ctx, width, height);
  const orientation = width > height * 1.05 ? 'landscape' : height > width * 1.05 ? 'portrait' : 'square';
  const aspect = width / height;
  const isDocument = aspect > 0.65 && aspect < 0.85 && height > width;
  const edgeDensity = blurScore;
  const hasText = edgeDensity > 120 && brightness > 80 && brightness < 220;
  let qualityScore = 70;
  if (blurScore > 200) qualityScore += 15;
  else if (blurScore < 50) qualityScore -= 25;
  if (width >= 1200 && height >= 1200) qualityScore += 10;
  if (width < 400 || height < 400) qualityScore -= 20;
  qualityScore = Math.max(0, Math.min(100, qualityScore));

  return {
    width,
    height,
    orientation,
    blurScore: Math.round(blurScore),
    isBlurry: blurScore < 80,
    brightness: Math.round(brightness),
    isDark: brightness < 70,
    isBright: brightness > 220,
    qualityScore,
    suggestedRotation: 0,
    hasText,
    isDocument,
    perceptualHash: thumbHash(ctx),
  };
}

export function markDuplicates(items: Img2PdfItem[]): Img2PdfItem[] {
  const hashes = new Map<string, string>();
  return items.map((item) => {
    const key = item.contentHash ?? `${item.file.size}-${item.analysis?.width}x${item.analysis?.height}`;
    const existing = hashes.get(key);
    if (existing) {
      return {
        ...item,
        analysis: item.analysis
          ? { ...item.analysis, duplicateOf: existing }
          : { width: 0, height: 0, orientation: 'square', blurScore: 0, isBlurry: false, brightness: 0, isDark: false, isBright: false, qualityScore: 0, suggestedRotation: 0, hasText: false, isDocument: false, duplicateOf: existing },
      };
    }
    hashes.set(key, item.id);
    return item;
  });
}

export async function createImg2PdfItem(file: File): Promise<Img2PdfItem> {
  const typed = file;
  const thumbUrl = URL.createObjectURL(file);
  let analysis: Img2PdfAnalysis | undefined;
  try {
    analysis = await analyzeImageFile(typed);
  } catch {
    analysis = undefined;
  }
  return {
    id: uid(),
    file: typed,
    name: file.name,
    thumbUrl,
    rotation: 0,
    contentHash: analysis?.perceptualHash,
    analysis,
  };
}

async function decodeToCanvas(file: File): Promise<HTMLCanvasElement> {
  const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
  if (ext === 'avif' || file.type === 'image/avif') {
    try {
      const { decode } = await import('@jsquash/avif');
      const buf = await file.arrayBuffer();
      const imageData = await decode(buf);
      if (imageData) {
        const [c, ctx] = makeCanvas(imageData.width, imageData.height);
        ctx.putImageData(imageData, 0, 0);
        return c;
      }
    } catch {
      /* fallback */
    }
  }
  if (ext === 'webp' || file.type === 'image/webp') {
    try {
      const { decode } = await import('@jsquash/webp');
      const imageData = await decode(await file.arrayBuffer());
      if (imageData) {
        const [c, ctx] = makeCanvas(imageData.width, imageData.height);
        ctx.putImageData(imageData, 0, 0);
        return c;
      }
    } catch {
      /* fallback */
    }
  }
  return loadImageToCanvas(file);
}

function rotateCanvas(src: HTMLCanvasElement, deg: 0 | 90 | 180 | 270): HTMLCanvasElement {
  if (!deg) return src;
  const w = deg === 90 || deg === 270 ? src.height : src.width;
  const h = deg === 90 || deg === 270 ? src.width : src.height;
  const [c, ctx] = makeCanvas(w, h);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, w, h);
  ctx.translate(w / 2, h / 2);
  ctx.rotate((deg * Math.PI) / 180);
  ctx.drawImage(src, -src.width / 2, -src.height / 2);
  return c;
}

function placeImage(
  ctx: CanvasRenderingContext2D,
  img: HTMLCanvasElement,
  pageW: number,
  pageH: number,
  margin: number,
  fit: FitMode,
  align: AlignV,
): void {
  const innerW = pageW - margin * 2;
  const innerH = pageH - margin * 2;
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, pageW, pageH);

  let dw = img.width;
  let dh = img.height;
  if (fit === 'original') {
    dw = img.width;
    dh = img.height;
  } else if (fit === 'stretch') {
    dw = innerW;
    dh = innerH;
  } else if (fit === 'fill') {
    const s = Math.max(innerW / img.width, innerH / img.height);
    dw = img.width * s;
    dh = img.height * s;
  } else {
    const s = Math.min(innerW / img.width, innerH / img.height);
    dw = img.width * s;
    dh = img.height * s;
  }

  const x = margin + (innerW - dw) / 2;
  let y = margin;
  if (align === 'center') y = margin + (innerH - dh) / 2;
  else if (align === 'bottom') y = margin + innerH - dh;
  ctx.drawImage(img, x, y, dw, dh);
}

export async function extractImagesFromZip(zipFile: File): Promise<File[]> {
  const JSZip = (await import('jszip')).default;
  const zip = await JSZip.loadAsync(await zipFile.arrayBuffer());
  const imgs: File[] = [];
  const re = /\.(jpe?g|png|webp|gif|bmp|avif|heic|heif|tiff?|svg)$/i;
  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir || !re.test(path)) continue;
    const blob = await entry.async('blob');
    imgs.push(new File([blob], path.split('/').pop() || 'image.jpg', { type: blob.type || 'image/jpeg' }));
  }
  return imgs;
}

export async function fetchImageFromUrl(url: string): Promise<File> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Could not fetch image (${res.status})`);
  const blob = await res.blob();
  if (!blob.type.startsWith('image/')) throw new Error('URL did not return an image');
  const name = url.split('/').pop()?.split('?')[0] || 'image.jpg';
  return new File([blob], name, { type: blob.type });
}

export interface BuildPdfProgress {
  progress: number;
  label: string;
}

export async function buildPdfFromImages(
  items: Img2PdfItem[],
  settings: Img2PdfSettings,
  onProgress?: (p: BuildPdfProgress) => void,
): Promise<Blob> {
  const { PDFDocument, StandardFonts, rgb, degrees } = await import('@cantoo/pdf-lib');
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const margin = MARGIN_PT[settings.margin];
  const total = items.length;

  if (settings.advanced.title) doc.setTitle(settings.advanced.title);
  if (settings.advanced.author) doc.setAuthor(settings.advanced.author);
  if (settings.advanced.subject) doc.setSubject(settings.advanced.subject);
  if (settings.advanced.keywords) {
    doc.setKeywords(settings.advanced.keywords.split(',').map((k) => k.trim()).filter(Boolean));
  }
  doc.setProducer('Farvixo Tools Image to PDF');
  doc.setCreationDate(new Date());

  let pageNum = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    onProgress?.({ progress: i / total, label: `Processing ${item.name}…` });

    let canvas = await decodeToCanvas(item.file);
    let rotation = item.rotation;
    if (settings.optimize.autoRotate && item.analysis?.suggestedRotation) {
      rotation = (rotation + item.analysis.suggestedRotation) as 0 | 90 | 180 | 270;
    }
    canvas = rotateCanvas(canvas, rotation);

    if (settings.optimize.autoEnhance) autoEnhance(canvas);
    if (settings.optimize.sharpen) sharpen(canvas, 0.25);

    const [pageW, pageH] = resolvePageSize(settings, canvas.width, canvas.height);
    const pageCanvas = makeCanvas(pageW, pageH)[0];
    const pctx = pageCanvas.getContext('2d')!;
    placeImage(pctx, canvas, pageW, pageH, margin, settings.fit, settings.align);

    const q = settings.optimize.smartCompression ? settings.optimize.jpegQuality : 0.95;
    const jpg = await canvasToBlob(pageCanvas, 'image/jpeg', q);
    const embedded = await doc.embedJpg(await jpg.arrayBuffer());
    const page = doc.addPage([pageW, pageH]);
    page.drawImage(embedded, { x: 0, y: 0, width: pageW, height: pageH });
    pageNum++;

    if (settings.advanced.header) {
      page.drawText(settings.advanced.header, { x: margin, y: pageH - 24, size: 9, font, color: rgb(0.4, 0.4, 0.45) });
    }
    if (settings.advanced.footer) {
      page.drawText(settings.advanced.footer, { x: margin, y: 18, size: 9, font, color: rgb(0.4, 0.4, 0.45) });
    }
    if (settings.advanced.pageNumbers) {
      const label = `${pageNum}`;
      page.drawText(label, {
        x: pageW - margin - font.widthOfTextAtSize(label, 9),
        y: 18,
        size: 9,
        font,
        color: rgb(0.35, 0.35, 0.4),
      });
    }
    if (settings.advanced.watermark.trim()) {
      const wm = settings.advanced.watermark.trim();
      page.drawText(wm, {
        x: pageW / 2 - font.widthOfTextAtSize(wm, 48) / 2,
        y: pageH / 2,
        size: 48,
        font,
        color: rgb(0.85, 0.85, 0.88),
        rotate: degrees(-32),
        opacity: 0.35,
      });
    }
  }

  onProgress?.({ progress: 0.95, label: 'Finalizing PDF…' });

  if (settings.advanced.password.trim()) {
    await doc.encrypt({
      userPassword: settings.advanced.password,
      ownerPassword: settings.advanced.password,
    });
  }

  const bytes = await doc.save();
  onProgress?.({ progress: 1, label: 'Done' });
  return new Blob([new Uint8Array(bytes)], { type: 'application/pdf' });
}

const SESSION_KEY = 'farvixo-img2pdf-v1';

export function saveImg2PdfSession(names: string[]): void {
  try {
    localStorage.setItem(SESSION_KEY, JSON.stringify({ names, at: Date.now() }));
  } catch { /* */ }
}

export function loadImg2PdfSession(): string[] {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as { names: string[]; at: number };
    if (Date.now() - parsed.at > 48 * 3600_000) return [];
    return parsed.names ?? [];
  } catch {
    return [];
  }
}

export const IMG2PDF_ACCEPT =
  'image/*,.jpg,.jpeg,.png,.webp,.heic,.heif,.avif,.bmp,.gif,.tiff,.tif,.svg';
