'use client';

export type AudioFormat =
  | 'mp3' | 'wav' | 'flac' | 'aac' | 'm4a' | 'ogg' | 'opus'
  | 'aiff' | 'alac' | 'amr' | 'ac3' | 'pcm';

export type AudioPresetId =
  | 'balanced'
  | 'lossless'
  | 'high-quality'
  | 'mobile'
  | 'streaming'
  | 'podcast'
  | 'studio'
  | 'custom';

export interface AudioFormatPreset {
  id: AudioFormat;
  label: string;
  ext: string;
  mime: string;
  lossless?: boolean;
}

export const AUDIO_FORMATS: AudioFormatPreset[] = [
  { id: 'mp3', label: 'MP3', ext: 'mp3', mime: 'audio/mpeg' },
  { id: 'wav', label: 'WAV', ext: 'wav', mime: 'audio/wav', lossless: true },
  { id: 'flac', label: 'FLAC', ext: 'flac', mime: 'audio/flac', lossless: true },
  { id: 'aac', label: 'AAC', ext: 'aac', mime: 'audio/aac' },
  { id: 'm4a', label: 'M4A', ext: 'm4a', mime: 'audio/mp4' },
  { id: 'ogg', label: 'OGG', ext: 'ogg', mime: 'audio/ogg' },
  { id: 'opus', label: 'OPUS', ext: 'opus', mime: 'audio/opus' },
  { id: 'aiff', label: 'AIFF', ext: 'aiff', mime: 'audio/aiff', lossless: true },
  { id: 'alac', label: 'ALAC', ext: 'm4a', mime: 'audio/mp4', lossless: true },
  { id: 'amr', label: 'AMR', ext: 'amr', mime: 'audio/amr' },
  { id: 'ac3', label: 'AC3', ext: 'ac3', mime: 'audio/ac3' },
  { id: 'pcm', label: 'PCM', ext: 'wav', mime: 'audio/wav', lossless: true },
];

export const AUDIO_QUALITY_PRESETS: { id: AudioPresetId; label: string; desc: string }[] = [
  { id: 'balanced', label: 'Balanced', desc: 'MP3 192k — universal compatibility' },
  { id: 'lossless', label: 'Lossless', desc: 'FLAC — no quality loss' },
  { id: 'high-quality', label: 'High Quality', desc: 'AAC 256k — premium streaming' },
  { id: 'mobile', label: 'Mobile Optimized', desc: 'AAC 96k — small file size' },
  { id: 'streaming', label: 'Streaming', desc: 'OPUS 128k — web & Discord' },
  { id: 'podcast', label: 'Podcast Ready', desc: 'MP3 128k mono + normalize' },
  { id: 'studio', label: 'Studio Quality', desc: 'WAV 48kHz stereo' },
  { id: 'custom', label: 'Custom', desc: 'Full manual control' },
];

export const SAMPLE_RATES = [8000, 11025, 16000, 22050, 44100, 48000, 96000] as const;
export const BITRATES = ['64k', '96k', '128k', '160k', '192k', '256k', '320k'] as const;

export interface AudioEnhanceSettings {
  noiseRemoval: boolean;
  voiceEnhance: boolean;
  musicEnhance: boolean;
  bassBoost: boolean;
  vocalBoost: boolean;
  echoRemoval: boolean;
  normalize: boolean;
  autoEq: boolean;
  smartCompression: boolean;
  stereoEnhance: boolean;
  silenceRemoval: boolean;
  clarityEnhance: boolean;
  loudnessOptimize: boolean;
}

export interface AudioEditSettings {
  trimStart: string;
  trimEnd: string;
  trimStartSec: number;
  trimEndSec: number;
  fadeIn: number;
  fadeOut: number;
  volume: number;
  pitch: number;
  speed: number;
  reverse: boolean;
}

export interface AudioMetadata {
  title: string;
  artist: string;
  album: string;
  year: string;
  genre: string;
  comment: string;
}

export interface AudioConvertSettings {
  preset: AudioPresetId;
  outputFormat: AudioFormat;
  bitrate: string;
  sampleRate: number;
  channels: 0 | 1 | 2;
  enhance: AudioEnhanceSettings;
  edit: AudioEditSettings;
  metadata: AudioMetadata;
  mergeQueue: boolean;
  stripMetadata: boolean;
}

