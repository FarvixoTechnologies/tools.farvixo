import { govPresetsForCompressor } from '@/lib/engines/gov-photo-engine';

export interface SocialPreset {
  id: string;
  platform: string;
  label: string;
  width: number;
  height: number;
  maxKB?: number;
  format: 'jpeg' | 'png' | 'webp';
}

export interface GovPreset {
  id: string;
  label: string;
  width: number;
  height: number;
  minKB?: number;
  maxKB: number;
  format: 'jpeg';
  description: string;
}

export const socialPresets: SocialPreset[] = [
  // Instagram
  { id: 'ig-post', platform: 'Instagram', label: 'Post (1080×1080)', width: 1080, height: 1080, format: 'jpeg' },
  { id: 'ig-story', platform: 'Instagram', label: 'Story (1080×1920)', width: 1080, height: 1920, format: 'jpeg' },
  { id: 'ig-profile', platform: 'Instagram', label: 'Profile (320×320)', width: 320, height: 320, format: 'jpeg' },
  { id: 'ig-reel-cover', platform: 'Instagram', label: 'Reel Cover (1080×1920)', width: 1080, height: 1920, format: 'jpeg' },

  // Facebook
  { id: 'fb-post', platform: 'Facebook', label: 'Post (1200×630)', width: 1200, height: 630, format: 'jpeg' },
  { id: 'fb-cover', platform: 'Facebook', label: 'Cover (820×312)', width: 820, height: 312, format: 'jpeg' },
  { id: 'fb-profile', platform: 'Facebook', label: 'Profile (170×170)', width: 170, height: 170, format: 'jpeg' },
  { id: 'fb-event', platform: 'Facebook', label: 'Event Cover (1920×1005)', width: 1920, height: 1005, format: 'jpeg' },

  // Twitter / X
  { id: 'x-post', platform: 'Twitter / X', label: 'Post (1600×900)', width: 1600, height: 900, format: 'jpeg' },
  { id: 'x-header', platform: 'Twitter / X', label: 'Header (1500×500)', width: 1500, height: 500, format: 'jpeg' },
  { id: 'x-profile', platform: 'Twitter / X', label: 'Profile (400×400)', width: 400, height: 400, format: 'jpeg' },

  // YouTube
  { id: 'yt-thumbnail', platform: 'YouTube', label: 'Thumbnail (1280×720)', width: 1280, height: 720, maxKB: 2048, format: 'jpeg' },
  { id: 'yt-banner', platform: 'YouTube', label: 'Channel Art (2560×1440)', width: 2560, height: 1440, format: 'jpeg' },

  // LinkedIn
  { id: 'li-post', platform: 'LinkedIn', label: 'Post (1200×627)', width: 1200, height: 627, format: 'jpeg' },
  { id: 'li-banner', platform: 'LinkedIn', label: 'Banner (1584×396)', width: 1584, height: 396, format: 'jpeg' },
  { id: 'li-profile', platform: 'LinkedIn', label: 'Profile (400×400)', width: 400, height: 400, format: 'jpeg' },

  // WhatsApp
  { id: 'wa-profile', platform: 'WhatsApp', label: 'Profile (500×500)', width: 500, height: 500, format: 'jpeg' },
  { id: 'wa-status', platform: 'WhatsApp', label: 'Status (1080×1920)', width: 1080, height: 1920, format: 'jpeg' },

  // Pinterest
  { id: 'pin-standard', platform: 'Pinterest', label: 'Standard Pin (1000×1500)', width: 1000, height: 1500, format: 'jpeg' },

  // TikTok
  { id: 'tt-cover', platform: 'TikTok', label: 'Video Cover (1080×1920)', width: 1080, height: 1920, format: 'jpeg' },
];

export const govPresets: GovPreset[] = govPresetsForCompressor();

export const responsiveSizes = [150, 320, 640, 768, 1024, 1280, 1920, 2560];

export function getPresetsByPlatform(): Map<string, SocialPreset[]> {
  const map = new Map<string, SocialPreset[]>();
  for (const p of socialPresets) {
    if (!map.has(p.platform)) map.set(p.platform, []);
    map.get(p.platform)!.push(p);
  }
  return map;
}
