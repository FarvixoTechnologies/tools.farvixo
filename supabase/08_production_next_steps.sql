-- ============================================================
-- Farvixo — Production Next Steps (idempotent)
-- Project: bujpwwxanaejfcyuigth
-- Run AFTER schema.sql (+ 01..07 if needed) in Supabase SQL Editor.
-- Covers: missing tables, storage buckets, RLS (own-data policies).
-- ============================================================

-- ---------- subscriptions ----------
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null default 'FREE',             -- FREE | PRO | ENTERPRISE
  status text not null default 'inactive',       -- active | canceled | past_due | inactive | trialing
  stripe_customer_id text,
  stripe_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create index if not exists subscriptions_status_idx on public.subscriptions (status);

alter table public.subscriptions enable row level security;

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own" on public.subscriptions
  for select using (auth.uid() = user_id);

drop policy if exists "subscriptions_insert_own" on public.subscriptions;
create policy "subscriptions_insert_own" on public.subscriptions
  for insert with check (auth.uid() = user_id);

drop policy if exists "subscriptions_update_own" on public.subscriptions;
create policy "subscriptions_update_own" on public.subscriptions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- wallet ----------
create table if not exists public.wallet (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  balance_cents integer not null default 0 check (balance_cents >= 0),
  currency text not null default 'INR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

alter table public.wallet enable row level security;

drop policy if exists "wallet_select_own" on public.wallet;
create policy "wallet_select_own" on public.wallet
  for select using (auth.uid() = user_id);

drop policy if exists "wallet_insert_own" on public.wallet;
create policy "wallet_insert_own" on public.wallet
  for insert with check (auth.uid() = user_id);

drop policy if exists "wallet_update_own" on public.wallet;
create policy "wallet_update_own" on public.wallet
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- credits (snapshot table; ledger stays in credit_ledger) ----------
create table if not exists public.credits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  lifetime_earned integer not null default 0,
  lifetime_spent integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.credits enable row level security;

drop policy if exists "credits_select_own" on public.credits;
create policy "credits_select_own" on public.credits
  for select using (auth.uid() = user_id);

-- Sync credits row from profiles.credits on signup (best-effort)
create or replace function public.sync_credits_row()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.credits (user_id, balance, lifetime_earned, updated_at)
  values (new.id, coalesce(new.credits, 0), coalesce(new.credits, 0), now())
  on conflict (user_id) do update
    set balance = excluded.balance,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_sync_credits on public.profiles;
create trigger profiles_sync_credits
  after insert or update of credits on public.profiles
  for each row execute function public.sync_credits_row();

-- ---------- favorites ----------
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_slug text not null,
  tool_name text,
  category text,
  created_at timestamptz not null default now(),
  unique (user_id, tool_slug)
);

create index if not exists favorites_user_idx on public.favorites (user_id, created_at desc);

alter table public.favorites enable row level security;

drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own" on public.favorites
  for select using (auth.uid() = user_id);

drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own" on public.favorites
  for insert with check (auth.uid() = user_id);

drop policy if exists "favorites_update_own" on public.favorites;
create policy "favorites_update_own" on public.favorites
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own" on public.favorites
  for delete using (auth.uid() = user_id);

-- ---------- history (tool usage archive; jobs remains for API pipeline) ----------
create table if not exists public.history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_slug text not null,
  tool_name text,
  category text,
  status text not null default 'completed',
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists history_user_created_idx on public.history (user_id, created_at desc);

alter table public.history enable row level security;

drop policy if exists "history_select_own" on public.history;
create policy "history_select_own" on public.history
  for select using (auth.uid() = user_id);

drop policy if exists "history_insert_own" on public.history;
create policy "history_insert_own" on public.history
  for insert with check (auth.uid() = user_id);

drop policy if exists "history_update_own" on public.history;
create policy "history_update_own" on public.history
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "history_delete_own" on public.history;
create policy "history_delete_own" on public.history
  for delete using (auth.uid() = user_id);

-- ---------- settings (per-user prefs) ----------
create table if not exists public.settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  locale text not null default 'en',
  theme text not null default 'system',          -- light | dark | system
  email_notifications boolean not null default true,
  push_notifications boolean not null default true,
  marketing_opt_in boolean not null default false,
  prefs jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.settings enable row level security;

drop policy if exists "settings_select_own" on public.settings;
create policy "settings_select_own" on public.settings
  for select using (auth.uid() = user_id);

drop policy if exists "settings_insert_own" on public.settings;
create policy "settings_insert_own" on public.settings
  for insert with check (auth.uid() = user_id);

drop policy if exists "settings_update_own" on public.settings;
create policy "settings_update_own" on public.settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "settings_delete_own" on public.settings;
create policy "settings_delete_own" on public.settings
  for delete using (auth.uid() = user_id);

-- ---------- devices ----------
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  platform text,                                   -- android | ios | web | desktop
  push_token text,
  app_version text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create index if not exists devices_user_idx on public.devices (user_id, last_seen_at desc);

alter table public.devices enable row level security;

drop policy if exists "devices_select_own" on public.devices;
create policy "devices_select_own" on public.devices
  for select using (auth.uid() = user_id);

