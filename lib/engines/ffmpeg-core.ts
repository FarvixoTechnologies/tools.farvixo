'use client';

import type { FFmpeg } from '@ffmpeg/ffmpeg';

let ffmpegInstance: FFmpeg | null = null;

export type ProgressCallback = (progress: number) => void;

export async function getFFmpeg(onProgress?: ProgressCallback): Promise<FFmpeg> {
  const { FFmpeg } = await import('@ffmpeg/ffmpeg');
  const { toBlobURL } = await import('@ffmpeg/util');

  let instance = ffmpegInstance;
  if (!instance) {
    instance = new FFmpeg();
    const base = 'https://unpkg.com/@ffmpeg/core@0.12.10/dist/umd';
    await instance.load({
      coreURL: await toBlobURL(`${base}/ffmpeg-core.js`, 'text/javascript'),
      wasmURL: await toBlobURL(`${base}/ffmpeg-core.wasm`, 'application/wasm'),
    });
    ffmpegInstance = instance;
  }

  if (onProgress) {
    instance.on('progress', ({ progress }: { progress: number }) => {
      if (progress >= 0 && progress <= 1) onProgress(progress);
    });
  }

  return instance;
}

export function extOf(file: File): string {
  return (file.name.split('.').pop() || 'dat').toLowerCase();
}

export async function readFfmpegFile(ffmpeg: FFmpeg, name: string, mime: string): Promise<Blob> {
  const data = await ffmpeg.readFile(name);
  const bytes = data instanceof Uint8Array ? new Uint8Array(data) : new TextEncoder().encode(String(data));
  return new Blob([bytes], { type: mime });
}

export function mimeForFormat(format: string, kind: 'video' | 'audio' | 'gif'): string {
  if (kind === 'gif') return 'image/gif';
  if (kind === 'audio') {
    const map: Record<string, string> = {
      mp3: 'audio/mpeg', wav: 'audio/wav', ogg: 'audio/ogg', aac: 'audio/aac', flac: 'audio/flac', m4a: 'audio/mp4',
    };
    return map[format] || 'audio/mpeg';
  }
  const map: Record<string, string> = {
    mp4: 'video/mp4', webm: 'video/webm', mkv: 'video/x-matroska', mov: 'video/quicktime', avi: 'video/x-msvideo', gif: 'image/gif',
  };
  return map[format] || 'video/mp4';
}
