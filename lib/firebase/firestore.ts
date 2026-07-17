'use client';

import { type Firestore, getFirestore } from 'firebase/firestore';
import { ensureFirebaseReady } from '@/lib/firebase/app';

let db: Firestore | null = null;

export async function getFirestoreDb(): Promise<Firestore | null> {
  if (typeof window === 'undefined') return null;
  if (db) return db;
  const app = await ensureFirebaseReady();
  if (!app) return null;
  try {
    db = getFirestore(app);
    return db;
  } catch (e) {
    console.warn('[firebase] Firestore init failed:', e);
    return null;
  }
}
