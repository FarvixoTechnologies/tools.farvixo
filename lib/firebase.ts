/**
 * Farvixo Firebase Production 2026 — public barrel (tree-shake friendly).
 * Prefer importing specific modules for smaller bundles.
 */
export { firebaseConfig, isFirebaseConfigured } from '@/lib/firebase/config';
export { getFirebaseApp, ensureFirebaseReady } from '@/lib/firebase/app';
export { activateAppCheck, getAppCheck } from '@/lib/firebase/appCheck';
export {
  getFirebaseAnalytics,
  trackFirebaseEvent,
  trackPageView,
  trackSessionStart,
  setFirebaseUserId,
} from '@/lib/firebase/analytics';
export {
  initRemoteConfig,
  getRemoteString,
  getRemoteBool,
  isMaintenanceMode,
  getAnnouncementBanner,
} from '@/lib/firebase/remoteConfig';
export {
  getFcmToken,
  registerFcmTokenWithSupabase,
  listenForegroundMessages,
} from '@/lib/firebase/messaging';
export { getFirestoreDb } from '@/lib/firebase/firestore';
export { getFirebaseStorage, storageRef } from '@/lib/firebase/storage';
export { getFirebasePerformance } from '@/lib/firebase/performance';
