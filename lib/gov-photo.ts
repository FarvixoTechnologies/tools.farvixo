'use client';

import { jsPDF } from 'jspdf';
import JSZip from 'jszip';
import { canvasToBlob, fileToTypedBlobAsync, loadImage, loadImageToCanvas, makeCanvas } from '@/lib/image';

/* ─── PAN Card portal specifications ─── */

export type PanPortal = 'nsdl' | 'uti';
export type PanFileType = 'photo' | 'signature' | 'document';

export interface PanSpec {
  w: number;
  h: number;
  dpi: number;
  minKB: number;
  maxKB: number;
  format: 'jpeg' | 'pdf';
  cmLabel: string;
}

export const PAN_SPECS: Record<PanPortal, Record<PanFileType, PanSpec>> = {
  nsdl: {
    photo: { w: 197, h: 276, dpi: 200, minKB: 20, maxKB: 50, format: 'jpeg', cmLabel: '3.5 × 2.5 cm' },
    signature: { w: 354, h: 157, dpi: 200, minKB: 10, maxKB: 50, format: 'jpeg', cmLabel: '4.5 × 2 cm' },
    document: { w: 2480, h: 3508, dpi: 200, minKB: 1, maxKB: 300, format: 'pdf', cmLabel: 'A4 PDF' },
  },
  uti: {
    photo: { w: 213, h: 213, dpi: 300, minKB: 5, maxKB: 30, format: 'jpeg', cmLabel: '213 × 213 px' },
    signature: { w: 400, h: 200, dpi: 600, minKB: 5, maxKB: 60, format: 'jpeg', cmLabel: '400 × 200 px' },
    document: { w: 2480, h: 3508, dpi: 200, minKB: 1, maxKB: 2048, format: 'pdf', cmLabel: 'A4 PDF' },
  },
};

export interface EditState {
  panX: number;
  panY: number;
  zoom: number;
  rotation: number;
  brightness: number;
  contrast: number;
}

export const DEFAULT_EDIT: EditState = {
  panX: 0.5,
  panY: 0.5,
  zoom: 1,
  rotation: 0,
  brightness: 100,
  contrast: 100,
};

export interface FaceBBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface FaceAnalysis {
  detected: boolean;
  bbox: FaceBBox;
  eyeY: number;
  eyeOpen: boolean;
  frontFacing: boolean;
  glareWarning: boolean;
}

export type ComplianceStatus = 'pass' | 'fail' | 'warn' | 'skip';

export interface ComplianceItem {
  id: string;
  label: string;
  labelHi: string;
  status: ComplianceStatus;
  message?: string;
  messageHi?: string;
}

/* ─── MediaPipe face detection (CDN, no npm) ─── */

type Landmark = { x: number; y: number; z?: number };

/** MediaPipe WASM logs INFO lines via stderr → console.error; Next.js dev overlay treats them as crashes. */
let mediaPipeLogFilterInstalled = false;
function installMediaPipeLogFilter(): void {
  if (mediaPipeLogFilterInstalled || typeof console === 'undefined') return;
  mediaPipeLogFilterInstalled = true;
  const origError = console.error.bind(console);
  console.error = (...args: unknown[]) => {
    const msg = args
      .map((a) => (typeof a === 'string' ? a : a instanceof Error ? a.message : String(a)))
      .join(' ');
    if (/^INFO:/i.test(msg)) return;
    if (/TensorFlow Lite|XNNPACK|vision_wasm|mediapipe|W0000|I0000/i.test(msg)) return;
    origError(...args);
  };
}

if (typeof window !== 'undefined') installMediaPipeLogFilter();

