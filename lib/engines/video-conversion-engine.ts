'use client';

import type { FFmpeg } from '@ffmpeg/ffmpeg';
import { fetchFile } from '@ffmpeg/util';
import { extOf, getFFmpeg, mimeForFormat, readFfmpegFile } from './ffmpeg-core';
import type { ConvertSettings } from './video-presets';
import { RESOLUTION_PRESETS } from './video-presets';

export interface ConvertResult {
  blob: Blob;
  originalSize: number;
  compressedSize: number;
  reductionPercent: number;
  format: string;
  processingTimeMs: number;
  width: number;
  height: number;
}

export interface ConvertReport {
  fileName: string;
  originalSize: number;
  finalSize: number;
  reductionPercent: number;
  processingTimeMs: number;
  format: string;
  qualityScore: number;
}

function resolveDimensions(settings: ConvertSettings, srcW: number, srcH: number): { w: number; h: number } {
  if (settings.width > 0 && settings.height > 0) {
    return { w: settings.width, h: settings.height };
  }
  const preset = RESOLUTION_PRESETS.find((r) => r.id === settings.resolution);
  if (!preset || preset.id === 'original' || !srcW || !srcH) {
    return { w: 0, h: 0 };
  }
  if (settings.keepAspect) {
    const scale = Math.min(preset.width / srcW, preset.height / srcH);
    return { w: Math.round(srcW * scale), h: Math.round(srcH * scale) };
  }
  return { w: preset.width, h: preset.height };
}

function buildScaleFilter(settings: ConvertSettings, srcW: number, srcH: number): string[] {
  const filters: string[] = [];
  const { w, h } = resolveDimensions(settings, srcW, srcH);

  if (settings.rotate === 90) filters.push('transpose=1');
  if (settings.rotate === 180) filters.push('hflip,vflip');
  if (settings.rotate === 270) filters.push('transpose=2');

  if (settings.flipH) filters.push('hflip');
  if (settings.flipV) filters.push('vflip');

  if (settings.speed !== 1 && settings.speed > 0) {
    filters.push(`setpts=${(1 / settings.speed).toFixed(4)}*PTS`);
  }

  if (settings.aiStabilize) {
    filters.push('deshake');
  }

  if (settings.aiDenoise) {
    filters.push('hqdn3d=4:3:6:4.5');
  }

  if (w > 0 && h > 0) {
    filters.push(`scale=${w}:${h}:flags=lanczos`);
  } else if (settings.aiUpscale && srcW > 0 && srcH > 0 && srcW < 1920) {
    const uw = Math.min(1920, Math.round(srcW * 1.5));
    const uh = Math.round((uw / srcW) * srcH);
    filters.push(`scale=${uw}:${uh}:flags=lanczos,unsharp=5:5:0.8:5:5:0.0`);
  }

  if (settings.aiHdr) {
    filters.push('eq=brightness=0.06:saturation=1.15:contrast=1.05');
  }

  return filters;
}

function buildVideoArgs(settings: ConvertSettings, srcW: number, srcH: number): string[] {
  const args: string[] = [];
  const vf = buildScaleFilter(settings, srcW, srcH);

  if (settings.outputKind === 'gif') {
    const gifFilters = [`fps=${settings.gifFps}`, `scale=${settings.gifWidth}:-1:flags=lanczos`];
    args.push('-vf', gifFilters.join(','), '-loop', '0');
    return args;
  }

  if (settings.outputKind === 'audio') {
    args.push('-vn');
    if (settings.audioCodec === 'mp3') args.push('-c:a', 'libmp3lame', '-b:a', settings.audioBitrate);
    else if (settings.audioCodec === 'aac') args.push('-c:a', 'aac', '-b:a', settings.audioBitrate);
    else if (settings.audioCodec === 'flac') args.push('-c:a', 'flac');
    else if (settings.audioCodec === 'opus') args.push('-c:a', 'libopus', '-b:a', settings.audioBitrate);
    else args.push('-c:a', 'aac', '-b:a', settings.audioBitrate);
    if (settings.normalizeAudio) args.push('-af', 'loudnorm=I=-16:TP=-1.5:LRA=11');
    return args;
  }

  if (vf.length) args.push('-vf', vf.join(','));

  if (settings.videoCodec === 'vp9' || settings.outputFormat === 'webm') {
    if (settings.mode === 'compress' || settings.mode === 'target-size') {
      args.push('-c:v', 'libvpx-vp9', '-crf', String(settings.crf + 8), '-b:v', '0', '-row-mt', '1');
    } else {
      args.push('-c:v', 'libvpx-vp9', '-crf', String(settings.crf + 5), '-b:v', settings.videoBitrate);
    }
  } else {
    const crf = settings.mode === 'quality' ? Math.max(18, settings.crf - 4) :
      settings.mode === 'compress' ? Math.min(32, settings.crf + 4) : settings.crf;
    if (settings.mode === 'custom' && settings.videoBitrate && settings.videoBitrate !== '0') {
      args.push('-c:v', 'libx264', '-b:v', settings.videoBitrate, '-preset', settings.preset);
    } else {
      args.push('-c:v', 'libx264', '-crf', String(crf), '-preset', settings.preset);
    }
  }

  if (settings.fps > 0) args.push('-r', String(settings.fps));

  if (settings.removeAudio) {
    args.push('-an');
  } else {
    args.push('-c:a', 'aac', '-b:a', settings.audioBitrate);
    if (settings.normalizeAudio) args.push('-af', 'loudnorm=I=-16:TP=-1.5:LRA=11');
    if (settings.speed !== 1 && settings.speed > 0) {
      args.push('-af', `atempo=${Math.min(2, Math.max(0.5, settings.speed)).toFixed(2)}`);
    }
  }

  if (settings.stripMetadata) args.push('-map_metadata', '-1');

  return args;
}

