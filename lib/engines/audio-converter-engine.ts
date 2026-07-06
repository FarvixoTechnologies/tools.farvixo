'use client';

import { fetchFile } from '@ffmpeg/util';
import { extOf, getFFmpeg, readFfmpegFile } from './ffmpeg-core';
import type { AudioConvertSettings } from './audio-presets';
import { mimeForAudioFormat, syncEditTimestamps } from './audio-presets';

export interface AudioConvertResult {
  blob: Blob;
  originalSize: number;
  compressedSize: number;
  reductionPercent: number;
  format: string;
  processingTimeMs: number;
  sampleRate: number;
  channels: number;
  duration: number;
}

export interface AudioConvertReport {
  fileName: string;
  originalFormat: string;
  outputFormat: string;
  originalSize: number;
  finalSize: number;
  reductionPercent: number;
  processingTimeMs: number;
  bitrate: string;
  sampleRate: number;
  channels: number;
  duration: number;
  qualityScore: number;
}

function buildAudioFilters(settings: AudioConvertSettings): string {
  const filters: string[] = [];
  const { enhance, edit } = settings;

  if (edit.reverse) filters.push('areverse');

  if (enhance.noiseRemoval || enhance.echoRemoval) {
    filters.push('afftdn=nf=-25');
    if (enhance.echoRemoval) filters.push('highpass=f=80,lowpass=f=12000');
  }

  if (enhance.voiceEnhance || enhance.vocalBoost) {
    filters.push('highpass=f=100,lowpass=f=8000');
    if (enhance.vocalBoost) filters.push('equalizer=f=3000:t=h:width=2000:g=4');
  }

  if (enhance.musicEnhance) filters.push('equalizer=f=100:t=q:width=1:g=2,equalizer=f=8000:t=q:width=1:g=2');
  if (enhance.bassBoost) filters.push('equalizer=f=100:t=q:width=1:g=6');
  if (enhance.autoEq) filters.push('firequalizer=gain_entry=\'entry(0,0);entry(250,-2);entry(4000,2);entry(8000,1)\'');
  if (enhance.stereoEnhance) filters.push('stereotools=mlev=0.015');
  if (enhance.clarityEnhance) filters.push('highpass=f=60,equalizer=f=4000:t=h:width=2000:g=3');

  if (edit.volume !== 1 && edit.volume > 0) filters.push(`volume=${edit.volume.toFixed(2)}`);

  if (enhance.normalize || enhance.loudnessOptimize) {
    filters.push('loudnorm=I=-16:TP=-1.5:LRA=11');
  }

  if (enhance.silenceRemoval) {
    filters.push('silenceremove=stop_periods=-1:stop_duration=0.5:stop_threshold=-40dB');
  }

  if (edit.fadeIn > 0) filters.push(`afade=t=in:st=0:d=${edit.fadeIn}`);
  if (edit.fadeOut > 0) filters.push(`afade=t=out:st=0:d=${edit.fadeOut}`);

  if (edit.pitch !== 1 && edit.pitch > 0) {
    const rate = Math.round(44100 * edit.pitch);
    filters.push(`asetrate=${rate},aresample=44100,atempo=${(1 / edit.pitch).toFixed(3)}`);
  } else if (edit.speed !== 1 && edit.speed > 0) {
    const tempo = Math.min(2, Math.max(0.5, edit.speed));
    filters.push(`atempo=${tempo.toFixed(3)}`);
  }

  return filters.join(',');
}

function buildMetadataArgs(settings: AudioConvertSettings): string[] {
  if (settings.stripMetadata) return ['-map_metadata', '-1'];
  const args: string[] = [];
  const m = settings.metadata;
  if (m.title) args.push('-metadata', `title=${m.title}`);
  if (m.artist) args.push('-metadata', `artist=${m.artist}`);
  if (m.album) args.push('-metadata', `album=${m.album}`);
  if (m.year) args.push('-metadata', `date=${m.year}`);
  if (m.genre) args.push('-metadata', `genre=${m.genre}`);
  if (m.comment) args.push('-metadata', `comment=${m.comment}`);
  return args;
}

