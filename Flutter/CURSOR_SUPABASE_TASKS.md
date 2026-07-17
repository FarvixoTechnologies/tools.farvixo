# Cursor task: finish the Supabase integration

**How to use this file in Cursor:** open the project, then in Cursor Chat
(Agent mode) type `@CURSOR_SUPABASE_TASKS.md complete all tasks` (or paste this
file). Work top-to-bottom, one task per commit. Do **not** break the offline
path — the app must still run with no Supabase keys.

---

## Context (already done — do not redo)

- `supabase/schema.sql` — full DB schema (profiles, user_settings,
  user_favorites, tool_usage, notifications, user_devices), RLS, `handle_new_user`
  trigger, `record_tool_use()` RPC, `avatars` storage bucket. **Apply it first**
  in the Supabase SQL editor.
- `lib/services/supabase_service.dart` — guarded client (`SupabaseService.client`,
  `.isAvailable`).
- `lib/providers/auth_provider.dart` — email / OAuth / OTP / biometric / guest auth.
- `lib/services/settings_sync_service.dart` — `push`/`pull` for `user_settings`.
- `lib/providers/app_settings_provider.dart` — sound/animations toggles (persisted).
- Local persistence lives in `lib/services/storage_service.dart` (SharedPreferences).

**Golden rules for every task**
1. When `SupabaseService.client == null` or the user `isGuest`, fall back to the
   existing local behavior (no crashes, no exceptions surfaced to UI).
2. Never bypass RLS — always filter by `auth.uid()` / current user id.
3. Keep SharedPreferences as the offline cache; Supabase is the source of truth
   when signed in. On conflict, prefer the most recently changed value.
4. Wrap all network calls in try/catch and `debugPrint` failures.

---

## Task 1 — Hydrate settings from Supabase on login

**Goal:** when a signed-in session is restored, pull `user_settings` and apply it
to the theme, accent, language, sound and animation providers.

- In `lib/services/settings_sync_service.dart` add
  `Future<void> hydrate(WidgetRef ref)` (or expose the pulled map) that reads the
  row via `pull()` and, if present, calls:
  - `themeModeProvider.notifier.setMode(...)` from `theme_mode` (`system|light|dark`)
  - `accentColorProvider.notifier.setColor(Color(accent_color))`
  - `languageProvider.notifier.setLanguage(language)`
  - `soundEnabledProvider.notifier.set(sound_enabled)`
  - `animationsEnabledProvider.notifier.set(animations_enabled)`
- Call `hydrate` once after a successful session restore/login in
  `auth_provider.dart` `_persistSession` (only for non-guest users), or from the
  app shell after `authProvider` becomes non-null.
- **Do not** re-push during hydration (avoid a pull→push loop). Add a guard flag.

**Acceptance:** change theme on device A, reinstall / sign in on device B → the
theme, accent and language match.

---

## Task 2 — Two-way sync for favorites

**Goal:** `user_favorites` mirrors the favorite tools.

- Edit `lib/providers/tool_activity_provider.dart` `FavoriteToolsNotifier.toggle`:
  after updating local state + SharedPreferences, also upsert/delete in Supabase:
  - add: `client.from('user_favorites').upsert({'user_id': uid, 'tool_id': id})`
  - remove: `client.from('user_favorites').delete().eq('user_id', uid).eq('tool_id', id)`
- On login (Task 1 area), pull `user_favorites` for the user and merge into the
  provider's initial state (union of local + remote, then push the merged set once).
- Guard all of this behind `SupabaseService.client != null && !isGuest`.

**Acceptance:** favorite a tool → row appears in `user_favorites`; unfavorite →
row removed; fresh install after login shows the same favorites.

---

## Task 3 — Record tool usage server-side

**Goal:** `tool_usage` tracks recent + frequency; drives Recently Used.

- In `RecentToolsNotifier.recordUse` (same file), after local update call the RPC:
  `client.rpc('record_tool_use', params: {'p_tool_id': toolId})`.
- On login, pull the top 10 rows ordered by `last_used_at desc` and hydrate
  `recentToolsProvider`.
- Behind the same guard; offline still updates the local list.

**Acceptance:** open a tool → `tool_usage.use_count` increments and
`last_used_at` updates; Recently Used reflects it after reinstall+login.

---

## Task 4 — Profile: edit + avatar upload

**Goal:** the Settings/Profile "Edit Profile" flow writes to `profiles` and the
`avatars` storage bucket.

- Add `lib/services/profile_service.dart` with:
  - `Future<void> updateProfile({String? fullName})` →
    `client.from('profiles').update({'full_name': fullName}).eq('id', uid)`
    and also `client.auth.updateUser(UserAttributes(data: {'full_name': ...}))`.
  - `Future<String> uploadAvatar(File file)` → upload to `avatars/<uid>/avatar.<ext>`
    with `upsert: true`, then `getPublicUrl`, then save to `profiles.avatar_url`
    and auth metadata. Return the URL.
- Wire the profile edit screen (`lib/features/profile/profile_screen.dart`) and the
  camera badge on the Settings profile card to these methods; refresh `authProvider`
  so the new name/avatar shows immediately.
- Use `image_picker` for selection (add to `pubspec.yaml` if missing).

**Acceptance:** change name + pick a photo → persists across restart and is
visible from another device.

---

## Task 5 — Notifications from the database

**Goal:** the bell badge + Notifications screen use the `notifications` table.

- Add `lib/services/notification_feed_service.dart`:
  - `Future<List<AppNotification>> list()` → select for `auth.uid()` ordered by
    `created_at desc`.
  - `Future<int> unreadCount()` → count where `is_read = false`.
  - `Future<void> markRead(String id)` / `markAllRead()`.
  - `Stream<...> live()` → realtime subscription on `notifications` (the table is
    already in the `supabase_realtime` publication).
- Replace the hardcoded `3` / `7` badge counts in `home_screen.dart` and
  `settings_screen.dart` with a provider backed by `unreadCount()`.
- Build the list UI in `lib/features/notifications/notifications_screen.dart`
  (empty state when none). Keep a static fallback list when offline.

**Acceptance:** insert a row in `notifications` → badge count updates live and the
row shows in the screen; tapping marks it read.

---

## Task 6 — Devices & Active Sessions

**Goal:** register this device on login and show/revoke devices in Settings.

- On login, upsert into `user_devices` (`device_name`, `platform`, `last_active`)
  using `device_info_plus` (add if missing).
- In `settings_screen.dart`, make the "Devices" and "Active Sessions" tiles open a
  screen listing `user_devices`; allow deleting a row (revoke). The current device
  is highlighted.

**Acceptance:** each device you sign in from appears; deleting removes it.

---

## Task 7 — Config & docs

- Confirm `lib/config/app_config.dart` reads `SUPABASE_URL` and
  `SUPABASE_ANON_KEY` (dart-define / .env). Add an example `.env.example`.
- Update `supabase/README.md` if you add tables/columns.
- Run `flutter analyze` and fix all warnings introduced by these tasks.

---

## Definition of done

- `flutter analyze` clean.
- App runs with **and** without Supabase keys (offline fallback intact).
- Settings, favorites, recent tools, profile, notifications and devices all read
  and write the correct Supabase tables, scoped by the signed-in user (RLS).
