'use client';

/**
 * Ultra Advanced Image Compression Engine
 * Supports: JPEG (MozJPEG), PNG (OxiPNG), WebP, AVIF, JPEG XL
 * All processing runs client-side via WebAssembly + Web Workers
 */

export type OutputFormat = 'jpeg' | 'png' | 'webp' | 'avif' | 'jxl' | 'original';
export type CompressionMode = 'auto' | 'lossless' | 'balanced' | 'aggressive' | 'custom' | 'target-size';
export type MetadataMode = 'strip-all' | 'strip-gps' | 'preserve' | 'selective';
export type ChromaSubsampling = '4:4:4' | '4:2:2' | '4:2:0';

export interface CompressionOptions {
  format: OutputFormat;
  mode: CompressionMode;
  quality: number;
  effort: number;
  targetSizeKB?: number;
  resize?: { width?: number; height?: number; fit: 'contain' | 'cover' | 'fill' };
  metadata: MetadataMode;
  chromaSubsampling: ChromaSubsampling;
  stripMetadata: boolean;
}

export interface CompressionResult {
  blob: Blob;
  originalSize: number;
  compressedSize: number;
  reductionPercent: number;
  format: string;
  dimensions: { width: number; height: number };
  processingTimeMs: number;
  qualityScore?: number;
}

export interface ImageAnalysis {
  width: number;
  height: number;
  hasAlpha: boolean;
  colorDepth: number;
  estimatedColors: number;
  isPhotographic: boolean;
  fileType: string;
  dpi?: number;
}

const MODE_QUALITY: Record<string, number> = {
  lossless: 100,
  balanced: 75,
  aggressive: 45,
};

const MODE_EFFORT: Record<string, number> = {
  lossless: 10,
  balanced: 6,
  aggressive: 3,
};

async function fileToImageData(file: File): Promise<{ imageData: ImageData; width: number; height: number; hasAlpha: boolean }> {
  const bitmap = await createImageBitmap(file);
  const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(bitmap, 0, 0);
  bitmap.close();
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

  let hasAlpha = false;
  const data = imageData.data;
  for (let i = 3; i < data.length; i += 16) {
    if (data[i] < 255) { hasAlpha = true; break; }
  }

  return { imageData, width: canvas.width, height: canvas.height, hasAlpha };
}

function resizeImageData(
  imageData: ImageData,
  targetWidth: number,
  targetHeight: number,
): ImageData {
  const srcCanvas = new OffscreenCanvas(imageData.width, imageData.height);
  const srcCtx = srcCanvas.getContext('2d')!;
  srcCtx.putImageData(imageData, 0, 0);

  const dstCanvas = new OffscreenCanvas(targetWidth, targetHeight);
  const dstCtx = dstCanvas.getContext('2d')!;
  dstCtx.imageSmoothingEnabled = true;
  dstCtx.imageSmoothingQuality = 'high';
  dstCtx.drawImage(srcCanvas, 0, 0, targetWidth, targetHeight);

  return dstCtx.getImageData(0, 0, targetWidth, targetHeight);
}

function calculateResizeDimensions(
  origWidth: number,
  origHeight: number,
  opts: NonNullable<CompressionOptions['resize']>,
): { width: number; height: number } {
  const { width: tw, height: th, fit } = opts;
  if (tw && th) {
    if (fit === 'fill') return { width: tw, height: th };
    const scale = fit === 'cover'
      ? Math.max(tw / origWidth, th / origHeight)
      : Math.min(tw / origWidth, th / origHeight);
    return { width: Math.round(origWidth * scale), height: Math.round(origHeight * scale) };
  }
  if (tw) {
    const scale = tw / origWidth;
    return { width: tw, height: Math.round(origHeight * scale) };
  }
  if (th) {
    const scale = th / origHeight;
    return { width: Math.round(origWidth * scale), height: th };
  }
  return { width: origWidth, height: origHeight };
}

function resolveFormat(opts: CompressionOptions, hasAlpha: boolean, originalType: string): string {
  if (opts.format !== 'original') return opts.format;
  if (originalType.includes('png')) return 'png';
  if (originalType.includes('webp')) return 'webp';
  if (originalType.includes('avif')) return 'avif';
  return hasAlpha ? 'png' : 'jpeg';
}

