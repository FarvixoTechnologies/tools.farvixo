# Farvixo — Flutter Supabase layer

Production project: **`bujpwwxanaejfcyuigth`**
(`https://bujpwwxanaejfcyuigth.supabase.co`)

`schema.sql` is already applied (migration `flutter_app_sync_layer` + harden).
It sits safely next to the web/admin schema.

## Status (done)

| Piece | Status |
| --- | --- |
| `user_settings` / `user_favorites` / `user_tool_stats` / `user_devices` | Live + RLS |
| `record_tool_use()` | Live (authenticated only) |
| `notifications.is_read` ↔ `read` sync | Live |
| `avatars` bucket policies | Live |
| Realtime on `notifications` | Live |
| Flutter app sync services | Wired |
| `Flutter/.env` | Created locally (gitignored) |

## One manual step — Auth redirect

In [Supabase Dashboard → Authentication → URL Configuration](https://supabase.com/dashboard/project/bujpwwxanaejfcyuigth/auth/url-configuration) add:

```
com.farvixo.app://login-callback
```

(Android intent-filter is already in `AndroidManifest.xml`.)

Also allow your site URL / additional redirects used by the web app.

## Local run

```bash
cd Flutter
# .env already has SUPABASE_URL + SUPABASE_ANON_KEY (gitignored)
flutter pub get
flutter run
```

Without `.env` / dart-defines the app still runs offline (guest mode).

## Table map

| Flutter feature | Table / RPC |
| --- | --- |
| Settings | `user_settings` |
| Favorites | `user_favorites` |
| Recently used | `user_tool_stats` + `record_tool_use` |
| Notifications | `notifications` (`is_read`) |
| Devices | `user_devices` |
| Profile / avatar | `profiles` + `avatars` |

Web tables (`settings`, `favorites`, `tool_usage`, `devices`) are untouched.