function downscaleForFaceDetection(source: HTMLCanvasElement | HTMLImageElement): HTMLCanvasElement {
  const sw = 'naturalWidth' in source ? source.naturalWidth : source.width;
  const sh = 'naturalHeight' in source ? source.naturalHeight : source.height;
  const maxDim = 640;
  if (Math.max(sw, sh) <= maxDim) {
    if (source instanceof HTMLCanvasElement) return source;
    const [c, ctx] = makeCanvas(sw, sh);
    ctx.drawImage(source, 0, 0);
    return c;
  }
  const scale = maxDim / Math.max(sw, sh);
  const [c, ctx] = makeCanvas(Math.round(sw * scale), Math.round(sh * scale));
  ctx.drawImage(source, 0, 0, c.width, c.height);
  return c;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let faceLandmarkerPromise: Promise<any> | null = null;

async function getFaceLandmarker(): Promise<{ detect: (img: HTMLCanvasElement | HTMLImageElement) => { faceLandmarks?: Landmark[][] } }> {
  if (!faceLandmarkerPromise) {
    installMediaPipeLogFilter();
    faceLandmarkerPromise = (async () => {
      const dynamicImport = new Function('u', 'return import(u)') as (u: string) => Promise<unknown>;
      const mp = await dynamicImport('https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/+esm') as {
        FaceLandmarker: { createFromOptions: (v: unknown, o: Record<string, unknown>) => Promise<{ detect: (img: HTMLCanvasElement | HTMLImageElement) => { faceLandmarks?: Landmark[][] } }> };
        FilesetResolver: { forVisionTasks: (base: string) => Promise<unknown> };
      };
      const vision = await mp.FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm',
      );
      return mp.FaceLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath:
            'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
          delegate: 'CPU',
        },
        runningMode: 'IMAGE',
        numFaces: 1,
      });
    })();
  }
  return faceLandmarkerPromise;
}

function bboxFromLandmarks(pts: Landmark[]): FaceBBox {
  let minX = 1;
  let minY = 1;
  let maxX = 0;
  let maxY = 0;
  for (const p of pts) {
    minX = Math.min(minX, p.x);
    minY = Math.min(minY, p.y);
    maxX = Math.max(maxX, p.x);
    maxY = Math.max(maxY, p.y);
  }
  const pad = 0.08;
  return {
    x: Math.max(0, minX - pad * (maxX - minX)),
    y: Math.max(0, minY - pad * (maxY - minY)),
    w: Math.min(1, maxX - minX + pad * 2 * (maxX - minX)),
    h: Math.min(1, maxY - minY + pad * 2 * (maxY - minY)),
  };
}

export async function detectFace(source: HTMLCanvasElement | HTMLImageElement): Promise<FaceAnalysis | null> {
  try {
    installMediaPipeLogFilter();
    const landmarker = await getFaceLandmarker();
    const sample = downscaleForFaceDetection(source);
    const result = landmarker.detect(sample);
    const pts = result.faceLandmarks?.[0];
    if (!pts?.length) return null;

    const bbox = bboxFromLandmarks(pts);
    const leftEye = pts[33];
    const rightEye = pts[263];
    const upperL = pts[159];
    const lowerL = pts[145];
    const upperR = pts[386];
    const lowerR = pts[374];
    const nose = pts[1];

    const eyeY = ((leftEye.y + rightEye.y) / 2);
    const eyeDistL = Math.abs(upperL.y - lowerL.y);
    const eyeDistR = Math.abs(upperR.y - lowerR.y);
    const eyeOpen = eyeDistL > 0.008 && eyeDistR > 0.008;

    const faceCenterX = bbox.x + bbox.w / 2;
    const noseOffset = Math.abs(nose.x - faceCenterX) / Math.max(0.01, bbox.w);
    const frontFacing = noseOffset < 0.15;

    const glareWarning = detectGlare(source, leftEye, rightEye);

    return { detected: true, bbox, eyeY, eyeOpen, frontFacing, glareWarning };
  } catch {
    return null;
  }
}

function detectGlare(
  source: HTMLCanvasElement | HTMLImageElement,
  leftEye: Landmark,
  rightEye: Landmark,
): boolean {
  const w = 'naturalWidth' in source ? source.naturalWidth : source.width;
  const h = 'naturalHeight' in source ? source.naturalHeight : source.height;
  const [, ctx] = makeCanvas(w, h);
  ctx.drawImage(source, 0, 0);
  const data = ctx.getImageData(0, 0, w, h).data;
  const check = (lm: Landmark) => {
    const x = Math.round(lm.x * w);
    const y = Math.round(lm.y * h);
    const r = 8;
    let bright = 0;
    let n = 0;
    for (let dy = -r; dy <= r; dy++) {
      for (let dx = -r; dx <= r; dx++) {
        const px = x + dx;
        const py = y + dy;
        if (px < 0 || py < 0 || px >= w || py >= h) continue;
        const i = (py * w + px) * 4;
        const lum = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
        if (lum > 245) bright++;
        n++;
      }
    }
    return n > 0 && bright / n > 0.35;
  };
  return check(leftEye) || check(rightEye);
}

/* ─── Background removal (@imgly) ─── */

