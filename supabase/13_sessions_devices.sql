-- 13_sessions_devices.sql
-- Sessions & Devices module: session tracking, device history, login audit.
-- Writes happen server-side via the service role (bypasses RLS); the
-- SELECT-own policies let users view/manage their own sessions later.

create table if not exists public.devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  device_id    text not null,
  platform     text,
  app_version  text,
  user_agent   text,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  unique (user_id, device_id)
);

create table if not exists public.user_sessions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  device_id      text,
  provider       text,
  ip             text,
  user_agent     text,
  created_at     timestamptz not null default now(),
  last_active_at timestamptz not null default now(),
  revoked_at     timestamptz,
  revoked_by     uuid references auth.users(id) on delete set null,
  unique (user_id, device_id)
);

create table if not exists public.login_history (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete set null,
  provider   text,
  success    boolean not null default true,
  ip         text,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists devices_user_idx          on public.devices (user_id);
create index if not exists devices_last_seen_idx      on public.devices (last_seen_at desc);
create index if not exists user_sessions_user_idx     on public.user_sessions (user_id);
create index if not exists user_sessions_active_idx   on public.user_sessions (last_active_at desc);
create index if not exists user_sessions_revoked_idx  on public.user_sessions (revoked_at);
create index if not exists login_history_user_idx     on public.login_history (user_id);
create index if not exists login_history_created_idx  on public.login_history (created_at desc);

alter table public.devices       enable row level security;
alter table public.user_sessions enable row level security;
alter table public.login_history enable row level security;

drop policy if exists devices_select_own on public.devices;
create policy devices_select_own on public.devices
  for select using (auth.uid() = user_id);

drop policy if exists user_sessions_select_own on public.user_sessions;
create policy user_sessions_select_own on public.user_sessions
  for select using (auth.uid() = user_id);

drop policy if exists login_history_select_own on public.login_history;
create policy login_history_select_own on public.login_history
  for select using (auth.uid() = user_id);
