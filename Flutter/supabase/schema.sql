-- =============================================================================
-- FARVIXO FLUTTER — production-compatible layer (Farvixo project)
-- =============================================================================
-- Safe to run on the live Farvixo Supabase project that already has web/admin
-- tables (profiles, notifications, tool_usage event log, favorites, devices…).
--
-- Creates Flutter-only tables / columns without replacing existing web schemas:
--   user_settings · user_favorites · user_devices · user_tool_stats
--   notifications.is_read (+ sync with existing `read`)
--   profiles.ai_credits / cloud_storage_mb / member_since
--   record_tool_use() → user_tool_stats
--   avatars storage policies · realtime notifications
-- =============================================================================

create extension if not exists "pgcrypto";

-- -----------------------------------------------------------------------------
-- helper
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- profiles — add Flutter display columns (do NOT change existing plan/role text)
-- -----------------------------------------------------------------------------
alter table public.profiles add column if not exists ai_credits integer;
alter table public.profiles alter column ai_credits set default 1250;
alter table public.profiles add column if not exists cloud_storage_mb integer;
alter table public.profiles alter column cloud_storage_mb set default 102400;
alter table public.profiles add column if not exists member_since timestamptz;
alter table public.profiles alter column member_since set default now();

update public.profiles
set ai_credits = coalesce(ai_credits, greatest(coalesce(credits, 0), 1250))
where ai_credits is null;

update public.profiles
set cloud_storage_mb = coalesce(cloud_storage_mb, 102400)
where cloud_storage_mb is null;

update public.profiles
set member_since = coalesce(member_since, created_at, now())
where member_since is null;

-- -----------------------------------------------------------------------------
-- user_settings (Flutter Settings sync) — distinct from public.settings
-- -----------------------------------------------------------------------------
create table if not exists public.user_settings (
  user_id                 uuid primary key references public.profiles (id) on delete cascade,
  theme_mode              text not null default 'system'
                            check (theme_mode in ('system', 'light', 'dark')),
  accent_color            bigint not null default 4286331629,
  language                text not null default 'en',
  sound_enabled           boolean not null default true,
  animations_enabled      boolean not null default true,
  notifications_enabled   boolean not null default true,
  ai_assistant_enabled    boolean not null default true,
  offline_enabled         boolean not null default true,
  cloud_sync_enabled      boolean not null default true,
  biometric_enabled       boolean not null default false,
  updated_at              timestamptz not null default now()
);

alter table public.user_settings add column if not exists theme_mode text;
alter table public.user_settings add column if not exists accent_color bigint;
alter table public.user_settings add column if not exists language text;
alter table public.user_settings add column if not exists sound_enabled boolean;
alter table public.user_settings add column if not exists animations_enabled boolean;
alter table public.user_settings add column if not exists notifications_enabled boolean;
alter table public.user_settings add column if not exists ai_assistant_enabled boolean;
alter table public.user_settings add column if not exists offline_enabled boolean;
alter table public.user_settings add column if not exists cloud_sync_enabled boolean;
alter table public.user_settings add column if not exists biometric_enabled boolean;
alter table public.user_settings add column if not exists updated_at timestamptz;

drop trigger if exists trg_user_settings_updated_at on public.user_settings;
create trigger trg_user_settings_updated_at
  before update on public.user_settings
  for each row execute function public.set_updated_at();

comment on table public.user_settings is
  'Flutter app preferences (theme/accent/language/toggles). Separate from web public.settings.';

-- -----------------------------------------------------------------------------
-- user_favorites (Flutter) — distinct from public.favorites (tool_slug)
-- -----------------------------------------------------------------------------
create table if not exists public.user_favorites (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  tool_id    text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, tool_id)
);

create index if not exists idx_user_favorites_user on public.user_favorites (user_id);

comment on table public.user_favorites is
  'Flutter favorite tool ids. Separate from web public.favorites.';

-- -----------------------------------------------------------------------------
-- user_tool_stats — aggregate recent/frequency (web tool_usage is an event log)
-- -----------------------------------------------------------------------------
create table if not exists public.user_tool_stats (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  tool_id      text not null,
  use_count    integer not null default 1,
  last_used_at timestamptz not null default now(),
  primary key (user_id, tool_id)
);

create index if not exists idx_user_tool_stats_recent
  on public.user_tool_stats (user_id, last_used_at desc);

comment on table public.user_tool_stats is
  'Flutter Recently Used aggregates. Web analytics stay in public.tool_usage.';