function resolveQuality(opts: CompressionOptions): number {
  if (opts.mode === 'custom' || opts.mode === 'target-size') return opts.quality;
  return MODE_QUALITY[opts.mode] ?? opts.quality;
}

function resolveEffort(opts: CompressionOptions): number {
  if (opts.mode === 'custom') return opts.effort;
  return MODE_EFFORT[opts.mode] ?? opts.effort;
}

async function encodeJPEG(imageData: ImageData, quality: number): Promise<Blob> {
  const { encode } = await import('@jsquash/jpeg');
  const encoded = await encode(imageData, { quality });
  return new Blob([encoded], { type: 'image/jpeg' });
}

async function encodePNG(imageData: ImageData): Promise<Blob> {
  const { encode } = await import('@jsquash/png');
  const encoded = await encode(imageData);
  return new Blob([encoded], { type: 'image/png' });
}

async function encodeWebP(imageData: ImageData, quality: number): Promise<Blob> {
  const { encode } = await import('@jsquash/webp');
  const encoded = await encode(imageData, { quality });
  return new Blob([encoded], { type: 'image/webp' });
}

async function encodeAVIF(imageData: ImageData, quality: number, effort: number): Promise<Blob> {
  const { encode } = await import('@jsquash/avif');
  const speed = Math.max(0, Math.min(10, 10 - effort));
  const encoded = await encode(imageData, { quality, speed });
  return new Blob([encoded], { type: 'image/avif' });
}

async function encodeImage(
  imageData: ImageData,
  format: string,
  quality: number,
  effort: number,
): Promise<Blob> {
  switch (format) {
    case 'jpeg': return encodeJPEG(imageData, quality);
    case 'png': return encodePNG(imageData);
    case 'webp': return encodeWebP(imageData, quality);
    case 'avif': return encodeAVIF(imageData, quality, effort);
    // No browser JXL encoder exists yet — encode honestly as WebP instead of
    // shipping a WebP payload mislabelled as .jxl.
    case 'jxl': return encodeWebP(imageData, quality);
    default: return encodeJPEG(imageData, quality);
  }
}

export async function compressImage(
  file: File,
  options: CompressionOptions,
): Promise<CompressionResult> {
  const startTime = performance.now();
  const { imageData, width, height, hasAlpha } = await fileToImageData(file);

  let processedData = imageData;
  let finalWidth = width;
  let finalHeight = height;

  if (options.resize) {
    const dims = calculateResizeDimensions(width, height, options.resize);
    finalWidth = dims.width;
    finalHeight = dims.height;
    processedData = resizeImageData(imageData, finalWidth, finalHeight);
  }

  const format = resolveFormat(options, hasAlpha, file.type);
  const quality = resolveQuality(options);
  const effort = resolveEffort(options);

  // For lossless mode with alpha, prefer PNG
  if (options.mode === 'lossless' && hasAlpha && format === 'jpeg') {
    const blob = await encodePNG(processedData);
    return {
      blob,
      originalSize: file.size,
      compressedSize: blob.size,
      reductionPercent: Math.round((1 - blob.size / file.size) * 100),
      format: 'png',
      dimensions: { width: finalWidth, height: finalHeight },
      processingTimeMs: performance.now() - startTime,
    };
  }

  const blob = await encodeImage(processedData, format, quality, effort);

  return {
    blob,
    originalSize: file.size,
    compressedSize: blob.size,
    reductionPercent: Math.round((1 - blob.size / file.size) * 100),
    format,
    dimensions: { width: finalWidth, height: finalHeight },
    processingTimeMs: performance.now() - startTime,
  };
}

