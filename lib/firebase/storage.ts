'use client';

import { type FirebaseStorage, getStorage, ref } from 'firebase/storage';
import { ensureFirebaseReady } from '@/lib/firebase/app';

let storage: FirebaseStorage | null = null;

export async function getFirebaseStorage(): Promise<FirebaseStorage | null> {
  if (typeof window === 'undefined') return null;
  if (storage) return storage;
  const app = await ensureFirebaseReady();
  if (!app) return null;
  try {
    storage = getStorage(app);
    return storage;
  } catch (e) {
    console.warn('[firebase] Storage init failed:', e);
    return null;
  }
}

export async function storageRef(path: string) {
  const s = await getFirebaseStorage();
  if (!s) return null;
  return ref(s, path);
}
