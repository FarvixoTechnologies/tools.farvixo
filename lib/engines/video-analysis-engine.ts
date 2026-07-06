'use client';

export interface VideoAnalysis {
  fileName: string;
  fileSize: number;
  duration: number;
  width: number;
  height: number;
  aspectRatio: string;
  estimatedBitrateKbps: number;
  estimatedFps: number;
  hasAudio: boolean;
  orientation: 'landscape' | 'portrait' | 'square';
  format: string;
  isHdr: boolean;
  qualityScore: number;
  suggestions: string[];
}

function formatAspect(w: number, h: number): string {
  if (!w || !h) return '—';
  const gcd = (a: number, b: number): number => (b === 0 ? a : gcd(b, a % b));
  const d = gcd(w, h);
  return `${w / d}:${h / d}`;
}

function scoreQuality(width: number, height: number, bitrateKbps: number): number {
  const pixels = width * height;
  if (!pixels || !bitrateKbps) return 70;
  const bpp = (bitrateKbps * 1000) / (pixels * 30);
  if (bpp > 0.15) return 95;
  if (bpp > 0.08) return 85;
  if (bpp > 0.04) return 72;
  return 58;
}

function buildSuggestions(a: Omit<VideoAnalysis, 'suggestions' | 'qualityScore'>): string[] {
  const tips: string[] = [];
  if (a.width > 1920 || a.height > 1080) {
    tips.push('4K/2K detected — consider 1080p output for web sharing to reduce size.');
  }
  if (a.estimatedBitrateKbps > 8000) {
    tips.push('High bitrate — Compress mode can cut size 40–70% with minimal visible loss.');
  }
  if (a.duration > 600 && a.fileSize > 100 * 1024 * 1024) {
    tips.push('Large file — trim unused sections or use H.264 CRF 26–28 for email-friendly size.');
  }
  if (a.orientation === 'portrait') {
    tips.push('Portrait video — use Instagram/TikTok presets for optimal platform delivery.');
  }
  if (!a.hasAudio) {
    tips.push('No audio track — enable "Remove audio" to speed up conversion.');
  }
  if (tips.length === 0) {
    tips.push('Balanced MP4 (H.264 + AAC) is recommended for universal compatibility.');
  }
  return tips;
}

export async function analyzeVideoFile(file: File): Promise<VideoAnalysis> {
  const ext = (file.name.split('.').pop() || 'mp4').toLowerCase();

  const meta = await new Promise<{
    duration: number;
    width: number;
    height: number;
    hasAudio: boolean;
  }>((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement('video');
    video.preload = 'metadata';
    video.muted = true;
    video.playsInline = true;

    const cleanup = () => URL.revokeObjectURL(url);

    video.onloadedmetadata = () => {
      const duration = Number.isFinite(video.duration) ? video.duration : 0;
      const width = video.videoWidth || 0;
      const height = video.videoHeight || 0;
      cleanup();
      resolve({ duration, width, height, hasAudio: true });
    };

    video.onerror = () => {
      cleanup();
      reject(new Error('Could not read video metadata. The file may be corrupted or unsupported.'));
    };

    video.src = url;
  });

  const bitrateKbps = meta.duration > 0
    ? Math.round((file.size * 8) / meta.duration / 1000)
    : 0;

  const orientation: VideoAnalysis['orientation'] =
    meta.width > meta.height ? 'landscape' :
    meta.width < meta.height ? 'portrait' : 'square';

  const base = {
    fileName: file.name,
    fileSize: file.size,
    duration: meta.duration,
    width: meta.width,
    height: meta.height,
    aspectRatio: formatAspect(meta.width, meta.height),
    estimatedBitrateKbps: bitrateKbps,
    estimatedFps: 30,
    hasAudio: meta.hasAudio,
    orientation,
    format: ext.toUpperCase(),
    isHdr: meta.width >= 3840,
  };

  return {
    ...base,
    qualityScore: scoreQuality(meta.width, meta.height, bitrateKbps),
    suggestions: buildSuggestions(base),
  };
}

export interface AIVideoRecommendation {
  recommendedFormat: string;
  recommendedResolution: string;
  recommendedMode: 'balanced' | 'quality' | 'compress';
  crf: number;
  explanation: string;
}

export function getAutoRecommendation(analysis: VideoAnalysis): AIVideoRecommendation {
  if (analysis.estimatedBitrateKbps > 6000 || analysis.fileSize > 80 * 1024 * 1024) {
    return {
      recommendedFormat: 'mp4',
      recommendedResolution: analysis.width > 1920 ? '1080p' : 'original',
      recommendedMode: 'compress',
      crf: 26,
      explanation: 'High bitrate/large file — compress with H.264 CRF 26 for best size reduction.',
    };
  }
  if (analysis.orientation === 'portrait') {
    return {
      recommendedFormat: 'mp4',
      recommendedResolution: '1080p',
      recommendedMode: 'balanced',
      crf: 23,
      explanation: 'Portrait content — MP4 at 1080p optimized for social platforms.',
    };
  }
  return {
    recommendedFormat: 'mp4',
    recommendedResolution: 'original',
    recommendedMode: 'balanced',
    crf: 23,
    explanation: 'Balanced MP4 (H.264 + AAC) recommended for quality and compatibility.',
  };
}

const SESSION_KEY = 'toolnest-video-converter-session';

export async function extractVideosFromZip(zipFile: File): Promise<File[]> {
  const JSZip = (await import('jszip')).default;
  const zip = await JSZip.loadAsync(await zipFile.arrayBuffer());
  const re = /\.(mp4|mkv|mov|avi|wmv|flv|webm|mpeg|mpg|3gp|m4v|ts|mts|m2ts|ogv|asf|mxf|vob|dv|gif)$/i;
  const out: File[] = [];
  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir || !re.test(path)) continue;
    const blob = await entry.async('blob');
    const name = path.split('/').pop() || 'video.mp4';
    out.push(new File([blob], name, { type: blob.type || 'video/mp4' }));
  }
  return out;
}

export function saveVideoSession(names: string[]): void {
  try {
    const prev = loadVideoSession();
    const merged = [...names, ...prev].slice(0, 12);
    localStorage.setItem(SESSION_KEY, JSON.stringify([...new Set(merged)]));
  } catch { /* ignore */ }
}

export function loadVideoSession(): string[] {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}