create or replace function public.record_tool_use(p_tool_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_tool_id is null or length(trim(p_tool_id)) = 0 then
    raise exception 'tool_id required';
  end if;

  insert into public.user_tool_stats (user_id, tool_id, use_count, last_used_at)
  values (auth.uid(), trim(p_tool_id), 1, now())
  on conflict (user_id, tool_id)
  do update set
    use_count    = public.user_tool_stats.use_count + 1,
    last_used_at = now();
end;
$$;

revoke all on function public.record_tool_use(text) from public;
revoke all on function public.record_tool_use(text) from anon;
grant execute on function public.record_tool_use(text) to authenticated;

-- -----------------------------------------------------------------------------
-- user_devices (Flutter) — distinct from public.devices / trusted_devices
-- -----------------------------------------------------------------------------
create table if not exists public.user_devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  device_key   text,
  device_name  text,
  platform     text,
  last_active  timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

alter table public.user_devices add column if not exists device_key text;
alter table public.user_devices add column if not exists device_name text;
alter table public.user_devices add column if not exists platform text;
alter table public.user_devices add column if not exists last_active timestamptz;
alter table public.user_devices add column if not exists created_at timestamptz;

create index if not exists idx_user_devices_user
  on public.user_devices (user_id, last_active desc);

drop index if exists uq_user_devices_user_key;
do $$
begin
  alter table public.user_devices
    add constraint uq_user_devices_user_key unique (user_id, device_key);
exception
  when duplicate_object then null;
  when unique_violation then
    raise notice 'uq_user_devices_user_key skipped — clean duplicates first';
end $$;

comment on table public.user_devices is
  'Flutter Devices & Active Sessions. Separate from web public.devices.';

-- -----------------------------------------------------------------------------
-- notifications — bridge Flutter is_read ↔ existing web `read`
-- -----------------------------------------------------------------------------
alter table public.notifications add column if not exists is_read boolean;
alter table public.notifications add column if not exists data jsonb;

update public.notifications
set is_read = coalesce(is_read, read, false)
where is_read is null;

update public.notifications
set data = coalesce(data, '{}'::jsonb)
where data is null;

alter table public.notifications alter column is_read set default false;
alter table public.notifications alter column data set default '{}'::jsonb;

create or replace function public.sync_notification_read_flags()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.is_read is null and new.read is not null then
      new.is_read := new.read;
    elsif new.read is null and new.is_read is not null then
      new.read := new.is_read;
    else
      new.is_read := coalesce(new.is_read, false);
      new.read := coalesce(new.read, new.is_read, false);
    end if;
    return new;
  end if;

  -- UPDATE: whichever column changed wins
  if new.is_read is distinct from old.is_read then
    new.read := new.is_read;
  elsif new.read is distinct from old.read then
    new.is_read := new.read;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notifications_sync_read on public.notifications;
create trigger trg_notifications_sync_read
  before insert or update on public.notifications
  for each row execute function public.sync_notification_read_flags();

alter table public.notifications replica identity full;

create index if not exists idx_notifications_unread_is_read
  on public.notifications (user_id) where is_read = false;

-- -----------------------------------------------------------------------------
-- RLS for Flutter tables
-- -----------------------------------------------------------------------------
alter table public.user_settings   enable row level security;
alter table public.user_favorites  enable row level security;
alter table public.user_tool_stats enable row level security;
alter table public.user_devices    enable row level security;

drop policy if exists "settings: all own" on public.user_settings;
create policy "settings: all own" on public.user_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "favorites: all own" on public.user_favorites;
create policy "favorites: all own" on public.user_favorites
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "tool_stats: all own" on public.user_tool_stats;
create policy "tool_stats: all own" on public.user_tool_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "devices: all own" on public.user_devices;
create policy "devices: all own" on public.user_devices
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Ensure profiles own-row policies exist (web may already have equivalents)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles: select own'
  ) then
    create policy "profiles: select own" on public.profiles
      for select using (auth.uid() = id);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles: update own'
  ) then
    create policy "profiles: update own" on public.profiles
      for update using (auth.uid() = id) with check (auth.uid() = id);
  end if;
end $$;

-- notifications: ensure select/update for own rows (web may already have)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'notifications: select own'
  ) then
    create policy "notifications: select own" on public.notifications
      for select using (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'notifications: update own'
  ) then
    create policy "notifications: update own" on public.notifications
      for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end $$;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.user_settings   to authenticated;
grant select, insert, update, delete on public.user_favorites  to authenticated;
grant select, insert, update, delete on public.user_tool_stats to authenticated;
grant select, insert, update, delete on public.user_devices    to authenticated;
grant select, update on public.notifications to authenticated;
grant select, update on public.profiles to authenticated;

-- -----------------------------------------------------------------------------
-- Signup: ensure Flutter user_settings row (do NOT replace existing handle_new_user)
-- -----------------------------------------------------------------------------
create or replace function public.ensure_flutter_user_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  -- Welcome ping only if user has zero notifications
  if not exists (
    select 1 from public.notifications n where n.user_id = new.id limit 1
  ) then
    insert into public.notifications (user_id, title, body, type, read, is_read)
    values (
      new.id,
      'Welcome to Farvixo!',
      'Explore 120+ tools and the AI Assistant — all in one app.',
      'system',
      false,
      false
    );
  end if;

  return new;
end;
$$;

revoke all on function public.ensure_flutter_user_row() from public;
revoke all on function public.ensure_flutter_user_row() from anon;
revoke all on function public.ensure_flutter_user_row() from authenticated;

drop trigger if exists on_profile_ensure_flutter on public.profiles;
create trigger on_profile_ensure_flutter
  after insert on public.profiles
  for each row execute function public.ensure_flutter_user_row();

-- -----------------------------------------------------------------------------
-- STORAGE — avatars (bucket may already exist)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = coalesce(excluded.file_size_limit, storage.buckets.file_size_limit),
  allowed_mime_types = coalesce(excluded.allowed_mime_types, storage.buckets.allowed_mime_types);

drop policy if exists "avatars: public read"  on storage.objects;
drop policy if exists "avatars: owner upload" on storage.objects;
drop policy if exists "avatars: owner update" on storage.objects;
drop policy if exists "avatars: owner delete" on storage.objects;

-- Public URL access does not need a broad SELECT listing policy.
-- Keep owner write policies for Flutter ProfileService uploads.
create policy "avatars: owner upload" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: owner update" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars: owner delete" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -----------------------------------------------------------------------------
-- REALTIME
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- BACKFILL
-- -----------------------------------------------------------------------------
insert into public.user_settings (user_id)
select id from public.profiles
on conflict (user_id) do nothing;