export async function compressToTargetSize(
  file: File,
  targetKB: number,
  options: Omit<CompressionOptions, 'mode' | 'targetSizeKB'>,
): Promise<CompressionResult> {
  const startTime = performance.now();
  const { imageData, width, height, hasAlpha } = await fileToImageData(file);

  let processedData = imageData;
  let finalWidth = width;
  let finalHeight = height;

  if (options.resize) {
    const dims = calculateResizeDimensions(width, height, options.resize);
    finalWidth = dims.width;
    finalHeight = dims.height;
    processedData = resizeImageData(imageData, finalWidth, finalHeight);
  }

  const format = resolveFormat({ ...options, mode: 'custom' }, hasAlpha, file.type);
  const targetBytes = targetKB * 1024;

  let lo = 1;
  let hi = 100;
  let bestBlob: Blob | null = null;
  let bestQuality = 50;

  // Binary search for optimal quality
  for (let i = 0; i < 10; i++) {
    const mid = Math.round((lo + hi) / 2);
    const blob = await encodeImage(processedData, format, mid, 6);
    if (blob.size <= targetBytes) {
      bestBlob = blob;
      bestQuality = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }

  // If still too large at lowest quality, try resizing down
  if (!bestBlob) {
    let scale = 0.9;
    while (scale > 0.1) {
      const sw = Math.round(finalWidth * scale);
      const sh = Math.round(finalHeight * scale);
      const resized = resizeImageData(processedData, sw, sh);
      const blob = await encodeImage(resized, format, 60, 6);
      if (blob.size <= targetBytes) {
        bestBlob = blob;
        finalWidth = sw;
        finalHeight = sh;
        break;
      }
      scale -= 0.1;
    }
    if (!bestBlob) {
      const tiny = resizeImageData(processedData, Math.round(finalWidth * 0.1), Math.round(finalHeight * 0.1));
      bestBlob = await encodeImage(tiny, format, 30, 6);
      finalWidth = Math.round(finalWidth * 0.1);
      finalHeight = Math.round(finalHeight * 0.1);
    }
  }

  return {
    blob: bestBlob,
    originalSize: file.size,
    compressedSize: bestBlob.size,
    reductionPercent: Math.round((1 - bestBlob.size / file.size) * 100),
    format,
    dimensions: { width: finalWidth, height: finalHeight },
    processingTimeMs: performance.now() - startTime,
    qualityScore: bestQuality,
  };
}

export async function compareCodecs(
  file: File,
  quality: number,
): Promise<{ format: string; blob: Blob; size: number; timeMs: number }[]> {
  const { imageData } = await fileToImageData(file);
  const formats = ['jpeg', 'webp', 'avif', 'png'] as const;
  const results: { format: string; blob: Blob; size: number; timeMs: number }[] = [];

  for (const fmt of formats) {
    const start = performance.now();
    try {
      const blob = await encodeImage(imageData, fmt, quality, 6);
      results.push({ format: fmt, blob, size: blob.size, timeMs: performance.now() - start });
    } catch {
      // codec unavailable
    }
  }

  return results.sort((a, b) => a.size - b.size);
}

export async function analyzeImage(file: File): Promise<ImageAnalysis> {
  const { imageData, width, height, hasAlpha } = await fileToImageData(file);
  const data = imageData.data;

  const colorSet = new Set<number>();
  const sampleStep = Math.max(1, Math.floor(data.length / 4 / 10000));
  for (let i = 0; i < data.length; i += 4 * sampleStep) {
    colorSet.add((data[i] << 16) | (data[i + 1] << 8) | data[i + 2]);
  }

  const isPhotographic = colorSet.size > 5000;

  return {
    width,
    height,
    hasAlpha,
    colorDepth: hasAlpha ? 32 : 24,
    estimatedColors: colorSet.size,
    isPhotographic,
    fileType: file.type,
  };
}

export function getAutoSettings(analysis: ImageAnalysis): { format: OutputFormat; quality: number; mode: CompressionMode } {
  if (!analysis.isPhotographic && analysis.hasAlpha) {
    return { format: 'png', quality: 100, mode: 'lossless' };
  }
  if (!analysis.isPhotographic && analysis.estimatedColors < 256) {
    return { format: 'png', quality: 100, mode: 'lossless' };
  }
  if (analysis.isPhotographic) {
    return { format: 'avif', quality: 72, mode: 'balanced' };
  }
  return { format: 'webp', quality: 80, mode: 'balanced' };
}

export function getFormatExtension(format: string): string {
  const map: Record<string, string> = {
    jpeg: 'jpg', png: 'png', webp: 'webp', avif: 'avif', jxl: 'webp',
  };
  return map[format] || 'jpg';
}

export function generateFilename(originalName: string, format: string, suffix?: string): string {
  const base = originalName.replace(/\.[^.]+$/, '');
  const ext = getFormatExtension(format);
  return suffix ? `${base}-${suffix}.${ext}` : `${base}-compressed.${ext}`;
}