type ImglyModule = { removeBackground: (src: Blob, cfg?: Record<string, unknown>) => Promise<Blob> };

let imglyPromise: Promise<ImglyModule> | null = null;

async function loadImgly(): Promise<ImglyModule> {
  if (!imglyPromise) {
    const dynamicImport = new Function('u', 'return import(u)') as (u: string) => Promise<ImglyModule>;
    imglyPromise = dynamicImport('https://cdn.jsdelivr.net/npm/@imgly/background-removal@1.5.5/+esm');
  }
  return imglyPromise;
}

export async function compositeOnWhite(file: File): Promise<HTMLCanvasElement> {
  const imgly = await loadImgly();
  const cut = await imgly.removeBackground(file);
  const fg = await loadImage(new File([cut], 'cut.png', { type: 'image/png' }));
  const [c, ctx] = makeCanvas(fg.width, fg.height);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, c.width, c.height);
  ctx.drawImage(fg, 0, 0);
  return c;
}

export function isBackgroundLight(canvas: HTMLCanvasElement, threshold = 220): boolean {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const sample = (x: number, y: number) => {
    const d = ctx.getImageData(x, y, 1, 1).data;
    return 0.299 * d[0] + 0.587 * d[1] + 0.114 * d[2];
  };
  const pts = [
    [2, 2], [w - 3, 2], [2, h - 3], [w - 3, h - 3],
    [w >> 1, 2], [w >> 1, h - 3], [2, h >> 1], [w - 3, h >> 1],
  ];
  const avg = pts.reduce((s, [x, y]) => s + sample(x, y), 0) / pts.length;
  return avg >= threshold;
}

/* ─── Image rendering & encoding ─── */

export function fileToCanvas(file: File): Promise<HTMLCanvasElement> {
  return loadImageToCanvas(file);
}

export function autoEditFromFace(
  face: FaceAnalysis,
  imgW: number,
  imgH: number,
  spec: PanSpec,
): EditState {
  const coverScale = Math.max(spec.w / imgW, spec.h / imgH);
  const facePxH = face.bbox.h * imgH;
  const desiredFacePxH = spec.h * 0.75;
  const zoom = Math.min(2, Math.max(1, desiredFacePxH / (facePxH * coverScale)));

  const faceCenterX = face.bbox.x + face.bbox.w / 2;
  const faceCenterY = face.bbox.y + face.bbox.h * 0.45 + face.bbox.y * 0.1;
  const targetX = 0.5;
  const targetY = 0.4;

  const panX = clamp01(0.5 + (faceCenterX - targetX) * zoom * 0.8);
  const panY = clamp01(0.5 + (faceCenterY - targetY) * zoom * 0.8);

  return { panX, panY, zoom, rotation: 0, brightness: 100, contrast: 100 };
}

function clamp01(v: number) {
  return Math.min(1, Math.max(0, v));
}

export function renderToSpec(
  source: HTMLCanvasElement | HTMLImageElement,
  spec: PanSpec,
  edit: EditState,
): HTMLCanvasElement {
  const sw = 'naturalWidth' in source ? source.naturalWidth : source.width;
  const sh = 'naturalHeight' in source ? source.naturalHeight : source.height;
  const [out, outCtx] = makeCanvas(spec.w, spec.h);
  outCtx.fillStyle = '#ffffff';
  outCtx.fillRect(0, 0, spec.w, spec.h);

  const coverScale = Math.max(spec.w / sw, spec.h / sh) * edit.zoom;
  const drawW = sw * coverScale;
  const drawH = sh * coverScale;

  const ox = (spec.w - drawW) * edit.panX;
  const oy = (spec.h - drawH) * edit.panY;

  outCtx.save();
  outCtx.filter = `brightness(${edit.brightness}%) contrast(${edit.contrast}%)`;
  if (edit.rotation !== 0) {
    outCtx.translate(spec.w / 2, spec.h / 2);
    outCtx.rotate((edit.rotation * Math.PI) / 180);
    outCtx.translate(-spec.w / 2, -spec.h / 2);
  }
  outCtx.drawImage(source, ox, oy, drawW, drawH);
  outCtx.restore();
  return out;
}