drop policy if exists "devices_insert_own" on public.devices;
create policy "devices_insert_own" on public.devices
  for insert with check (auth.uid() = user_id);

drop policy if exists "devices_update_own" on public.devices;
create policy "devices_update_own" on public.devices
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "devices_delete_own" on public.devices;
create policy "devices_delete_own" on public.devices
  for delete using (auth.uid() = user_id);

-- ---------- user_sessions (app-tracked sessions; auth.sessions is system) ----------
create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text,
  ip inet,
  user_agent text,
  provider text,                                   -- email | google | github | magic_link
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  last_active_at timestamptz not null default now()
);

create index if not exists user_sessions_user_idx
  on public.user_sessions (user_id, last_active_at desc);

alter table public.user_sessions enable row level security;

drop policy if exists "user_sessions_select_own" on public.user_sessions;
create policy "user_sessions_select_own" on public.user_sessions
  for select using (auth.uid() = user_id);

drop policy if exists "user_sessions_insert_own" on public.user_sessions;
create policy "user_sessions_insert_own" on public.user_sessions
  for insert with check (auth.uid() = user_id);

drop policy if exists "user_sessions_update_own" on public.user_sessions;
create policy "user_sessions_update_own" on public.user_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "user_sessions_delete_own" on public.user_sessions;
create policy "user_sessions_delete_own" on public.user_sessions
  for delete using (auth.uid() = user_id);

-- Ensure notifications has full CRUD (schema.sql already creates table)
alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);

drop policy if exists "notifications_insert_own" on public.notifications;
create policy "notifications_insert_own" on public.notifications
  for insert with check (auth.uid() = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own" on public.notifications
  for delete using (auth.uid() = user_id);

-- Ensure profiles insert own (signup race / client upsert)
alter table public.profiles enable row level security;

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles
  for delete using (auth.uid() = id);

-- ============================================================
-- STORAGE BUCKETS
-- Public: avatars, images
-- Private: documents, videos, chat, exports, temp
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',   'avatars',   true,  5 * 1024 * 1024, array['image/jpeg','image/png','image/webp','image/gif']),
  ('images',    'images',    true,  25 * 1024 * 1024, array['image/jpeg','image/png','image/webp','image/gif','image/avif']),
  ('documents', 'documents', false, 100 * 1024 * 1024, null),
  ('videos',    'videos',    false, 500 * 1024 * 1024, array['video/mp4','video/webm','video/quicktime']),
  ('chat',      'chat',      false, 25 * 1024 * 1024, null),
  ('temp',      'temp',      false, 200 * 1024 * 1024, null),
  ('exports',   'exports',   false, 200 * 1024 * 1024, null)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit;

-- Paths: {user_id}/... — users only access their own folder
-- Public buckets: anyone can read; only owner can write
do $$
declare
  b text;
begin
  foreach b in array array['avatars','images','documents','videos','chat','temp','exports']
  loop
    execute format('drop policy if exists %I on storage.objects', b || '_select_own');
    execute format('drop policy if exists %I on storage.objects', b || '_insert_own');
    execute format('drop policy if exists %I on storage.objects', b || '_update_own');
    execute format('drop policy if exists %I on storage.objects', b || '_delete_own');
    execute format('drop policy if exists %I on storage.objects', b || '_public_read');
  end loop;
end $$;

-- Public read for avatars + images
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "images_public_read" on storage.objects
  for select using (bucket_id = 'images');

-- Own-folder write for all buckets
create policy "avatars_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "avatars_update_own" on storage.objects
  for update using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "avatars_delete_own" on storage.objects
  for delete using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "images_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'images' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "images_update_own" on storage.objects
  for update using (
    bucket_id = 'images' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "images_delete_own" on storage.objects
  for delete using (
    bucket_id = 'images' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Private buckets: select + mutate only own folder
create policy "documents_select_own" on storage.objects
  for select using (
    bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "documents_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "documents_update_own" on storage.objects
  for update using (
    bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "documents_delete_own" on storage.objects
  for delete using (
    bucket_id = 'documents' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "videos_select_own" on storage.objects
  for select using (
    bucket_id = 'videos' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "videos_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'videos' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "videos_update_own" on storage.objects
  for update using (
    bucket_id = 'videos' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "videos_delete_own" on storage.objects
  for delete using (
    bucket_id = 'videos' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "chat_select_own" on storage.objects
  for select using (
    bucket_id = 'chat' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "chat_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'chat' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "chat_update_own" on storage.objects
  for update using (
    bucket_id = 'chat' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "chat_delete_own" on storage.objects
  for delete using (
    bucket_id = 'chat' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "temp_select_own" on storage.objects
  for select using (
    bucket_id = 'temp' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "temp_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'temp' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "temp_update_own" on storage.objects
  for update using (
    bucket_id = 'temp' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "temp_delete_own" on storage.objects
  for delete using (
    bucket_id = 'temp' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "exports_select_own" on storage.objects
  for select using (
    bucket_id = 'exports' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "exports_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'exports' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "exports_update_own" on storage.objects
  for update using (
    bucket_id = 'exports' and auth.uid()::text = (storage.foldername(name))[1]
  );
create policy "exports_delete_own" on storage.objects
  for delete using (
    bucket_id = 'exports' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Service role bypasses RLS automatically (full access).