function buildOutputArgs(settings: AudioConvertSettings): string[] {
  const args: string[] = [];
  const fmt = settings.outputFormat;
  const af = buildAudioFilters(settings);
  if (af) args.push('-af', af);

  if (settings.sampleRate > 0) args.push('-ar', String(settings.sampleRate));
  if (settings.channels > 0) args.push('-ac', String(settings.channels));

  switch (fmt) {
    case 'mp3':
      args.push('-c:a', 'libmp3lame', '-b:a', settings.bitrate || '192k');
      break;
    case 'aac':
    case 'm4a':
      args.push('-c:a', 'aac', '-b:a', settings.bitrate || '192k');
      break;
    case 'flac':
    case 'alac':
      args.push('-c:a', fmt === 'alac' ? 'alac' : 'flac');
      break;
    case 'wav':
    case 'pcm':
    case 'aiff':
      args.push('-c:a', 'pcm_s16le');
      break;
    case 'ogg':
      args.push('-c:a', 'libvorbis', '-b:a', settings.bitrate || '192k');
      break;
    case 'opus':
      args.push('-c:a', 'libopus', '-b:a', settings.bitrate || '128k');
      break;
    case 'amr':
      args.push('-c:a', 'libopencore_amrnb', '-b:a', '12.2k');
      break;
    case 'ac3':
      args.push('-c:a', 'ac3', '-b:a', settings.bitrate || '192k');
      break;
    default:
      args.push('-c:a', 'libmp3lame', '-b:a', settings.bitrate || '192k');
  }

  args.push(...buildMetadataArgs(settings));
  return args;
}

function timeArgs(settings: AudioConvertSettings, duration = 0): string[] {
  const edit = duration > 0 ? syncEditTimestamps(settings.edit, duration) : settings.edit;
  const args: string[] = [];
  if (edit.trimStart) args.push('-ss', edit.trimStart);
  if (edit.trimEnd) args.push('-to', edit.trimEnd);
  return args;
}

function outExt(format: string): string {
  const map: Record<string, string> = {
    m4a: 'm4a', alac: 'm4a', pcm: 'wav', aiff: 'aiff',
  };
  return map[format] ?? format;
}

export async function convertAudio(
  file: File,
  settings: AudioConvertSettings,
  onProgress?: (p: number) => void,
  meta?: { duration: number; sampleRate: number; channels: number },
  coverArt?: File | null,
): Promise<AudioConvertResult> {
  const start = performance.now();
  const ffmpeg = await getFFmpeg(onProgress);
  const inExt = extOf(file);
  const inName = `in.${inExt}`;
  const outFmt = outExt(settings.outputFormat);
  const outName = `out.${outFmt}`;
  const duration = meta?.duration ?? 0;

  await ffmpeg.writeFile(inName, await fetchFile(file));

  const inputArgs = ['-i', inName];
  if (coverArt) {
    const coverExt = extOf(coverArt) || 'jpg';
    await ffmpeg.writeFile(`cover.${coverExt}`, await fetchFile(coverArt));
    inputArgs.push('-i', `cover.${coverExt}`);
  }

  const time = timeArgs(settings, duration);
  const outputArgs = buildOutputArgs(settings);

  if (coverArt) {
    const coverExt = extOf(coverArt) || 'jpg';
    await ffmpeg.exec([
      ...inputArgs,
      ...time,
      '-map', '0:a',
      '-map', '1:v',
      '-c:v', 'mjpeg',
      '-disposition:v:0', 'attached_pic',
      ...outputArgs,
      outName,
    ]);
  } else {
    await ffmpeg.exec([...inputArgs, ...time, ...outputArgs, outName]);
  }

  const mime = mimeForAudioFormat(settings.outputFormat);
  const blob = await readFfmpegFile(ffmpeg, outName, mime);

  return {
    blob,
    originalSize: file.size,
    compressedSize: blob.size,
    reductionPercent: Math.round((1 - blob.size / file.size) * 100),
    format: outFmt,
    processingTimeMs: performance.now() - start,
    sampleRate: settings.sampleRate || meta?.sampleRate || 44100,
    channels: settings.channels || meta?.channels || 2,
    duration,
  };
}