export async function embedJpegDpi(blob: Blob, dpi: number): Promise<Blob> {
  const buf = new Uint8Array(await blob.arrayBuffer());
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) return blob;

  let offset = 2;
  while (offset < buf.length - 4) {
    if (buf[offset] !== 0xff) break;
    const marker = buf[offset + 1];
    const len = (buf[offset + 2] << 8) | buf[offset + 3];
    if (marker === 0xe0 && len >= 16) {
      const out = new Uint8Array(buf);
      out[offset + 11] = 1;
      out[offset + 12] = (dpi >> 8) & 0xff;
      out[offset + 13] = dpi & 0xff;
      out[offset + 14] = (dpi >> 8) & 0xff;
      out[offset + 15] = dpi & 0xff;
      return new Blob([out], { type: 'image/jpeg' });
    }
    if (marker === 0xd9) break;
    offset += 2 + len;
  }

  const jfif = new Uint8Array([
    0xff, 0xe0, 0x00, 0x10,
    0x4a, 0x46, 0x49, 0x46, 0x00,
    0x01, 0x01, 0x01,
    (dpi >> 8) & 0xff, dpi & 0xff,
    (dpi >> 8) & 0xff, dpi & 0xff,
    0x00, 0x00,
  ]);
  const out = new Uint8Array(2 + jfif.length + (buf.length - 2));
  out[0] = 0xff;
  out[1] = 0xd8;
  out.set(jfif, 2);
  out.set(buf.subarray(2), 2 + jfif.length);
  return new Blob([out], { type: 'image/jpeg' });
}

export async function readJpegDpi(blob: Blob): Promise<number | null> {
  const buf = new Uint8Array(await blob.arrayBuffer());
  let offset = 2;
  while (offset < buf.length - 16) {
    if (buf[offset] !== 0xff) break;
    const marker = buf[offset + 1];
    const len = (buf[offset + 2] << 8) | buf[offset + 3];
    if (marker === 0xe0 && buf[offset + 4] === 0x4a) {
      const units = buf[offset + 11];
      const xd = (buf[offset + 12] << 8) | buf[offset + 13];
      if (units === 1) return xd;
      if (units === 2) return Math.round(xd * 2.54);
      return null;
    }
    offset += 2 + len;
  }
  return null;
}

/** Binary-search JPEG quality to land in safe KB zone (prefer midpoint). */
export async function canvasToForceWeight(
  canvas: HTMLCanvasElement,
  minKB: number,
  maxKB: number,
): Promise<Blob> {
  const targetKB = Math.round((minKB + maxKB) / 2);
  let lo = 0.05;
  let hi = 0.98;
  let best: Blob | null = null;
  let bestDiff = Infinity;

  for (let i = 0; i < 14; i++) {
    const mid = (lo + hi) / 2;
    const blob = await canvasToBlob(canvas, 'image/jpeg', mid);
    const kb = blob.size / 1024;
    const diff = Math.abs(kb - targetKB);
    if (kb >= minKB && kb <= maxKB && diff < bestDiff) {
      best = blob;
      bestDiff = diff;
    }
    if (kb > maxKB) hi = mid;
    else lo = mid;
  }

  if (best) return best;

  for (let q = 0.98; q >= 0.05; q -= 0.05) {
    const blob = await canvasToBlob(canvas, 'image/jpeg', q);
    if (blob.size / 1024 <= maxKB) return blob;
  }
  return canvasToBlob(canvas, 'image/jpeg', 0.5);
}

export async function encodeForSpec(
  canvas: HTMLCanvasElement,
  spec: PanSpec,
): Promise<Blob> {
  const raw = await canvasToForceWeight(canvas, spec.minKB, spec.maxKB);
  return embedJpegDpi(raw, spec.dpi);
}

/* ─── Quality analysis ─── */

export function laplacianVariance(canvas: HTMLCanvasElement): number {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  let sum = 0;
  let sumSq = 0;
  let n = 0;
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const lum = (i: number) => 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
      const i = (y * w + x) * 4;
      const c = lum(i);
      const lap =
        lum(i - w * 4) + lum(i + w * 4) + lum(i - 4) + lum(i + 4) - 4 * c;
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  return sumSq / n - (sum / n) ** 2;
}

export function estimateFaceCoverage(
  face: FaceAnalysis,
  imgW: number,
  imgH: number,
  spec: PanSpec,
  edit: EditState,
): number {
  const coverScale = Math.max(spec.w / imgW, spec.h / imgH) * edit.zoom;
  const facePxH = face.bbox.h * imgH * coverScale;
  return facePxH / spec.h;
}

/* ─── Compliance validator (12 checks) ─── */