export const DEFAULT_AUDIO_ENHANCE: AudioEnhanceSettings = {
  noiseRemoval: false,
  voiceEnhance: false,
  musicEnhance: false,
  bassBoost: false,
  vocalBoost: false,
  echoRemoval: false,
  normalize: true,
  autoEq: false,
  smartCompression: true,
  stereoEnhance: false,
  silenceRemoval: false,
  clarityEnhance: false,
  loudnessOptimize: false,
};

export const DEFAULT_AUDIO_EDIT: AudioEditSettings = {
  trimStart: '',
  trimEnd: '',
  trimStartSec: 0,
  trimEndSec: 0,
  fadeIn: 0,
  fadeOut: 0,
  volume: 1,
  pitch: 1,
  speed: 1,
  reverse: false,
};

export const DEFAULT_AUDIO_METADATA: AudioMetadata = {
  title: '',
  artist: '',
  album: '',
  year: '',
  genre: '',
  comment: '',
};

export const DEFAULT_AUDIO_SETTINGS: AudioConvertSettings = {
  preset: 'balanced',
  outputFormat: 'mp3',
  bitrate: '192k',
  sampleRate: 44100,
  channels: 0,
  enhance: DEFAULT_AUDIO_ENHANCE,
  edit: DEFAULT_AUDIO_EDIT,
  metadata: DEFAULT_AUDIO_METADATA,
  mergeQueue: false,
  stripMetadata: false,
};

export function secToTimestamp(sec: number): string {
  if (!sec || sec <= 0) return '';
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  const whole = Math.floor(s);
  const frac = Math.round((s - whole) * 100);
  if (h > 0) {
    return `${h}:${String(m).padStart(2, '0')}:${String(whole).padStart(2, '0')}.${String(frac).padStart(2, '0')}`;
  }
  return `${m}:${String(whole).padStart(2, '0')}.${String(frac).padStart(2, '0')}`;
}

export function syncEditTimestamps(edit: AudioEditSettings, duration: number): AudioEditSettings {
  const trimStart = edit.trimStartSec > 0 ? secToTimestamp(edit.trimStartSec) : '';
  const trimEnd = edit.trimEndSec > 0 && edit.trimEndSec < duration ? secToTimestamp(edit.trimEndSec) : '';
  return { ...edit, trimStart, trimEnd };
}

export function applyAudioPreset(preset: AudioPresetId): Partial<AudioConvertSettings> {
  switch (preset) {
    case 'lossless':
      return { outputFormat: 'flac', bitrate: '0', sampleRate: 44100, channels: 0, enhance: { ...DEFAULT_AUDIO_ENHANCE, normalize: false } };
    case 'high-quality':
      return { outputFormat: 'aac', bitrate: '256k', sampleRate: 48000, channels: 0 };
    case 'mobile':
      return { outputFormat: 'aac', bitrate: '96k', sampleRate: 44100, channels: 0 };
    case 'streaming':
      return { outputFormat: 'opus', bitrate: '128k', sampleRate: 48000, channels: 0 };
    case 'podcast':
      return {
        outputFormat: 'mp3', bitrate: '128k', sampleRate: 44100, channels: 1,
        enhance: { ...DEFAULT_AUDIO_ENHANCE, normalize: true, voiceEnhance: true, noiseRemoval: true },
      };
    case 'studio':
      return { outputFormat: 'wav', bitrate: '0', sampleRate: 48000, channels: 2, enhance: { ...DEFAULT_AUDIO_ENHANCE, normalize: false } };
    case 'balanced':
      return { outputFormat: 'mp3', bitrate: '192k', sampleRate: 44100, channels: 0 };
  }
  return {};
}

export function mimeForAudioFormat(format: AudioFormat): string {
  return AUDIO_FORMATS.find((f) => f.id === format)?.mime ?? 'audio/mpeg';
}

export const AUDIO_ACCEPT =
  'audio/*,.mp3,.wav,.aac,.m4a,.flac,.ogg,.opus,.wma,.aiff,.amr,.ac3,.caf,.au,.ape,.dts,.mid,.midi';
