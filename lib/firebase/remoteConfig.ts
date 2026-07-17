'use client';

import {
  fetchAndActivate,
  getRemoteConfig,
  getValue,
  type RemoteConfig,
} from 'firebase/remote-config';
import { ensureFirebaseReady } from '@/lib/firebase/app';

const DEFAULTS: Record<string, string | number | boolean> = {
  maintenance_mode: false,
  min_app_version: '1.0.0',
  premium_features_enabled: true,
  announcement_banner: '',
  theme_overrides: '',
};

let remoteConfig: RemoteConfig | null = null;
let loaded = false;
const cache = new Map<string, string>();

export async function initRemoteConfig(): Promise<boolean> {
  if (typeof window === 'undefined') return false;
  if (loaded) return true;

  // Seed local cache with defaults first (offline-safe).
  Object.entries(DEFAULTS).forEach(([k, v]) => cache.set(k, String(v)));

  try {
    const app = await ensureFirebaseReady();
    if (!app) {
      loaded = true;
      return false;
    }
    remoteConfig = getRemoteConfig(app);
    remoteConfig.settings = {
      minimumFetchIntervalMillis: process.env.NODE_ENV === 'production' ? 3_600_000 : 0,
      fetchTimeoutMillis: 10_000,
    };
    remoteConfig.defaultConfig = DEFAULTS;
    await fetchAndActivate(remoteConfig);
    Object.keys(DEFAULTS).forEach((key) => {
      cache.set(key, getValue(remoteConfig!, key).asString());
    });
    loaded = true;
    return true;
  } catch (e) {
    console.warn('[firebase] Remote Config unavailable — using defaults:', e);
    loaded = true;
    return false;
  }
}

export function getRemoteString(key: string, fallback = ''): string {
  if (cache.has(key)) return cache.get(key) ?? fallback;
  if (!remoteConfig) return String(DEFAULTS[key] ?? fallback);
  return getValue(remoteConfig, key).asString() || fallback;
}

export function getRemoteBool(key: string, fallback = false): boolean {
  const raw = getRemoteString(key, String(fallback));
  return raw === 'true' || raw === '1';
}

export function isMaintenanceMode(): boolean {
  return getRemoteBool('maintenance_mode', false);
}

export function getAnnouncementBanner(): string {
  return getRemoteString('announcement_banner', '');
}

export function arePremiumFeaturesEnabled(): boolean {
  return getRemoteBool('premium_features_enabled', true);
}