export async function validateCompliance(
  canvas: HTMLCanvasElement,
  blob: Blob,
  spec: PanSpec,
  fileType: PanFileType,
  face: FaceAnalysis | null,
  opts?: { edit?: EditState; sourceW?: number; sourceH?: number },
): Promise<ComplianceItem[]> {
  const items: ComplianceItem[] = [];
  const kb = blob.size / 1024;

  items.push({
    id: 'dimensions',
    label: 'Dimensions match portal spec',
    labelHi: 'आयाम पोर्टल विनिर्देश से मेल खाते हैं',
    status: canvas.width === spec.w && canvas.height === spec.h ? 'pass' : 'fail',
    message: `${canvas.width}×${canvas.height}px (required ${spec.w}×${spec.h}px)`,
  });

  items.push({
    id: 'filesize',
    label: 'File size within range',
    labelHi: 'फ़ाइल आकार सीमा के भीतर',
    status: kb >= spec.minKB && kb <= spec.maxKB ? 'pass' : kb > spec.maxKB ? 'fail' : 'warn',
    message: `${kb.toFixed(1)} KB (required ${spec.minKB}–${spec.maxKB} KB)`,
    messageHi: kb < spec.minKB ? 'फ़ाइल बहुत छोटी — गुणवत्ता अस्वीकृति हो सकती है' : undefined,
  });

  items.push({
    id: 'format',
    label: spec.format === 'pdf' ? 'File format is PDF' : 'File format is JPEG',
    labelHi: spec.format === 'pdf' ? 'फ़ाइल प्रारूप PDF है' : 'फ़ाइल प्रारूप JPEG है',
    status:
      spec.format === 'pdf'
        ? blob.type === 'application/pdf' ? 'pass' : 'fail'
        : blob.type === 'image/jpeg' ? 'pass' : 'fail',
  });

  const dpi = spec.format === 'jpeg' ? await readJpegDpi(blob) : null;
  items.push({
    id: 'dpi',
    label: 'DPI metadata correct',
    labelHi: 'DPI मेटाडेटा सही है',
    status:
      spec.format === 'pdf'
        ? 'skip'
        : dpi === spec.dpi
          ? 'pass'
          : dpi
            ? 'warn'
            : 'warn',
    message: dpi ? `${dpi} DPI (required ${spec.dpi})` : `Embedded ${spec.dpi} DPI on export`,
  });

  const bgOk = isBackgroundLight(canvas);
  items.push({
    id: 'background',
    label: 'White/light background',
    labelHi: 'सफेद/हल्का पृष्ठभूमि',
    status: fileType === 'photo' ? (bgOk ? 'pass' : 'warn') : 'skip',
    message: bgOk ? 'Background appears white/light' : 'Use white wall or enable AI background removal',
  });

  if (fileType === 'photo') {
    items.push({
      id: 'face',
      label: 'Face detected',
      labelHi: 'चेहरा पहचाना गया',
      status: face?.detected ? 'pass' : 'warn',
      message: face?.detected ? 'Face found' : 'No face detected — adjust crop manually',
    });

    const coverage =
      face && opts?.sourceW && opts?.sourceH
        ? estimateFaceCoverage(face, opts.sourceW, opts.sourceH, spec, opts.edit ?? DEFAULT_EDIT)
        : null;
    items.push({
      id: 'coverage',
      label: 'Face coverage 70–80%',
      labelHi: 'चेहरा कवरेज 70–80%',
      status:
        coverage === null
          ? 'skip'
          : coverage >= 0.65 && coverage <= 0.85
            ? 'pass'
            : 'warn',
      message: coverage !== null ? `~${Math.round(coverage * 100)}% of frame` : undefined,
    });

    items.push({
      id: 'eyes',
      label: 'Eyes open',
      labelHi: 'आँखें खुली हैं',
      status: face?.eyeOpen ? 'pass' : face ? 'warn' : 'skip',
    });

    items.push({
      id: 'front',
      label: 'Front-facing pose',
      labelHi: 'सामने की ओर मुख',
      status: face?.frontFacing ? 'pass' : face ? 'warn' : 'skip',
    });

    items.push({
      id: 'glare',
      label: 'No glasses glare',
      labelHi: 'चश्मे पर चमक नहीं',
      status: face?.glareWarning ? 'warn' : face ? 'pass' : 'skip',
      message: face?.glareWarning ? 'Possible glare detected on glasses' : undefined,
    });
  }

  const sharpness = laplacianVariance(canvas);
  items.push({
    id: 'sharpness',
    label: 'Image not blurry',
    labelHi: 'छवि धुंधली नहीं',
    status: sharpness > 80 ? 'pass' : sharpness > 40 ? 'warn' : 'fail',
    message: sharpness <= 40 ? 'Image may be too blurry for portal upload' : undefined,
  });

  const aspect = canvas.width / canvas.height;
  const targetAspect = spec.w / spec.h;
  items.push({
    id: 'aspect',
    label: 'Aspect ratio matches spec',
    labelHi: 'पहलू अनुपात विनिर्देश से मेल',
    status: Math.abs(aspect - targetAspect) < 0.01 ? 'pass' : 'fail',
  });

  return items;
}

