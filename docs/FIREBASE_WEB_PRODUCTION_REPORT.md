# Farvixo Web — Firebase Production 2026 Report

**Date:** 2026-07-17  
**Site:** https://tools.farvixo.com  
**Firebase project:** `farvixo-production-2026`  
**Auth SoT:** Supabase (unchanged)

## Deliverables

| File | Status |
|---|---|
| `lib/firebase/config.ts` | Done — env-only, Production 2026 |
| `lib/firebase/app.ts` | Done — single `initializeApp` |
| `lib/firebase/appCheck.ts` | Done — reCAPTCHA v3 |
| `lib/firebase/analytics.ts` | Done |
| `lib/firebase/remoteConfig.ts` | Done — defaults + cache |
| `lib/firebase/messaging.ts` | Done — FCM + Supabase sync |
| `lib/firebase/firestore.ts` | Done |
| `lib/firebase/storage.ts` | Done |
| `lib/firebase/performance.ts` | Done (prod only) |
| `lib/firebase.ts` | Barrel export |
| `lib/firebase/client.ts` | Compat shim |
| `.env.production` | Done |
| `public/firebase-messaging-sw.js` | Done |
| `app/api/push/register/route.ts` | Done |
| `components/FirebaseProvider.tsx` | Done |

Obsolete `FirebaseAnalyticsInit.tsx` removed.

## Config (Web)

```
apiKey: AIzaSyCW6-ik0yBIkrHH2ScoZFEFD3u5qhUS5SU
authDomain: farvixo-production-2026.firebaseapp.com
projectId: farvixo-production-2026
storageBucket: farvixo-production-2026.firebasestorage.app
messagingSenderId: 282376161241
appId: 1:282376161241:web:d0bca9dcc89c299e1f7bc8
measurementId: G-VTGV5YE47C
```

Next.js requires `NEXT_PUBLIC_` for browser env. Aliases without prefix are also read server-side via `config.ts`.

## Console checklist (you must complete)

1. **App Check → Web → reCAPTCHA v3** — create site key → set `NEXT_PUBLIC_FIREBASE_RECAPTCHA_SITE_KEY` on Cloudflare
2. **Cloud Messaging → Web Push certificates** — generate VAPID → set `NEXT_PUBLIC_FIREBASE_VAPID_KEY`
3. Copy all `NEXT_PUBLIC_FIREBASE_*` from `.env.production` into Cloudflare Pages env → Redeploy
4. Deploy Firestore / Storage rules from `Flutter/firebase/` (or repo `firebase/` if mirrored)
5. Enable Analytics + Performance in Firebase Console

## Validation matrix

| Check | Code | Needs Console / env |
|---|---|---|
| Analytics | `trackFirebaseEvent` + `page_view` on route change | Measurement ID live |
| App Check | Activates before other products | reCAPTCHA site key |
| Remote Config | Defaults + fetch/activate | Optional RC params |
| FCM token | Permission + SW + `/api/push/register` | VAPID key + logged-in user |
| Firestore | `getFirestoreDb()` | Rules / App Check |
| Storage | `getFirebaseStorage()` | Rules / App Check |
| No double init | Single app singleton | — |
| No firebase_auth | Confirmed | — |

## Analytics events

`page_view` · `session_start` · `tool_open` · `tool_complete` · `login` · `signup` · `search` · `download` · `share` · `favorite` · `ai_request` · `ai_response` · `errors`

Use `trackEvent()` from `lib/analytics-client.ts` (writes Supabase + Firebase).

## Security notes

- No service-account / private keys in frontend
- App Check site key + Firebase web config are public by design
- FCM tokens stored in Supabase `push_tokens` (fallback `devices`) for authenticated users only

## Build

`npm run build` — **passed** (2026-07-17)

## Lighthouse

Run after Cloudflare deploy with App Check + Analytics live:

```bash
npx lighthouse https://tools.farvixo.com --only-categories=performance,accessibility,best-practices,seo --quiet
```

Target: Mobile ≥ 90 (existing site target). Firebase lazy-imports keep initial JS lean.
