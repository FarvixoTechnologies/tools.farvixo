export type VideoCodec = 'h264' | 'h265' | 'vp9' | 'av1' | 'copy';
export type AudioCodec = 'aac' | 'mp3' | 'opus' | 'flac' | 'copy' | 'none';
export type OutputKind = 'video' | 'audio' | 'gif';

export interface FormatPreset {
  id: string;
  label: string;
  ext: string;
  kind: OutputKind;
  mime: string;
}

export interface ResolutionPreset {
  id: string;
  label: string;
  width: number;
  height: number;
}

export interface PlatformPreset {
  id: string;
  platform: string;
  label: string;
  width: number;
  height: number;
  fps: number;
  videoBitrate: string;
  audioBitrate: string;
  format: string;
}

export const INPUT_FORMATS = [
  'mp4', 'mkv', 'mov', 'avi', 'wmv', 'flv', 'webm', 'mpeg', 'mpg', '3gp', 'm4v',
  'ts', 'mts', 'm2ts', 'ogv', 'asf', 'mxf', 'vob', 'dv', 'gif',
] as const;

export const VIDEO_OUTPUT_FORMATS: FormatPreset[] = [
  { id: 'mp4', label: 'MP4 (H.264)', ext: 'mp4', kind: 'video', mime: 'video/mp4' },
  { id: 'webm', label: 'WebM (VP9)', ext: 'webm', kind: 'video', mime: 'video/webm' },
  { id: 'mkv', label: 'MKV', ext: 'mkv', kind: 'video', mime: 'video/x-matroska' },
  { id: 'mov', label: 'MOV', ext: 'mov', kind: 'video', mime: 'video/quicktime' },
  { id: 'avi', label: 'AVI', ext: 'avi', kind: 'video', mime: 'video/x-msvideo' },
  { id: 'gif', label: 'GIF', ext: 'gif', kind: 'gif', mime: 'image/gif' },
];

export const AUDIO_OUTPUT_FORMATS: FormatPreset[] = [
  { id: 'mp3', label: 'MP3', ext: 'mp3', kind: 'audio', mime: 'audio/mpeg' },
  { id: 'aac', label: 'AAC', ext: 'aac', kind: 'audio', mime: 'audio/aac' },
  { id: 'wav', label: 'WAV', ext: 'wav', kind: 'audio', mime: 'audio/wav' },
  { id: 'flac', label: 'FLAC', ext: 'flac', kind: 'audio', mime: 'audio/flac' },
  { id: 'ogg', label: 'OGG', ext: 'ogg', kind: 'audio', mime: 'audio/ogg' },
  { id: 'm4a', label: 'M4A', ext: 'm4a', kind: 'audio', mime: 'audio/mp4' },
];

export const RESOLUTION_PRESETS: ResolutionPreset[] = [
  { id: 'original', label: 'Original', width: 0, height: 0 },
  { id: '480p', label: '480p SD', width: 854, height: 480 },
  { id: '720p', label: '720p HD', width: 1280, height: 720 },
  { id: '1080p', label: '1080p Full HD', width: 1920, height: 1080 },
  { id: '2k', label: '2K (1440p)', width: 2560, height: 1440 },
  { id: '4k', label: '4K UHD', width: 3840, height: 2160 },
];

export const PLATFORM_PRESETS: PlatformPreset[] = [
  { id: 'yt-1080', platform: 'YouTube', label: 'YouTube 1080p', width: 1920, height: 1080, fps: 30, videoBitrate: '8M', audioBitrate: '192k', format: 'mp4' },
  { id: 'yt-shorts', platform: 'YouTube', label: 'YouTube Shorts', width: 1080, height: 1920, fps: 30, videoBitrate: '6M', audioBitrate: '128k', format: 'mp4' },
  { id: 'ig-reel', platform: 'Instagram', label: 'Instagram Reel', width: 1080, height: 1920, fps: 30, videoBitrate: '5M', audioBitrate: '128k', format: 'mp4' },
  { id: 'ig-feed', platform: 'Instagram', label: 'Instagram Feed', width: 1080, height: 1080, fps: 30, videoBitrate: '4M', audioBitrate: '128k', format: 'mp4' },
  { id: 'tiktok', platform: 'TikTok', label: 'TikTok', width: 1080, height: 1920, fps: 30, videoBitrate: '5M', audioBitrate: '128k', format: 'mp4' },
  { id: 'twitter', platform: 'Twitter / X', label: 'X Video', width: 1280, height: 720, fps: 30, videoBitrate: '5M', audioBitrate: '128k', format: 'mp4' },
  { id: 'linkedin', platform: 'LinkedIn', label: 'LinkedIn', width: 1920, height: 1080, fps: 30, videoBitrate: '6M', audioBitrate: '128k', format: 'mp4' },
  { id: 'whatsapp', platform: 'WhatsApp', label: 'WhatsApp Status', width: 720, height: 1280, fps: 24, videoBitrate: '2M', audioBitrate: '96k', format: 'mp4' },
];

export type ConvertMode = 'balanced' | 'quality' | 'compress' | 'custom' | 'target-size';

export interface ConvertSettings {
  outputFormat: string;
  outputKind: OutputKind;
  mode: ConvertMode;
  videoCodec: VideoCodec;
  audioCodec: AudioCodec;
  crf: number;
  videoBitrate: string;
  audioBitrate: string;
  fps: number;
  resolution: string;
  width: number;
  height: number;
  keepAspect: boolean;
  preset: string;
  stripMetadata: boolean;
  normalizeAudio: boolean;
  removeAudio: boolean;
  burnSubtitles: boolean;
  trimStart: string;
  trimEnd: string;
  rotate: 0 | 90 | 180 | 270;
  speed: number;
  flipH: boolean;
  flipV: boolean;
  gifFps: number;
  gifWidth: number;
  targetSizeMB: number;
  aiUpscale: boolean;
  aiDenoise: boolean;
  aiStabilize: boolean;
  aiHdr: boolean;
}

export const DEFAULT_CONVERT_SETTINGS: ConvertSettings = {
  outputFormat: 'mp4',
  outputKind: 'video',
  mode: 'balanced',
  videoCodec: 'h264',
  audioCodec: 'aac',
  crf: 23,
  videoBitrate: '4M',
  audioBitrate: '128k',
  fps: 0,
  resolution: 'original',
  width: 0,
  height: 0,
  keepAspect: true,
  preset: 'fast',
  stripMetadata: true,
  normalizeAudio: false,
  removeAudio: false,
  burnSubtitles: false,
  trimStart: '',
  trimEnd: '',
  rotate: 0,
  speed: 1,
  flipH: false,
  flipV: false,
  gifFps: 15,
  gifWidth: 480,
  targetSizeMB: 25,
  aiUpscale: false,
  aiDenoise: false,
  aiStabilize: false,
  aiHdr: false,
};

export const ENCODER_PRESETS = ['ultrafast', 'superfast', 'veryfast', 'faster', 'fast', 'medium', 'slow'] as const;

export function getPlatformGroups(): Map<string, PlatformPreset[]> {
  const map = new Map<string, PlatformPreset[]>();
  for (const p of PLATFORM_PRESETS) {
    if (!map.has(p.platform)) map.set(p.platform, []);
    map.get(p.platform)!.push(p);
  }
  return map;
}