export function complianceScore(items: ComplianceItem[]): { pass: number; total: number; ready: boolean } {
  const checked = items.filter((i) => i.status !== 'skip');
  const pass = checked.filter((i) => i.status === 'pass').length;
  const fails = checked.filter((i) => i.status === 'fail').length;
  return { pass, total: checked.length, ready: fails === 0 && pass >= checked.length - 1 };
}

/* ─── Print sheet (A4, 8 photos) ─── */

const A4_W = 2480;
const A4_H = 3508;

export async function generatePrintSheet(
  photoCanvas: HTMLCanvasElement,
  copies: 6 | 8 = 8,
): Promise<Blob> {
  const [sheet, ctx] = makeCanvas(A4_W, A4_H);
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, A4_W, A4_H);

  const cols = 2;
  const rows = copies === 8 ? 4 : 3;
  const margin = 120;
  const gap = 40;
  const cellW = (A4_W - margin * 2 - gap * (cols - 1)) / cols;
  const cellH = (A4_H - margin * 2 - gap * (rows - 1)) / rows;
  const scale = Math.min(cellW / photoCanvas.width, cellH / photoCanvas.height);
  const pw = photoCanvas.width * scale;
  const ph = photoCanvas.height * scale;

  let n = 0;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (n >= copies) break;
      const x = margin + c * (cellW + gap) + (cellW - pw) / 2;
      const y = margin + r * (cellH + gap) + (cellH - ph) / 2;
      ctx.strokeStyle = '#cccccc';
      ctx.lineWidth = 2;
      ctx.strokeRect(margin + c * (cellW + gap), margin + r * (cellH + gap), cellW, cellH);
      ctx.drawImage(photoCanvas, x, y, pw, ph);
      n++;
    }
  }

  ctx.strokeStyle = '#999';
  ctx.setLineDash([8, 8]);
  ctx.strokeRect(margin / 2, margin / 2, A4_W - margin, A4_H - margin);
  ctx.setLineDash([]);

  return canvasToBlob(sheet, 'image/jpeg', 0.92);
}

/* ─── Document → PDF ─── */

export async function imageFileToPdf(file: File, maxKB: number): Promise<Blob> {
  const typed = await fileToTypedBlobAsync(file);
  const img = await loadImage(typed, file.name);
  const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const dataUrl = await new Promise<string>((resolve, reject) => {
    const [c, ctx] = makeCanvas(img.width, img.height);
    ctx.drawImage(img, 0, 0);
    c.toBlob(
      (b) => {
        if (!b) return reject(new Error('Failed to encode image'));
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result as string);
        reader.onerror = () => reject(new Error('Failed to read blob'));
        reader.readAsDataURL(b);
      },
      'image/jpeg',
      0.85,
    );
  });
  pdf.addImage(dataUrl, 'JPEG', 0, 0, 210, 297);
  let blob = pdf.output('blob');
  if (blob.size / 1024 <= maxKB) return blob;

  for (let q = 0.8; q >= 0.3; q -= 0.1) {
    const [c, ctx] = makeCanvas(img.width, img.height);
    ctx.drawImage(img, 0, 0);
    const jpeg = await canvasToBlob(c, 'image/jpeg', q);
    const url = await new Promise<string>((res) => {
      const r = new FileReader();
      r.onload = () => res(r.result as string);
      r.readAsDataURL(jpeg);
    });
    const p = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
    p.addImage(url, 'JPEG', 0, 0, 210, 297);
    blob = p.output('blob');
    if (blob.size / 1024 <= maxKB) return blob;
  }
  return blob;
}

