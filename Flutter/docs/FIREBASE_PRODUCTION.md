# Farvixo Firebase Production (2026)

**Project ID:** `farvixo-production-2026`  
**Android package:** `com.farvixo.app`  
**Web app ID:** `1:282376161241:web:d0bca9dcc89c299e1f7bc8`  
**Auth source of truth:** Supabase (Flutter + Web) — **do not enable Firebase Auth for app login**

## What Firebase is used for

| Product | Role |
|---|---|
| Analytics | Funnel events (`login`, `tool_open`, …) + Web GA (`G-VTGV5YE47C`) |
| Crashlytics | Flutter / platform / API errors |
| Cloud Messaging | Push + topics `all_users`, `plan_free`, `plan_pro` |
| Remote Config | `maintenance_mode`, `min_app_version`, banners, premium toggle |
| App Check | Android Play Integrity (debug provider in debug builds) |
| Firestore | Optional `users/{supabaseUid}` mirror only |
| Storage | Path helpers: `avatars/`, `documents/`, `uploads/`, `images/`, `temporary/` |

## App files

- `android/app/google-services.json` — 2026 Android client (includes OAuth client id)
- `lib/firebase_options.dart` — Android + Web options
- `lib/core/firebase/firebase_bootstrap.dart` — ordered init
- `lib/services/*` — Analytics, Crashlytics, FCM, Remote Config, App Check, mirror
- Web (Next.js): `lib/firebase/config.ts`, `lib/firebase/client.ts`, `components/FirebaseAnalyticsInit.tsx`
- `firebase/firestore.rules`, `storage.rules`, `remote_config_defaults.json`

## Web firebaseConfig

```js
{
  apiKey: "AIzaSyCW6-ik0yBIkrHH2ScoZFEFD3u5qhUS5SU",
  authDomain: "farvixo-production-2026.firebaseapp.com",
  projectId: "farvixo-production-2026",
  storageBucket: "farvixo-production-2026.firebasestorage.app",
  messagingSenderId: "282376161241",
  appId: "1:282376161241:web:d0bca9dcc89c299e1f7bc8",
  measurementId: "G-VTGV5YE47C"
}
```

## Firebase Console checklist

1. Project `farvixo-production-2026` selected
2. Android app `com.farvixo.app` registered; SHA-1/256 added for Play Integrity
3. Web app registered (Farvixo Tools Web)
4. Analytics enabled
5. Crashlytics enabled (first crash report after release build)
6. Cloud Messaging API enabled
7. Remote Config parameters created (match `remote_config_defaults.json`)
8. App Check → Play Integrity registered for Android
9. Deploy `firestore.rules` + `storage.rules`
10. **Do not** rely on Firebase Auth for Farvixo login

## Deep links (FCM)

Send data payload with `path` or `deep_link` (e.g. `/tools/pdf-to-word`). Handled by `NotificationService`.

## Note on Firestore mirror writes

Rules allow create/update on `users/{userId}` only when `data.id == userId` and `source == 'supabase'`. **Turn on App Check enforcement** in Firebase Console before production. Prefer Admin SDK / Edge Function sync for stricter security.