function timeArgs(settings: ConvertSettings): string[] {
  const args: string[] = [];
  if (settings.trimStart) args.push('-ss', settings.trimStart);
  if (settings.trimEnd) args.push('-to', settings.trimEnd);
  return args;
}

export async function convertVideo(
  file: File,
  settings: ConvertSettings,
  onProgress?: (p: number) => void,
  srcW = 0,
  srcH = 0,
): Promise<ConvertResult> {
  const start = performance.now();
  const ffmpeg = await getFFmpeg(onProgress);
  const inExt = extOf(file);
  const inName = `in.${inExt}`;
  const outExt = settings.outputKind === 'gif' ? 'gif' : settings.outputFormat;
  const outName = `out.${outExt}`;

  await ffmpeg.writeFile(inName, await fetchFile(file));

  const inputArgs = ['-i', inName, ...timeArgs(settings)];
  const outputArgs = buildVideoArgs(settings, srcW, srcH);
  await ffmpeg.exec([...inputArgs, ...outputArgs, outName]);

  const mime = mimeForFormat(outExt, settings.outputKind);
  const blob = await readFfmpegFile(ffmpeg, outName, mime);

  const { w, h } = resolveDimensions(settings, srcW, srcH);

  return {
    blob,
    originalSize: file.size,
    compressedSize: blob.size,
    reductionPercent: Math.round((1 - blob.size / file.size) * 100),
    format: outExt,
    processingTimeMs: performance.now() - start,
    width: w || srcW,
    height: h || srcH,
  };
}

export async function convertVideoBatch(
  files: File[],
  settings: ConvertSettings,
  analyses: { width: number; height: number }[],
  onItemProgress?: (index: number, progress: number) => void,
  onItemDone?: (index: number, result: ConvertResult) => void,
): Promise<ConvertResult[]> {
  const results: ConvertResult[] = [];
  for (let i = 0; i < files.length; i++) {
    const result = await convertVideo(
      files[i],
      settings,
      (p) => onItemProgress?.(i, p),
      analyses[i]?.width ?? 0,
      analyses[i]?.height ?? 0,
    );
    results.push(result);
    onItemDone?.(i, result);
  }
  return results;
}

export function applyPlatformPreset(
  settings: ConvertSettings,
  preset: { width: number; height: number; fps: number; videoBitrate: string; audioBitrate: string; format: string },
): ConvertSettings {
  return {
    ...settings,
    outputFormat: preset.format,
    outputKind: 'video',
    width: preset.width,
    height: preset.height,
    fps: preset.fps,
    videoBitrate: preset.videoBitrate,
    audioBitrate: preset.audioBitrate,
    resolution: 'original',
    mode: 'balanced',
  };
}

export async function fetchVideoFromUrl(url: string): Promise<File> {
  const res = await fetch(url, { mode: 'cors' });
  if (!res.ok) throw new Error('Could not fetch video from URL. Check CORS or try downloading first.');
  const blob = await res.blob();
  const name = url.split('/').pop()?.split('?')[0] || 'video.mp4';
  return new File([blob], name, { type: blob.type || 'video/mp4' });
}

export function generateOutputName(originalName: string, format: string): string {
  const base = originalName.replace(/\.[^.]+$/, '');
  return `${base}-converted.${format}`;
}