export async function mergeAndConvertAudio(
  files: File[],
  settings: AudioConvertSettings,
  onProgress?: (p: number) => void,
  meta?: { duration: number; sampleRate: number; channels: number },
  coverArt?: File | null,
): Promise<AudioConvertResult> {
  if (files.length === 1) return convertAudio(files[0], settings, onProgress, meta, coverArt);

  const start = performance.now();
  const ffmpeg = await getFFmpeg(onProgress);
  const totalOriginal = files.reduce((s, f) => s + f.size, 0);
  const outFmt = outExt(settings.outputFormat);
  const outName = `out.${outFmt}`;

  const listLines: string[] = [];
  for (let i = 0; i < files.length; i++) {
    const ext = extOf(files[i]);
    const name = `part${i}.${ext}`;
    await ffmpeg.writeFile(name, await fetchFile(files[i]));
    listLines.push(`file '${name}'`);
  }
  await ffmpeg.writeFile('list.txt', new TextEncoder().encode(listLines.join('\n')));

  const tempName = `temp_raw.${extOf(files[0])}`;
  await ffmpeg.exec(['-f', 'concat', '-safe', '0', '-i', 'list.txt', '-c', 'copy', tempName]);

  const inputArgs = ['-i', tempName];
  if (coverArt) {
    const coverExt = extOf(coverArt) || 'jpg';
    await ffmpeg.writeFile(`cover.${coverExt}`, await fetchFile(coverArt));
    inputArgs.push('-i', `cover.${coverExt}`);
  }

  const time = timeArgs(settings, meta?.duration ?? 0);
  const outputArgs = buildOutputArgs(settings);

  if (coverArt) {
    await ffmpeg.exec([
      ...inputArgs,
      ...time,
      '-map', '0:a',
      '-map', '1:v',
      '-c:v', 'mjpeg',
      '-disposition:v:0', 'attached_pic',
      ...outputArgs,
      outName,
    ]);
  } else {
    await ffmpeg.exec([...inputArgs, ...time, ...outputArgs, outName]);
  }

  const mime = mimeForAudioFormat(settings.outputFormat);
  const blob = await readFfmpegFile(ffmpeg, outName, mime);

  return {
    blob,
    originalSize: totalOriginal,
    compressedSize: blob.size,
    reductionPercent: Math.round((1 - blob.size / totalOriginal) * 100),
    format: outFmt,
    processingTimeMs: performance.now() - start,
    sampleRate: settings.sampleRate || meta?.sampleRate || 44100,
    channels: settings.channels || meta?.channels || 2,
    duration: meta?.duration ?? 0,
  };
}

export async function convertAudioBatch(
  files: File[],
  settings: AudioConvertSettings,
  analyses: { duration: number; sampleRate: number; channels: number; qualityScore: number }[],
  onItemProgress?: (index: number, progress: number) => void,
  onItemDone?: (index: number, result: AudioConvertResult) => void,
): Promise<AudioConvertResult[]> {
  const results: AudioConvertResult[] = [];
  for (let i = 0; i < files.length; i++) {
    const result = await convertAudio(
      files[i],
      settings,
      (p) => onItemProgress?.(i, p),
      analyses[i],
    );
    results.push(result);
    onItemDone?.(i, result);
  }
  return results;
}

export function generateAudioOutputName(inputName: string, format: string): string {
  const base = inputName.replace(/\.[^.]+$/, '');
  return `${base}.${outExt(format)}`;
}