/* ─── ZIP batch download ─── */

export async function downloadZip(files: { name: string; blob: Blob }[]): Promise<Blob> {
  const zip = new JSZip();
  for (const f of files) zip.file(f.name, f.blob);
  return zip.generateAsync({ type: 'blob' });
}

/* ─── HEIC / normalize upload ─── */

export function isPdfFile(file: File): boolean {
  const type = file.type.toLowerCase();
  const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
  return type === 'application/pdf' || type === 'application/x-pdf' || ext === 'pdf';
}

/** Detect PDF even when extension/MIME are missing (checks %PDF header). */
export async function isPdfFileAsync(file: File): Promise<boolean> {
  if (isPdfFile(file)) return true;
  try {
    const head = new Uint8Array(await file.slice(0, 5).arrayBuffer());
    return head[0] === 0x25 && head[1] === 0x50 && head[2] === 0x44 && head[3] === 0x46;
  } catch {
    return false;
  }
}

export async function normalizeUploadFile(file: File): Promise<File> {
  if (await isPdfFileAsync(file)) {
    throw new Error('PDF cannot be opened as an image. Choose Document type to upload PDF files.');
  }

  const canvas = await loadImageToCanvas(file);
  const blob = await canvasToBlob(canvas, 'image/jpeg', 0.92);
  const base = file.name.replace(/\.[^.]+$/, '') || 'upload';
  return new File([blob], `${base}.jpg`, { type: 'image/jpeg' });
}

/* ─── Full processing pipeline ─── */

export interface ProcessInput {
  file: File;
  portal: PanPortal;
  fileType: PanFileType;
  edit: EditState;
  removeBackground: boolean;
  face: FaceAnalysis | null;
  sourceCanvas: HTMLCanvasElement;
}

export async function processPanFile(input: ProcessInput): Promise<{
  canvas: HTMLCanvasElement;
  blob: Blob;
  name: string;
  compliance: ComplianceItem[];
}> {
  const spec = PAN_SPECS[input.portal][input.fileType];

  if (input.fileType === 'document') {
    let blob: Blob;
    if (await isPdfFileAsync(input.file)) {
      blob = input.file;
      if (blob.size / 1024 > spec.maxKB) {
        throw new Error(`PDF exceeds ${spec.maxKB} KB limit. Use Aadhaar PDF Compressor first.`);
      }
    } else {
      blob = await imageFileToPdf(input.file, spec.maxKB);
    }
    return {
      canvas: input.sourceCanvas,
      blob,
      name: `pan-document-${input.portal}.pdf`,
      compliance: [
        {
          id: 'filesize',
          label: 'Document size within limit',
          labelHi: 'दस्तावेज़ आकार सीमा के भीतर',
          status: blob.size / 1024 <= spec.maxKB ? 'pass' : 'fail',
          message: `${(blob.size / 1024).toFixed(1)} KB / ${spec.maxKB} KB max`,
        },
      ],
    };
  }

  const rendered = renderToSpec(input.sourceCanvas, spec, input.edit);
  const blob = await encodeForSpec(rendered, spec);
  const compliance = await validateCompliance(rendered, blob, spec, input.fileType, input.face, {
    edit: input.edit,
    sourceW: input.sourceCanvas.width,
    sourceH: input.sourceCanvas.height,
  });
  const suffix = input.fileType === 'signature' ? 'signature' : 'photo';
  return {
    canvas: rendered,
    blob,
    name: `pan-${input.portal}-${suffix}.jpg`,
    compliance,
  };
}

export async function prepareSourceCanvas(
  file: File,
  fileType: PanFileType,
  removeBackground: boolean,
): Promise<{ canvas: HTMLCanvasElement; face: FaceAnalysis | null }> {
  /** Document uploads (PDF or scanned JPG) are converted only on Generate — never decoded here. */
  if (fileType === 'document') {
    const [c] = makeCanvas(1, 1);
    return { canvas: c, face: null };
  }

  const normalized = await normalizeUploadFile(file);
  let canvas = await fileToCanvas(normalized);
  let face: FaceAnalysis | null = null;

  if (fileType === 'photo') {
    face = await detectFace(canvas);
    if (removeBackground && !isBackgroundLight(canvas)) {
      try {
        canvas = await compositeOnWhite(normalized);
        face = await detectFace(canvas);
      } catch {
        /* keep original if bg removal fails */
      }
    }
  }

  return { canvas, face };
}
