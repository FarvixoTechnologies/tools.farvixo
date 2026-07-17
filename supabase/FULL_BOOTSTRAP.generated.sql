-- Farvixo FULL BOOTSTRAP (generated 2026-07-15T20:47:47.505Z)
-- Project: bujpwwxanaejfcyuigth
-- Prefer stepwise apply via supabase/BOOTSTRAP.md if errors occur.


-- ========== BEGIN schema.sql ==========

-- ============================================================
-- Farvixo Tools — Supabase Schema (idempotent, safe to re-run)
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor).
-- ============================================================

-- ---------- PROFILES ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  plan text not null default 'FREE',            -- 'FREE' | 'PRO' | 'ENTERPRISE'
  role text not null default 'USER',
  tools_used_today integer not null default 0,
  stripe_customer_id text,
  stripe_subscription_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles add column if not exists stripe_customer_id text;
alter table public.profiles add column if not exists stripe_subscription_id text;

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create a profile row when a user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- JOBS (tool usage history) ----------
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_slug text not null,
  tool_name text not null,
  category text not null,
  status text not null default 'completed',     -- used | completed | failed
  created_at timestamptz not null default now()
);

create index if not exists jobs_user_created_idx on public.jobs (user_id, created_at desc);

alter table public.jobs enable row level security;

drop policy if exists "jobs_select_own" on public.jobs;
create policy "jobs_select_own" on public.jobs
  for select using (auth.uid() = user_id);

drop policy if exists "jobs_insert_own" on public.jobs;
create policy "jobs_insert_own" on public.jobs
  for insert with check (auth.uid() = user_id);

drop policy if exists "jobs_delete_own" on public.jobs;
create policy "jobs_delete_own" on public.jobs
  for delete using (auth.uid() = user_id);

-- ---------- NEWSLETTER ----------
create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  source text,
  subscribed_at timestamptz not null default now(),
  unsubscribed_at timestamptz
);

alter table public.newsletter_subscribers enable row level security;
-- No public policies: only the service-role key (server) can read/write.

-- ---------- CONTACT MESSAGES ----------
create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  message text not null,
  status text not null default 'new',
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.contact_messages add column if not exists status text not null default 'new';
alter table public.contact_messages add column if not exists admin_note text;
alter table public.contact_messages add column if not exists updated_at timestamptz not null default now();

alter table public.contact_messages enable row level security;
-- Service-role only.

-- ---------- SEARCH LOGS ----------
create table if not exists public.search_logs (
  id uuid primary key default gen_random_uuid(),
  query text not null,
  results_count integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.search_logs enable row level security;
-- Service-role only.

-- ---------- ANALYTICS EVENTS ----------
create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  event text not null,
  props jsonb not null default '{}'::jsonb,
  user_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists analytics_event_idx on public.analytics_events (event, created_at desc);

alter table public.analytics_events enable row level security;
-- Service-role only.

-- ---------- ADMIN AUDIT LOG ----------
create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_created_idx on public.admin_audit_log (created_at desc);

alter table public.admin_audit_log enable row level security;
-- Service-role only.

-- ---------- ADMIN SETTINGS (key-value config store) ----------
create table if not exists public.admin_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

alter table public.admin_settings enable row level security;
-- Service-role only.

-- ============================================================
-- CREDITS SYSTEM — Farvixo API credits
-- ============================================================

-- Balance lives on the profile for fast reads; every change is ledgered.
alter table public.profiles add column if not exists credits integer not null default 0;

create table if not exists public.credit_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null,                        -- positive = grant, negative = spend
  balance_after integer not null,
  reason text not null,                           -- signup_bonus | admin_grant | admin_deduct | ai_chat | api_call | purchase
  actor_id uuid references auth.users(id) on delete set null,  -- admin who granted, null = system/self
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists credit_ledger_user_idx on public.credit_ledger (user_id, created_at desc);

alter table public.credit_ledger enable row level security;

drop policy if exists "credit_ledger_select_own" on public.credit_ledger;
create policy "credit_ledger_select_own" on public.credit_ledger
  for select using (auth.uid() = user_id);
-- Inserts only via adjust_credits() / service role.

-- Atomic credit adjustment: prevents double-spend and negative balances.
create or replace function public.adjust_credits(
  p_user_id uuid,
  p_amount integer,
  p_reason text,
  p_actor uuid default null,
  p_meta jsonb default '{}'::jsonb
) returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  new_balance integer;
begin
  update public.profiles
    set credits = credits + p_amount, updated_at = now()
    where id = p_user_id and credits + p_amount >= 0
    returning credits into new_balance;

  if new_balance is null then
    raise exception 'INSUFFICIENT_CREDITS';
  end if;

  insert into public.credit_ledger (user_id, amount, balance_after, reason, actor_id, meta)
    values (p_user_id, p_amount, new_balance, p_reason, p_actor, p_meta);

  return new_balance;
end;
$$;

-- Only the service role (server) may adjust credits — never the browser.
revoke execute on function public.adjust_credits(uuid, integer, text, uuid, jsonb) from public, anon, authenticated;

-- ---------- API KEYS (Farvixo public API) ----------
create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  key_hash text unique not null,                  -- sha256 of the full key; the key itself is never stored
  prefix text not null,                           -- display prefix e.g. fx_live_ab12…
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists api_keys_user_idx on public.api_keys (user_id, created_at desc);

alter table public.api_keys enable row level security;

drop policy if exists "api_keys_select_own" on public.api_keys;
create policy "api_keys_select_own" on public.api_keys
  for select using (auth.uid() = user_id);
-- Writes via service role only (creation returns the key once).

-- ---------- SIGNUP BONUS ----------
-- New users start with 25 free credits (replaces the old handle_new_user).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url, credits)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url',
    25
  )
  on conflict (id) do nothing;

  insert into public.credit_ledger (user_id, amount, balance_after, reason)
  values (new.id, 25, 25, 'signup_bonus');

  return new;
end;
$$;

-- ---------- NOTIFICATIONS ----------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null default 'system',          -- system | job | billing | announcement
  title text not null,
  body text,
  href text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);

drop policy if exists "notifications_insert_own" on public.notifications;
create policy "notifications_insert_own" on public.notifications
  for insert with check (auth.uid() = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id);

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own" on public.notifications
  for delete using (auth.uid() = user_id);


-- ========== END schema.sql ==========


-- ========== BEGIN 01_missing_admin.sql ==========

-- ============================================================
-- Farvixo Tools — Missing admin tables
-- Project: bujpwwxanaejfcyuigth (safe to re-run)
-- ============================================================

-- Contact inbox columns
ALTER TABLE public.contact_messages ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'new';
ALTER TABLE public.contact_messages ADD COLUMN IF NOT EXISTS admin_note text;
ALTER TABLE public.contact_messages ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Admin audit log
CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  target text,
  meta jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS admin_audit_created_idx ON public.admin_audit_log (created_at DESC);
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Admin settings key-value store
CREATE TABLE IF NOT EXISTS public.admin_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
ALTER TABLE public.admin_settings ENABLE ROW LEVEL SECURITY;

-- Ensure super admin (already applied via bootstrap script)
UPDATE public.profiles
SET role = 'SUPER_ADMIN', plan = 'ENTERPRISE', full_name = COALESCE(full_name, 'Faruk Mondal'), updated_at = now()
WHERE id = (SELECT id FROM auth.users WHERE lower(email) = lower('farukmondal106@gmail.com') LIMIT 1);


-- ========== END 01_missing_admin.sql ==========


-- ========== BEGIN 06_user_admin.sql ==========

-- User admin fields: email sync, ban status, admin notes, quota override
-- Run in Supabase SQL Editor after schema.sql / 01_missing_admin.sql

alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists is_banned boolean not null default false;
alter table public.profiles add column if not exists banned_at timestamptz;
alter table public.profiles add column if not exists ban_reason text;
alter table public.profiles add column if not exists admin_notes text;
alter table public.profiles add column if not exists storage_used_mb integer not null default 0;
alter table public.profiles add column if not exists daily_tool_limit integer;

create index if not exists profiles_email_idx on public.profiles (lower(email));
create index if not exists profiles_banned_idx on public.profiles (is_banned) where is_banned = true;

-- Sync email on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url, email, credits)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url',
    new.email,
    25
  )
  on conflict (id) do update set
    email = coalesce(excluded.email, public.profiles.email),
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);

  if not exists (
    select 1 from public.credit_ledger where user_id = new.id and reason = 'signup_bonus'
  ) then
    insert into public.credit_ledger (user_id, amount, balance_after, reason)
    values (new.id, 25, 25, 'signup_bonus');
  end if;

  return new;
end;
$$;

-- Backfill emails from auth.users (run once)
update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id and (p.email is null or p.email = '');

-- Allow service role to insert notifications for any user (admin broadcast)
drop policy if exists "notifications_insert_service" on public.notifications;
-- Notifications remain user-scoped for clients; admin uses service role.


-- ========== END 06_user_admin.sql ==========


-- ========== BEGIN 04_shares.sql ==========

-- Share links for processed files — run this in the Supabase SQL editor.

create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  token text unique not null,
  user_id uuid references auth.users(id) on delete set null,
  file_name text not null,
  file_size bigint not null default 0,
  mime_type text not null default 'application/octet-stream',
  storage_path text not null,
  expires_at timestamptz not null,
  max_downloads integer,                         -- null = unlimited
  downloads integer not null default 0,
  password_hash text,
  share_events jsonb not null default '[]'::jsonb,
  tool_slug text,
  device_hint text,
  created_at timestamptz not null default now()
);

-- Migrate existing deployments (safe to re-run).
alter table public.shares add column if not exists password_hash text;
alter table public.shares add column if not exists share_events jsonb not null default '[]'::jsonb;
alter table public.shares add column if not exists tool_slug text;
alter table public.shares add column if not exists device_hint text;

create index if not exists shares_token_idx on public.shares (token);
create index if not exists shares_expires_idx on public.shares (expires_at);

alter table public.shares enable row level security;
-- No public policies: only the service-role key (server) reads/writes shares.

-- Private storage bucket for shared files (25MB per object).
insert into storage.buckets (id, name, public, file_size_limit)
values ('shares', 'shares', false, 26214400)
on conflict (id) do nothing;


-- ========== END 04_shares.sql ==========


-- ========== BEGIN 07_notifications.sql ==========

-- Notification broadcasts audit + Realtime for live bell updates

create table if not exists public.notification_broadcasts (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  title text not null,
  body text,
  href text,
  target_type text not null default 'all',  -- all | plan | user
  target_value text,
  sent_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists notification_broadcasts_created_idx
  on public.notification_broadcasts (created_at desc);

alter table public.notification_broadcasts enable row level security;

-- Realtime: push new notifications to connected clients
alter table public.notifications replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;


-- ========== END 07_notifications.sql ==========


-- ========== BEGIN 08_production_next_steps.sql ==========

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


-- ========== END 08_production_next_steps.sql ==========


-- ========== BEGIN 09_architecture_v3_foundation.sql ==========

-- ============================================================
-- Farvixo DATABASE ARCHITECTURE v3.0 — PHASE 1 FOUNDATION
-- Enterprise · AI Native · Multi Platform · Offline-Ready
-- Idempotent — run after schema.sql + 08_production_next_steps.sql
-- ============================================================
-- Does NOT recreate: profiles, jobs, notifications, wallet, credits,
-- favorites, history, settings, devices, user_sessions, subscriptions,
-- api_keys, credit_ledger, analytics_events, admin_*, shares
-- ============================================================

-- ---------- EXTENSIONS ----------
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists "pgcrypto" with schema extensions;
create extension if not exists "pg_trgm" with schema extensions;
create extension if not exists "unaccent" with schema extensions;
create extension if not exists "btree_gin" with schema extensions;
create extension if not exists "btree_gist" with schema extensions;
create extension if not exists "pg_stat_statements" with schema extensions;
-- Optional (enable in Dashboard → Database → Extensions if create fails):
-- create extension if not exists "vector";      -- pgvector
-- create extension if not exists "postgis";
-- create extension if not exists "pg_net" with schema extensions;

-- Helper: updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- USER SYSTEM (v3 extras)
-- ============================================================

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  homepage_layout jsonb not null default '{}'::jsonb,
  tool_order jsonb not null default '[]'::jsonb,
  muted_categories text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists public.user_socials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  github_username text,
  google_sub text,
  twitter_handle text,
  website text,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  label text,
  fingerprint_hash text,
  trusted_at timestamptz not null default now(),
  expires_at timestamptz,
  unique (user_id, device_id)
);

create table if not exists public.login_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  provider text,
  success boolean not null default true,
  ip inet,
  user_agent text,
  geo jsonb,
  created_at timestamptz not null default now()
);
create index if not exists login_history_user_idx on public.login_history (user_id, created_at desc);

create table if not exists public.activity_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  entity_type text,
  entity_id text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists activity_history_user_idx on public.activity_history (user_id, created_at desc);

create table if not exists public.online_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'offline', -- online | away | offline
  last_seen_at timestamptz not null default now(),
  presence jsonb not null default '{}'::jsonb
);

create table if not exists public.verification (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null, -- email | phone | identity
  status text not null default 'pending',
  payload jsonb not null default '{}'::jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.blocked_users (
  user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_user_id),
  check (user_id <> blocked_user_id)
);

create table if not exists public.deleted_accounts (
  id uuid primary key default gen_random_uuid(),
  former_user_id uuid,
  email_hash text,
  reason text,
  snapshot jsonb not null default '{}'::jsonb,
  deleted_at timestamptz not null default now()
);

-- ============================================================
-- TOOLS CATALOG
-- ============================================================

create table if not exists public.tool_categories (
  id serial primary key,
  slug text unique not null,
  name text not null,
  icon text,
  accent text,
  sort_order integer not null default 0,
  tool_count integer not null default 0,
  is_active boolean not null default true
);

create table if not exists public.tools (
  id serial primary key,
  slug text unique not null,
  name text not null,
  description text,
  category_slug text references public.tool_categories(slug) on delete set null,
  icon text,
  badge text,
  is_ai_powered boolean not null default false,
  is_active boolean not null default true,
  usage_count bigint not null default 0,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists tools_category_idx on public.tools (category_slug);
create index if not exists tools_name_trgm_idx on public.tools using gin (name gin_trgm_ops);

create table if not exists public.tool_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  tool_slug text not null,
  duration_ms integer,
  status text not null default 'completed',
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists tool_usage_user_idx on public.tool_usage (user_id, created_at desc);
create index if not exists tool_usage_tool_idx on public.tool_usage (tool_slug, created_at desc);

create table if not exists public.tool_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_slug text not null,
  rating smallint not null check (rating between 1 and 5),
  body text,
  created_at timestamptz not null default now(),
  unique (user_id, tool_slug)
);

-- ============================================================
-- AI CORE
-- ============================================================

create table if not exists public.ai_providers (
  id text primary key, -- gemini | groq | openrouter
  display_name text not null,
  is_active boolean not null default true,
  config jsonb not null default '{}'::jsonb
);

create table if not exists public.ai_models (
  id text primary key,
  provider_id text not null references public.ai_providers(id) on delete cascade,
  display_name text not null,
  context_window integer,
  is_active boolean not null default true,
  meta jsonb not null default '{}'::jsonb
);

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  model_id text references public.ai_models(id) on delete set null,
  meta jsonb not null default '{}'::jsonb,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ai_conversations_user_idx on public.ai_conversations (user_id, updated_at desc);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant','system','tool')),
  content text not null,
  token_count integer,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ai_messages_conv_idx on public.ai_messages (conversation_id, created_at);

create table if not exists public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  provider_id text,
  model_id text,
  prompt_tokens integer not null default 0,
  completion_tokens integer not null default 0,
  cost_micros integer not null default 0,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_idx on public.ai_usage (user_id, created_at desc);

create table if not exists public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  message_id uuid references public.ai_messages(id) on delete cascade,
  rating smallint check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_prompt_library (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade, -- null = global
  title text not null,
  prompt text not null,
  tags text[] not null default '{}',
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

-- Embeddings table ready for pgvector (column as text until extension enabled)
create table if not exists public.ai_embeddings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  source_type text not null, -- message | file | tool | note
  source_id text not null,
  model_id text,
  content_preview text,
  -- embedding vector(1536),  -- uncomment after: create extension vector
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists ai_embeddings_source_idx on public.ai_embeddings (source_type, source_id);

-- ============================================================
-- WORKSPACE (multi-tenant scaffold)
-- ============================================================

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text unique not null,
  plan text not null default 'FREE',
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member', -- owner | admin | member | viewer
  joined_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists public.folders (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid references public.folders(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color text,
  unique (user_id, name)
);

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workspace_id uuid references public.workspaces(id) on delete set null,
  title text,
  body text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  url text not null,
  title text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.recent_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null,
  item_id text not null,
  title text,
  opened_at timestamptz not null default now()
);
create index if not exists recent_items_user_idx on public.recent_items (user_id, opened_at desc);

-- ============================================================
-- PAYMENTS (plans + transactions; subscriptions/wallet/credits already in 08)
-- ============================================================

create table if not exists public.plans (
  id text primary key, -- free | pro | enterprise
  name text not null,
  price_monthly_cents integer not null default 0,
  price_yearly_cents integer not null default 0,
  features jsonb not null default '[]'::jsonb,
  limits jsonb not null default '{}'::jsonb,
  is_active boolean not null default true
);

insert into public.plans (id, name, price_monthly_cents, features, limits)
values
  ('free', 'Free', 0, '["5 jobs/day","500MB storage"]'::jsonb, '{"jobs_per_day":5,"storage_mb":500}'::jsonb),
  ('pro', 'Pro', 999, '["Unlimited tools","100GB","Priority AI"]'::jsonb, '{"jobs_per_day":null,"storage_mb":102400}'::jsonb),
  ('enterprise', 'Enterprise', 0, '["SSO","SLA","Custom limits"]'::jsonb, '{}'::jsonb)
on conflict (id) do nothing;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null, -- credit_purchase | subscription | refund | withdrawal
  amount_cents integer not null,
  currency text not null default 'INR',
  status text not null default 'pending',
  provider text, -- stripe | razorpay | manual
  provider_ref text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists transactions_user_idx on public.transactions (user_id, created_at desc);

create table if not exists public.promo_codes (
  code text primary key,
  discount_pct integer check (discount_pct between 1 and 100),
  credit_bonus integer,
  max_redemptions integer,
  redemptions integer not null default 0,
  expires_at timestamptz,
  is_active boolean not null default true
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  number text unique,
  amount_cents integer not null,
  currency text not null default 'INR',
  status text not null default 'draft',
  pdf_path text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- NOTIFICATION / SEARCH / REMOTE CONFIG
-- ============================================================

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email boolean not null default true,
  push boolean not null default true,
  sms boolean not null default false,
  marketing boolean not null default false,
  channels jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text,
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create table if not exists public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  query text not null,
  results_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists search_history_user_idx on public.search_history (user_id, created_at desc);

create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  query text not null,
  filters jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  rollout_pct integer not null default 100 check (rollout_pct between 0 and 100),
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.remote_config (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.maintenance (
  id int primary key default 1 check (id = 1),
  is_active boolean not null default false,
  message text,
  starts_at timestamptz,
  ends_at timestamptz
);
insert into public.maintenance (id, is_active) values (1, false) on conflict do nothing;

-- ============================================================
-- SECURITY / SUPPORT / OFFLINE / API
-- ============================================================

create table if not exists public.failed_logins (
  id uuid primary key default gen_random_uuid(),
  email text,
  ip inet,
  user_agent text,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists failed_logins_ip_idx on public.failed_logins (ip, created_at desc);

create table if not exists public.blocked_ips (
  ip cidr primary key,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  event text not null,
  severity text not null default 'info',
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  status text not null default 'open',
  priority text not null default 'normal',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  body text not null,
  is_staff boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.offline_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text,
  op text not null,
  payload jsonb not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  synced_at timestamptz
);
create index if not exists offline_queue_user_idx on public.offline_queue (user_id, status, created_at);

create table if not exists public.sync_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  device_id text,
  status text not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.webhooks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  url text not null,
  secret text,
  events text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.webhook_logs (
  id uuid primary key default gen_random_uuid(),
  webhook_id uuid references public.webhooks(id) on delete cascade,
  status_code integer,
  payload jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.background_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  task_type text not null,
  status text not null default 'queued',
  payload jsonb not null default '{}'::jsonb,
  result jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.storage_files (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  path text not null,
  mime_type text,
  size_bytes bigint not null default 0,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (bucket, path)
);

-- ============================================================
-- FUNCTIONS (core)
-- ============================================================

create or replace function public.create_wallet(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.wallet (user_id) values (p_user_id)
  on conflict (user_id) do nothing;
  insert into public.credits (user_id, balance) values (p_user_id, 0)
  on conflict (user_id) do nothing;
  insert into public.settings (user_id) values (p_user_id)
  on conflict (user_id) do nothing;
  insert into public.notification_preferences (user_id) values (p_user_id)
  on conflict (user_id) do nothing;
  insert into public.user_preferences (user_id) values (p_user_id)
  on conflict (user_id) do nothing;
end;
$$;

create or replace function public.update_last_seen(p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.online_status (user_id, status, last_seen_at)
  values (p_user_id, 'online', now())
  on conflict (user_id) do update
    set status = 'online', last_seen_at = now();
end;
$$;

create or replace function public.log_activity(
  p_user_id uuid,
  p_action text,
  p_entity_type text default null,
  p_entity_id text default null,
  p_meta jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  rid uuid;
begin
  insert into public.activity_history (user_id, action, entity_type, entity_id, meta)
  values (p_user_id, p_action, p_entity_type, p_entity_id, p_meta)
  returning id into rid;
  return rid;
end;
$$;

create or replace function public.create_notification(
  p_user_id uuid,
  p_title text,
  p_body text default null,
  p_type text default 'system',
  p_href text default null
) returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  rid uuid;
begin
  insert into public.notifications (user_id, type, title, body, href)
  values (p_user_id, p_type, p_title, p_body, p_href)
  returning id into rid;
  return rid;
end;
$$;

create or replace function public.generate_slug(p_text text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(unaccent(coalesce(p_text, ''))), '[^a-z0-9]+', '-', 'g'));
$$;

-- Extend signup: wallet + settings + prefs after profile
create or replace function public.handle_new_user_v3()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.create_wallet(new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_v3 on auth.users;
create trigger on_auth_user_created_v3
  after insert on auth.users
  for each row execute function public.handle_new_user_v3();

-- ============================================================
-- RLS (own-data pattern)
-- ============================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'user_preferences','user_socials','trusted_devices','login_history',
    'activity_history','online_status','verification','blocked_users',
    'ai_conversations','ai_messages','ai_usage','ai_feedback','ai_prompt_library',
    'ai_embeddings','workspaces','workspace_members','folders','tags','notes',
    'bookmarks','recent_items','transactions','invoices','notification_preferences',
    'push_tokens','search_history','saved_searches','tickets','ticket_messages',
    'offline_queue','sync_logs','webhooks','storage_files','tool_usage','tool_reviews'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Generic own-user policies (tables with user_id)
do $$
declare
  rec record;
  pol text;
begin
  for rec in
    select unnest(array[
      'activity_history','ai_conversations','ai_messages','ai_usage','ai_feedback',
      'ai_embeddings','folders','tags','notes','bookmarks','recent_items',
      'transactions','invoices','push_tokens','search_history','saved_searches',
      'tickets','offline_queue','sync_logs','webhooks','storage_files',
      'tool_usage','tool_reviews','trusted_devices','verification','login_history'
    ]) as tbl
  loop
    pol := rec.tbl || '_select_own';
    execute format('drop policy if exists %I on public.%I', pol, rec.tbl);
    execute format(
      'create policy %I on public.%I for select using (auth.uid() = user_id)',
      pol, rec.tbl
    );
    pol := rec.tbl || '_insert_own';
    execute format('drop policy if exists %I on public.%I', pol, rec.tbl);
    execute format(
      'create policy %I on public.%I for insert with check (auth.uid() = user_id)',
      pol, rec.tbl
    );
    pol := rec.tbl || '_update_own';
    execute format('drop policy if exists %I on public.%I', pol, rec.tbl);
    execute format(
      'create policy %I on public.%I for update using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      pol, rec.tbl
    );
    pol := rec.tbl || '_delete_own';
    execute format('drop policy if exists %I on public.%I', pol, rec.tbl);
    execute format(
      'create policy %I on public.%I for delete using (auth.uid() = user_id)',
      pol, rec.tbl
    );
  end loop;
end $$;

-- PK = user_id tables
drop policy if exists "user_preferences_all_own" on public.user_preferences;
create policy "user_preferences_all_own" on public.user_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "user_socials_all_own" on public.user_socials;
create policy "user_socials_all_own" on public.user_socials
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "online_status_all_own" on public.online_status;
create policy "online_status_all_own" on public.online_status
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "notification_preferences_all_own" on public.notification_preferences;
create policy "notification_preferences_all_own" on public.notification_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "blocked_users_all_own" on public.blocked_users;
create policy "blocked_users_all_own" on public.blocked_users
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "workspaces_select_member" on public.workspaces;
create policy "workspaces_select_member" on public.workspaces
  for select using (
    auth.uid() = owner_id
    or exists (
      select 1 from public.workspace_members m
      where m.workspace_id = id and m.user_id = auth.uid()
    )
  );

drop policy if exists "workspaces_insert_own" on public.workspaces;
create policy "workspaces_insert_own" on public.workspaces
  for insert with check (auth.uid() = owner_id);

drop policy if exists "workspaces_update_own" on public.workspaces;
create policy "workspaces_update_own" on public.workspaces
  for update using (auth.uid() = owner_id);

drop policy if exists "workspace_members_select" on public.workspace_members;
create policy "workspace_members_select" on public.workspace_members
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.workspaces w
      where w.id = workspace_id and w.owner_id = auth.uid()
    )
  );

drop policy if exists "ticket_messages_select" on public.ticket_messages;
create policy "ticket_messages_select" on public.ticket_messages
  for select using (
    exists (
      select 1 from public.tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
  );

drop policy if exists "ticket_messages_insert" on public.ticket_messages;
create policy "ticket_messages_insert" on public.ticket_messages
  for insert with check (
    exists (
      select 1 from public.tickets t
      where t.id = ticket_id and t.user_id = auth.uid()
    )
  );

-- Public read catalogs
alter table public.tool_categories enable row level security;
alter table public.tools enable row level security;
alter table public.plans enable row level security;
alter table public.ai_providers enable row level security;
alter table public.ai_models enable row level security;
alter table public.feature_flags enable row level security;
alter table public.remote_config enable row level security;
alter table public.maintenance enable row level security;

drop policy if exists "tool_categories_public_read" on public.tool_categories;
create policy "tool_categories_public_read" on public.tool_categories for select using (true);

drop policy if exists "tools_public_read" on public.tools;
create policy "tools_public_read" on public.tools for select using (is_active = true);

drop policy if exists "plans_public_read" on public.plans;
create policy "plans_public_read" on public.plans for select using (is_active = true);

drop policy if exists "ai_providers_public_read" on public.ai_providers;
create policy "ai_providers_public_read" on public.ai_providers for select using (is_active = true);

drop policy if exists "ai_models_public_read" on public.ai_models;
create policy "ai_models_public_read" on public.ai_models for select using (is_active = true);

drop policy if exists "feature_flags_public_read" on public.feature_flags;
create policy "feature_flags_public_read" on public.feature_flags for select using (true);

drop policy if exists "remote_config_public_read" on public.remote_config;
create policy "remote_config_public_read" on public.remote_config for select using (true);

drop policy if exists "maintenance_public_read" on public.maintenance;
create policy "maintenance_public_read" on public.maintenance for select using (true);

-- Seed AI providers
insert into public.ai_providers (id, display_name) values
  ('gemini', 'Google Gemini'),
  ('groq', 'Groq'),
  ('openrouter', 'OpenRouter')
on conflict (id) do nothing;

insert into public.ai_models (id, provider_id, display_name) values
  ('gemini-2.0-flash', 'gemini', 'Gemini 2.0 Flash'),
  ('llama-3.3-70b-versatile', 'groq', 'Llama 3.3 70B'),
  ('meta-llama/llama-3.3-70b-instruct:free', 'openrouter', 'Llama 3.3 70B (OpenRouter Free)')
on conflict (id) do nothing;

-- Extra storage buckets (v3)
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('voice', 'voice', false, 50 * 1024 * 1024),
  ('imports', 'imports', false, 200 * 1024 * 1024),
  ('backups', 'backups', false, 500 * 1024 * 1024),
  ('workspace', 'workspace', false, 200 * 1024 * 1024),
  ('ai', 'ai', false, 100 * 1024 * 1024),
  ('tools', 'tools', false, 100 * 1024 * 1024),
  ('public', 'public', true, 25 * 1024 * 1024),
  ('private', 'private', false, 200 * 1024 * 1024)
on conflict (id) do nothing;

-- Views
create or replace view public.user_dashboard
with (security_invoker = true)
as
select
  p.id as user_id,
  p.full_name,
  p.plan,
  p.credits as profile_credits,
  c.balance as credits_balance,
  w.balance_cents as wallet_cents,
  s.status as sub_status,
  o.last_seen_at
from public.profiles p
left join public.credits c on c.user_id = p.id
left join public.wallet w on w.user_id = p.id
left join public.subscriptions s on s.user_id = p.id
left join public.online_status o on o.user_id = p.id;

create or replace view public.wallet_summary
with (security_invoker = true)
as
select user_id, balance_cents, currency, updated_at
from public.wallet;

create or replace view public.ai_usage_summary
with (security_invoker = true)
as
select
  user_id,
  count(*) as calls,
  sum(prompt_tokens) as prompt_tokens,
  sum(completion_tokens) as completion_tokens,
  date_trunc('day', created_at) as day
from public.ai_usage
group by user_id, date_trunc('day', created_at);


-- ========== END 09_architecture_v3_foundation.sql ==========


-- ========== BEGIN 10_seed_tools_catalog.sql ==========

-- ============================================================
-- Farvixo — Seed tool catalog (generated from data/categories.ts + data/tools.ts)
-- Generated: 2026-07-15T20:38:13.790Z
-- Run AFTER 09_architecture_v3_foundation.sql
-- Regenerate: node scripts/generate-tools-seed.mjs
-- ============================================================

-- Categories
insert into public.tool_categories (slug, name, icon, accent, sort_order, tool_count, is_active) values
  ('pdf', 'PDF Tools', 'file-text', 'accent-pdf', 1, 20, true),
  ('image', 'Image Tools', 'image', 'accent-image', 2, 13, true),
  ('video', 'Video Tools', 'video', 'accent-video', 3, 8, true),
  ('audio', 'Audio Tools', 'music', 'accent-audio', 4, 8, true),
  ('ai', 'AI Tools', 'bot', 'accent-ai', 5, 12, true),
  ('developer', 'Developer Tools', 'code', 'accent-dev', 6, 10, true),
  ('text', 'Text Tools', 'type', 'accent-dev', 7, 8, true),
  ('seo', 'SEO Tools', 'search', 'accent-seo', 8, 8, true),
  ('business', 'Business Tools', 'briefcase', 'accent-business', 9, 8, true),
  ('social', 'Social Media Tools', 'share', 'accent-social', 10, 8, true),
  ('utility', 'Utility Tools', 'settings', 'accent-utility', 11, 9, true),
  ('security', 'Security Tools', 'shield', 'accent-security', 12, 8, true),
  ('calculator', 'Calculator Tools', 'calculator', 'accent-calculator', 13, 6, true),
  ('file-converter', 'File Converter Tools', 'repeat', 'accent-file', 14, 6, true),
  ('government', 'Government Tools', 'landmark', 'accent-gov', 15, 8, true)
on conflict (slug) do update set
  name = excluded.name,
  icon = excluded.icon,
  accent = excluded.accent,
  sort_order = excluded.sort_order,
  tool_count = excluded.tool_count,
  is_active = true;

-- Tools
insert into public.tools (id, slug, name, description, category_slug, icon, badge, is_ai_powered, is_active, usage_count, meta) values
  (1, 'passport-photo-maker', 'Passport Photo Maker', 'Create compliant passport photos with country presets', 'government', 'user-square', null, false, true, 0, '{"runner":"gov-photo-advanced","mode":"gov-spec","keywords":[]}'::jsonb),
  (2, 'passport-signature-resizer', 'Passport Signature Resizer', 'Resize signature to passport upload specifications', 'government', 'pen', null, false, true, 0, '{"runner":"gov-photo-advanced","mode":"gov-spec","keywords":[]}'::jsonb),
  (3, 'pan-card-photo-resizer', 'PAN Card Photo Resizer', 'AI-powered NSDL & UTI photo, signature & document resizer with 12-point compliance check', 'government', 'user-square', 'new', false, true, 0, '{"runner":"gov-photo-advanced","mode":"pan-card","keywords":[]}'::jsonb),
  (4, 'aadhaar-photo-resizer', 'Aadhaar Photo Resizer', 'Resize photo to UIDAI Aadhaar specifications', 'government', 'user-square', null, false, true, 0, '{"runner":"gov-photo-advanced","mode":"gov-spec","keywords":[]}'::jsonb),
  (5, 'aadhaar-pdf-compressor', 'Aadhaar PDF Compressor', 'Compress Aadhaar PDF to UIDAI upload size limits', 'government', 'file-down', null, false, true, 0, '{"runner":"pdf-compressor","mode":"compress","keywords":[]}'::jsonb),
  (6, 'voter-id-photo-resizer', 'Voter ID Photo Resizer', 'Resize photo to Voter ID (EPIC) specifications', 'government', 'user-square', null, false, true, 0, '{"runner":"gov-photo-advanced","mode":"gov-spec","keywords":[]}'::jsonb),
  (7, 'driving-licence-photo-resizer', 'Driving Licence Photo Resizer', 'Resize photo & signature for DL (Sarathi) uploads', 'government', 'user-square', null, false, true, 0, '{"runner":"gov-photo-advanced","mode":"gov-spec","keywords":[]}'::jsonb),
  (8, 'exam-photo-signature-resizer', 'Exam Photo & Signature Resizer', 'SSC, UPSC, IBPS, NEET compliant photo & signature', 'government', 'user-square', null, false, true, 0, '{"runner":"gov-photo-advanced","mode":"gov-spec","keywords":[]}'::jsonb),
  (9, 'pdf-converter', 'PDF Converter', 'Convert PDF to Word, Excel, PowerPoint, Images and more — or convert any file to PDF', 'pdf', 'file-text', 'popular', false, true, 0, '{"runner":"pdf-converter","mode":"smart","keywords":[]}'::jsonb),
  (10, 'pdf-editor', 'PDF Editor', 'Visual PDF editor — annotate, edit text, shapes, AI assistant', 'pdf', 'file-pen', null, false, true, 0, '{"runner":"pdf-editor","mode":"edit","keywords":[]}'::jsonb),
  (11, 'merge-pdf', 'Merge PDF', 'Merge multiple PDF files into one document — AI organize, optimize & premium merge modes', 'pdf', 'merge', 'popular', false, true, 0, '{"runner":"merge-pdf","mode":"merge","keywords":[]}'::jsonb),
  (12, 'split-pdf', 'Split PDF', 'Split a PDF into separate pages or ranges', 'pdf', 'split', null, false, true, 0, '{"runner":"pdf","mode":"split","keywords":[]}'::jsonb),
  (13, 'compress-pdf', 'PDF Compressor', 'AI-powered PDF compression — smart modes, batch queue, quality reports & 100% private', 'pdf', 'file-down', 'popular', false, true, 0, '{"runner":"pdf-compressor","mode":"compress","keywords":["compress pdf","reduce pdf size","pdf optimizer","shrink pdf","pdf compression free"]}'::jsonb),
  (14, 'pdf-ocr', 'PDF OCR', 'Make scanned PDFs searchable with OCR', 'pdf', 'scan-text', 'ai', true, true, 0, '{"runner":"ocr","mode":"pdf","keywords":[]}'::jsonb),
  (15, 'pdf-to-word', 'PDF to Word', 'Convert PDF to editable Word with AI layout repair, OCR, tables & Indic script support — 100% private', 'pdf', 'file-text', 'popular', false, true, 0, '{"runner":"pdf-to-word","mode":"pdf2word","keywords":["pdf to word","pdf to docx","scanned pdf to word","bengali pdf to word","hindi pdf to word","form 16 pdf to word","ocr pdf word"]}'::jsonb),
  (16, 'word-to-pdf', 'Word to PDF', 'Convert Word documents (DOCX) to PDF', 'pdf', 'file-text', null, false, true, 0, '{"runner":"pdf-convert","mode":"word2pdf","keywords":[]}'::jsonb),
  (17, 'pdf-to-excel', 'PDF to Excel', 'Convert PDF files to Excel sheets', 'pdf', 'table', 'popular', false, true, 0, '{"runner":"pdf-convert","mode":"pdf2excel","keywords":[]}'::jsonb),
  (18, 'excel-to-pdf', 'Excel to PDF', 'Convert Excel spreadsheets (XLSX/CSV) to PDF', 'pdf', 'table', null, false, true, 0, '{"runner":"pdf-convert","mode":"excel2pdf","keywords":[]}'::jsonb),
  (19, 'protect-pdf', 'Protect PDF', 'Add password protection to PDF files', 'pdf', 'lock', null, false, true, 0, '{"runner":"pdf","mode":"protect","keywords":[]}'::jsonb),
  (20, 'sign-pdf', 'Sign PDF', 'Draw and place your signature on a PDF', 'pdf', 'pen', null, false, true, 0, '{"runner":"pdf","mode":"sign","keywords":[]}'::jsonb),
  (129, 'image-to-pdf', 'Image to PDF', 'AI-powered image to PDF — batch upload, organize, optimize & professional PDF output', 'pdf', 'image', 'popular', false, true, 0, '{"runner":"image-to-pdf","mode":"img2pdf","keywords":["image to pdf","jpg to pdf","png to pdf","photo to pdf","convert images pdf","batch image pdf","heic to pdf"]}'::jsonb),
  (131, 'flatten-pdf', 'Flatten PDF', 'Flatten forms, annotations and layers into plain uneditable pages', 'pdf', 'stamp', 'new', false, true, 0, '{"runner":"pdf","mode":"flatten","keywords":["flatten","forms","annotations","lock content"]}'::jsonb),
  (132, 'pdf-page-numbers', 'PDF Page Numbers', 'Stamp page numbers on every page — position, format and start number', 'pdf', 'hash', 'new', false, true, 0, '{"runner":"pdf","mode":"pagenum","keywords":["page numbers","numbering","stamp","bates"]}'::jsonb),
  (133, 'pdf-overlay', 'PDF Overlay', 'Stamp a letterhead, watermark PDF or digital paper onto every page', 'pdf', 'copy', 'new', false, true, 0, '{"runner":"pdf","mode":"overlay","keywords":["overlay","letterhead","stationery","digital paper","stamp pdf"]}'::jsonb),
  (134, 'n-up-pdf', 'N-up PDF', 'Print-saver: combine 2, 4 or 8 pages onto one sheet', 'pdf', 'grid', 'new', false, true, 0, '{"runner":"pdf","mode":"nup","keywords":["n-up","2up","4up","pages per sheet","print","booklet"]}'::jsonb),
  (135, 'pdf-metadata-editor', 'PDF Metadata Editor', 'View and edit title, author, subject and keywords of a PDF', 'pdf', 'braces', 'new', false, true, 0, '{"runner":"pdf","mode":"metadata","keywords":["metadata","title","author","exif","properties"]}'::jsonb),
  (136, 'remove-pdf-pages', 'Remove PDF Pages', 'Delete selected pages from a PDF (e.g. 2, 5-7)', 'pdf', 'scissors', 'new', false, true, 0, '{"runner":"pdf","mode":"pagedel","keywords":["remove pages","delete pages"]}'::jsonb),
  (137, 'extract-pdf-pages', 'Extract PDF Pages', 'Pull selected pages out into a new PDF (e.g. 1, 3-4)', 'pdf', 'split', 'new', false, true, 0, '{"runner":"pdf","mode":"pageext","keywords":["extract pages","pull pages","select pages"]}'::jsonb),
  (21, 'image-converter', 'Image Converter', 'Convert images between PNG, JPG, WebP and more', 'image', 'image', 'popular', false, true, 0, '{"runner":"image","mode":"convert","keywords":[]}'::jsonb),
  (22, 'image-compressor', 'Image Compressor', 'Compress images up to 90% smaller with AI-powered AVIF, WebP, JPEG & PNG optimization — 100% private, runs in your browser', 'image', 'image-down', 'popular', false, true, 0, '{"runner":"image-compressor","mode":"compress","keywords":["compress","image compressor","reduce size","optimize","webp","avif","jpeg","png","batch","bulk","resize","photo compressor","compress image to 50kb","compress for passport","compress for pan card"]}'::jsonb),
  (23, 'image-resizer', 'Image Resizer', 'Resize images to exact dimensions', 'image', 'scaling', null, false, true, 0, '{"runner":"image","mode":"resize","keywords":[]}'::jsonb),
  (24, 'crop-image', 'Crop Image', 'Crop images to any size or aspect ratio', 'image', 'crop', null, false, true, 0, '{"runner":"image","mode":"crop","keywords":[]}'::jsonb),
  (25, 'rotate-flip-image', 'Rotate & Flip Image', 'Rotate or mirror images in one click', 'image', 'rotate', null, false, true, 0, '{"runner":"image","mode":"rotate","keywords":[]}'::jsonb),
  (26, 'background-remover', 'Background Remover', 'Remove background from any image with AI — ultra HD cutout, hair refine, batch & 100% private', 'image', 'eraser', 'ai', true, true, 0, '{"runner":"bg-remover-advanced","mode":"remove","keywords":["background remover","remove bg","transparent png","cutout","hair","product photo","remove background free"]}'::jsonb),
  (27, 'background-changer', 'Background Changer', 'Replace image backgrounds with colors or photos', 'image', 'wand', 'ai', true, true, 0, '{"runner":"bg-remove","mode":"change","keywords":[]}'::jsonb),
  (28, 'ai-image-upscaler', 'AI Image Upscaler', 'Upscale images 2x or 4x with enhanced detail', 'image', 'sparkles', 'ai', true, true, 0, '{"runner":"image","mode":"upscale","keywords":[]}'::jsonb),
  (29, 'ai-photo-enhancer', 'AI Photo Enhancer', 'Auto-enhance brightness, contrast and sharpness', 'image', 'sparkles', 'ai', true, true, 0, '{"runner":"image","mode":"enhance","keywords":[]}'::jsonb),
  (30, 'ai-object-remover', 'AI Object Remover', 'Brush over objects to remove them from photos', 'image', 'eraser', 'ai', true, true, 0, '{"runner":"bg-remove","mode":"object","keywords":[]}'::jsonb),
  (31, 'image-ocr', 'OCR Image', 'AI-powered OCR — handwriting, tables, IDs, 150+ languages, batch export & live preview — 100% private', 'image', 'scan-text', 'popular', true, true, 0, '{"runner":"ocr","mode":"image","keywords":["ocr","image ocr","text extraction","handwriting ocr","scan text","bengali ocr","hindi ocr","table ocr","business card ocr","aadhaar ocr","invoice ocr"]}'::jsonb),
  (32, 'watermark-image', 'Watermark Image', 'Add text or logo watermarks to images', 'image', 'stamp', null, false, true, 0, '{"runner":"image","mode":"watermark","keywords":[]}'::jsonb),
  (130, 'watermark-remover', 'Watermark Remover', 'Remove watermarks from images', 'image', 'eraser', 'popular', true, true, 0, '{"runner":"bg-remove","mode":"object","keywords":[]}'::jsonb),
  (33, 'video-converter', 'Video Converter', 'Convert videos to MP4, WebM, MKV, MOV, GIF or extract MP3/AAC — AI analysis, batch queue, social presets, 100% private FFmpeg in your browser', 'video', 'video', 'popular', false, true, 0, '{"runner":"video-converter","mode":"convert","keywords":["video converter","mp4 to webm","mkv to mp4","video to mp3","convert video","ffmpeg online","batch video convert","4k video","gif converter"]}'::jsonb),
  (34, 'video-compressor', 'Video Compressor', 'Compress video files without quality loss', 'video', 'video', 'popular', false, true, 0, '{"runner":"ffmpeg","mode":"video-compress","keywords":[]}'::jsonb),
  (35, 'video-trimmer', 'Video Trimmer', 'Cut and trim video clips precisely', 'video', 'scissors', null, false, true, 0, '{"runner":"ffmpeg","mode":"video-trim","keywords":[]}'::jsonb),
  (36, 'video-merger', 'Video Merger', 'Join multiple videos into one file', 'video', 'merge', null, false, true, 0, '{"runner":"ffmpeg","mode":"video-merge","keywords":[]}'::jsonb),
  (37, 'video-splitter', 'Video Splitter', 'Split a video into equal parts', 'video', 'split', null, false, true, 0, '{"runner":"ffmpeg","mode":"video-split","keywords":[]}'::jsonb),
  (38, 'video-watermark', 'Video Watermark', 'Add text watermarks to videos', 'video', 'stamp', null, false, true, 0, '{"runner":"ffmpeg","mode":"video-watermark","keywords":[]}'::jsonb),
  (39, 'video-to-gif', 'Video to GIF', 'Turn video clips into animated GIFs', 'video', 'film', null, false, true, 0, '{"runner":"ffmpeg","mode":"video-gif","keywords":[]}'::jsonb),
  (40, 'ai-subtitle-generator', 'AI Subtitle Generator', 'Generate SRT subtitles from video audio with AI', 'video', 'captions', 'ai', true, true, 0, '{"runner":"speech","mode":"subtitle","keywords":[]}'::jsonb),
  (41, 'audio-converter', 'Audio Converter', 'AI-powered audio converter — batch upload, smart analysis, studio presets, noise removal & 15+ formats', 'audio', 'music', 'popular', false, true, 0, '{"runner":"audio-converter","mode":"audio-convert","keywords":["audio converter","mp3 to wav","flac to mp3","convert audio","aac converter","batch audio","ffmpeg audio","podcast converter"]}'::jsonb),
  (42, 'audio-compressor', 'Audio Compressor', 'Reduce audio file size with bitrate control', 'audio', 'music', null, false, true, 0, '{"runner":"ffmpeg","mode":"audio-compress","keywords":[]}'::jsonb),
  (43, 'audio-cutter', 'Audio Cutter', 'Cut and trim audio clips', 'audio', 'scissors', null, false, true, 0, '{"runner":"ffmpeg","mode":"audio-cut","keywords":[]}'::jsonb),
  (44, 'audio-merger', 'Audio Merger', 'Join multiple audio files into one', 'audio', 'merge', null, false, true, 0, '{"runner":"ffmpeg","mode":"audio-merge","keywords":[]}'::jsonb),
  (45, 'text-to-speech', 'Text to Speech', 'Convert text into natural speech', 'audio', 'volume', 'ai', true, true, 0, '{"runner":"speech","mode":"tts","keywords":[]}'::jsonb),
  (46, 'speech-to-text', 'Speech to Text', 'Transcribe speech into text live', 'audio', 'mic', 'ai', true, true, 0, '{"runner":"speech","mode":"stt","keywords":[]}'::jsonb),
  (47, 'voice-changer', 'Voice Changer', 'Change pitch and speed of any voice recording', 'audio', 'mic', null, false, true, 0, '{"runner":"ffmpeg","mode":"voice-change","keywords":[]}'::jsonb),
  (48, 'ai-noise-remover', 'AI Noise Remover', 'Clean background noise from audio', 'audio', 'sparkles', 'ai', true, true, 0, '{"runner":"ffmpeg","mode":"denoise","keywords":[]}'::jsonb),
  (49, 'ai-chat', 'AI Chat Assistant', 'Advanced AI chat with 6 personas, chat history, PDF Q&A, streaming, markdown & full controls', 'ai', 'bot', 'ai', true, true, 0, '{"runner":"ai-chat","mode":"chat","keywords":["ai chat","chatgpt alternative","gemini chat","ai assistant free","pdf chat"]}'::jsonb),
  (50, 'ai-writer', 'AI Writer', 'AI writer, paraphraser, summarizer', 'ai', 'pen', 'new', true, true, 0, '{"runner":"ai-text","mode":"writer","keywords":[]}'::jsonb),
  (51, 'ai-image-generator', 'AI Image Generator', 'Create stunning images with AI', 'ai', 'sparkles', 'new', true, true, 0, '{"runner":"ai-image","mode":"generate","keywords":[]}'::jsonb),
  (52, 'ai-resume-builder', 'AI Resume Builder', 'Build a professional resume PDF with AI polish', 'ai', 'file-text', 'ai', true, true, 0, '{"runner":"resume","mode":"resume","keywords":[]}'::jsonb),
  (53, 'ai-translator', 'AI Translator', 'Translate text between 100+ languages', 'ai', 'globe', 'ai', true, true, 0, '{"runner":"ai-text","mode":"translator","keywords":[]}'::jsonb),
  (54, 'ai-summarizer', 'AI Summarizer', 'Summarize long text into key points', 'ai', 'list', 'ai', true, true, 0, '{"runner":"ai-text","mode":"summarizer","keywords":[]}'::jsonb),
  (55, 'ai-email-writer', 'AI Email Writer', 'Draft professional emails in seconds', 'ai', 'mail', 'ai', true, true, 0, '{"runner":"ai-text","mode":"email","keywords":[]}'::jsonb),
  (56, 'ai-seo-writer', 'AI SEO Writer', 'Generate SEO-optimized articles from keywords', 'ai', 'search', 'ai', true, true, 0, '{"runner":"ai-text","mode":"seo-writer","keywords":[]}'::jsonb),
  (57, 'ai-code-generator', 'AI Code Generator', 'Generate code snippets in any language', 'ai', 'code', 'ai', true, true, 0, '{"runner":"ai-text","mode":"code","keywords":[]}'::jsonb),
  (58, 'ai-research-assistant', 'AI Research Assistant', 'Get synthesized answers to research questions', 'ai', 'search', 'ai', true, true, 0, '{"runner":"ai-text","mode":"research","keywords":[]}'::jsonb),
  (59, 'ai-presentation-maker', 'AI Presentation Maker', 'Turn a topic into a downloadable PPTX deck', 'ai', 'presentation', 'ai', true, true, 0, '{"runner":"presentation","mode":"pptx","keywords":[]}'::jsonb),
  (60, 'ai-pdf-assistant', 'AI PDF Assistant', 'Upload a PDF and ask questions about it', 'ai', 'file-text', 'ai', true, true, 0, '{"runner":"ai-chat","mode":"pdf","keywords":[]}'::jsonb),
  (138, 'gradient-generator', 'AI Gradient Generator', 'Design studio for gradients — AI prompt, image palette extraction, mesh/aurora/noise types, animation & 6 export formats', 'developer', 'wand', 'ai', true, true, 0, '{"runner":"gradient","mode":"studio","keywords":["gradient","css gradient","mesh gradient","aurora","background","tailwind gradient","color palette","design"]}'::jsonb),
  (139, 'world-weather-pro', 'World Weather Pro', 'Live weather, hourly timeline, 7 & 14-day forecast, air quality index, interactive radar map, astronomy & AI insights for any city — free, no signup', 'utility', 'cloud', 'new', false, true, 0, '{"runner":"weather","mode":"pro","keywords":["weather","live weather","weather today","forecast","weather forecast","temperature","air quality","aqi","humidity","wind speed","sunrise","sunset","moon phase","hourly forecast","7 day forecast","14 day forecast","weather radar map","rain forecast","weather near me"]}'::jsonb),
  (139, 'html-viewer', 'HTML Online Viewer', 'Advanced in-browser IDE — live HTML/CSS/JS editor, sandboxed preview, device simulation, console, AI fix/improve/generate & ZIP export', 'developer', 'code', 'new', false, true, 0, '{"runner":"html-viewer","mode":"ide","keywords":["html viewer","html editor","live preview","code playground","css","javascript","codepen","online ide","html tester","sandbox","responsive preview"]}'::jsonb),
  (61, 'json-formatter', 'JSON Formatter', 'Pretty-print and minify JSON', 'developer', 'braces', 'popular', false, true, 0, '{"runner":"dev","mode":"json-format","keywords":[]}'::jsonb),
  (62, 'json-validator', 'JSON Validator', 'Validate JSON and locate syntax errors', 'developer', 'braces', null, false, true, 0, '{"runner":"dev","mode":"json-validate","keywords":[]}'::jsonb),
  (63, 'base64-encoder-decoder', 'Base64 Encoder & Decoder', 'Encode and decode Base64 text and files', 'developer', 'binary', null, false, true, 0, '{"runner":"dev","mode":"base64","keywords":[]}'::jsonb),
  (64, 'url-encoder-decoder', 'URL Encoder & Decoder', 'Encode and decode URL components', 'developer', 'link', null, false, true, 0, '{"runner":"dev","mode":"url","keywords":[]}'::jsonb),
  (65, 'jwt-decoder', 'JWT Decoder', 'Decode JWT header and payload instantly', 'developer', 'key', null, false, true, 0, '{"runner":"dev","mode":"jwt","keywords":[]}'::jsonb),
  (66, 'uuid-generator', 'UUID Generator', 'Generate v4 UUIDs in bulk', 'developer', 'hash', null, false, true, 0, '{"runner":"dev","mode":"uuid","keywords":[]}'::jsonb),
  (67, 'hash-generator', 'Hash Generator', 'MD5, SHA-1, SHA-256, SHA-512 from text or files', 'developer', 'hash', null, false, true, 0, '{"runner":"security","mode":"hash-all","keywords":[]}'::jsonb),
  (68, 'api-tester', 'API Tester', 'Send HTTP requests and inspect responses', 'developer', 'send', null, false, true, 0, '{"runner":"dev","mode":"api-test","keywords":[]}'::jsonb),
  (69, 'case-converter', 'Case Converter', 'UPPER, lower, Title, camelCase, snake_case & more', 'text', 'type', 'popular', false, true, 0, '{"runner":"text","mode":"case","keywords":[]}'::jsonb),
  (70, 'word-counter', 'Word Counter', 'Count words, characters, sentences and reading time', 'text', 'type', null, false, true, 0, '{"runner":"text","mode":"count","keywords":[]}'::jsonb),
  (71, 'character-counter', 'Character Counter', 'Live character count with and without spaces', 'text', 'type', null, false, true, 0, '{"runner":"text","mode":"count","keywords":[]}'::jsonb),
  (72, 'text-compare', 'Text Compare', 'Compare two texts and highlight differences', 'text', 'split', null, false, true, 0, '{"runner":"text","mode":"compare","keywords":[]}'::jsonb),
  (73, 'remove-duplicate-lines', 'Remove Duplicate Lines', 'De-duplicate lines in any text list', 'text', 'list', null, false, true, 0, '{"runner":"text","mode":"dedupe","keywords":[]}'::jsonb),
  (74, 'reverse-text', 'Reverse Text', 'Reverse text, words or lines', 'text', 'repeat', null, false, true, 0, '{"runner":"text","mode":"reverse","keywords":[]}'::jsonb),
  (75, 'text-sorter', 'Text Sorter', 'Sort lines A→Z, Z→A, by length or randomly', 'text', 'list', null, false, true, 0, '{"runner":"text","mode":"sort","keywords":[]}'::jsonb),
  (76, 'lorem-ipsum-generator', 'Lorem Ipsum Generator', 'Generate placeholder text instantly', 'text', 'type', null, false, true, 0, '{"runner":"text","mode":"lorem","keywords":[]}'::jsonb),
  (77, 'seo-analyzer', 'SEO Analyzer', 'Audit any URL for on-page SEO issues', 'seo', 'search', 'popular', false, true, 0, '{"runner":"seo","mode":"analyze","keywords":[]}'::jsonb),
  (78, 'meta-tag-generator', 'Meta Tag Generator', 'Generate complete HTML meta tag snippets', 'seo', 'code', null, false, true, 0, '{"runner":"seo","mode":"meta","keywords":[]}'::jsonb),
  (79, 'sitemap-generator', 'Sitemap Generator', 'Build sitemap.xml from a list of URLs', 'seo', 'list', null, false, true, 0, '{"runner":"seo","mode":"sitemap","keywords":[]}'::jsonb),
  (80, 'robots-txt-generator', 'Robots.txt Generator', 'Create robots.txt rules visually', 'seo', 'bot', null, false, true, 0, '{"runner":"seo","mode":"robots","keywords":[]}'::jsonb),
  (81, 'open-graph-generator', 'Open Graph Generator', 'Generate OG tags for social sharing', 'seo', 'share', null, false, true, 0, '{"runner":"seo","mode":"og","keywords":[]}'::jsonb),
  (82, 'schema-markup-generator', 'Schema Markup Generator', 'Generate JSON-LD structured data', 'seo', 'braces', null, false, true, 0, '{"runner":"seo","mode":"schema","keywords":[]}'::jsonb),
  (83, 'keyword-density-checker', 'Keyword Density Checker', 'Analyze keyword frequency in content', 'seo', 'search', null, false, true, 0, '{"runner":"seo","mode":"density","keywords":[]}'::jsonb),
  (84, 'canonical-url-generator', 'Canonical URL Generator', 'Generate canonical link tags', 'seo', 'link', null, false, true, 0, '{"runner":"seo","mode":"canonical","keywords":[]}'::jsonb),
  (85, 'qr-code-generator', 'QR Code Generator', 'Create QR codes for links, text and Wi-Fi', 'utility', 'qr', 'popular', false, true, 0, '{"runner":"utility","mode":"qr","keywords":[]}'::jsonb),
  (86, 'barcode-generator', 'Barcode Generator', 'Generate CODE128, EAN and UPC barcodes', 'utility', 'barcode', null, false, true, 0, '{"runner":"utility","mode":"barcode","keywords":[]}'::jsonb),
  (87, 'password-generator', 'Password Generator', 'Generate strong random passwords', 'utility', 'key', 'popular', false, true, 0, '{"runner":"utility","mode":"password","keywords":[]}'::jsonb),
  (88, 'password-strength-checker', 'Password Strength Checker', 'Test password strength and crack time', 'utility', 'shield', null, false, true, 0, '{"runner":"utility","mode":"password-strength","keywords":[]}'::jsonb),
  (89, 'unit-converter', 'Unit Converter', 'Convert length, weight, temperature and more', 'utility', 'repeat', null, false, true, 0, '{"runner":"utility","mode":"unit","keywords":[]}'::jsonb),
  (90, 'currency-converter', 'Currency Converter', 'Convert currencies with live exchange rates', 'utility', 'globe', null, false, true, 0, '{"runner":"utility","mode":"currency","keywords":[]}'::jsonb),
  (91, 'timestamp-converter', 'Timestamp Converter', 'Convert Unix timestamps to human dates', 'utility', 'clock', null, false, true, 0, '{"runner":"utility","mode":"timestamp","keywords":[]}'::jsonb),
  (92, 'random-number-generator', 'Random Number Generator', 'Generate random numbers in any range', 'utility', 'hash', null, false, true, 0, '{"runner":"utility","mode":"random","keywords":[]}'::jsonb),
  (93, 'md5-generator', 'MD5 Generator', 'Generate MD5 hashes from text or files', 'security', 'hash', null, false, true, 0, '{"runner":"security","mode":"md5","keywords":[]}'::jsonb),
  (94, 'sha1-generator', 'SHA1 Generator', 'Generate SHA-1 hashes from text or files', 'security', 'hash', null, false, true, 0, '{"runner":"security","mode":"sha1","keywords":[]}'::jsonb),
  (95, 'sha256-generator', 'SHA256 Generator', 'Generate SHA-256 hashes from text or files', 'security', 'hash', null, false, true, 0, '{"runner":"security","mode":"sha256","keywords":[]}'::jsonb),
  (96, 'sha512-generator', 'SHA512 Generator', 'Generate SHA-512 hashes from text or files', 'security', 'hash', null, false, true, 0, '{"runner":"security","mode":"sha512","keywords":[]}'::jsonb),
  (97, 'file-checksum-generator', 'File Checksum Generator', 'Verify file integrity with checksums', 'security', 'shield', null, false, true, 0, '{"runner":"security","mode":"checksum","keywords":[]}'::jsonb),
  (98, 'ssl-checker', 'SSL Checker', 'Check SSL certificate details of any domain', 'security', 'lock', null, false, true, 0, '{"runner":"security","mode":"ssl","keywords":[]}'::jsonb),
  (99, 'url-scanner', 'URL Scanner', 'Scan URLs for safety red flags', 'security', 'search', null, false, true, 0, '{"runner":"security","mode":"url-scan","keywords":[]}'::jsonb),
  (100, 'encryption-tool', 'Encryption Tool', 'AES-256 encrypt and decrypt text with a passphrase', 'security', 'lock', null, false, true, 0, '{"runner":"security","mode":"encrypt","keywords":[]}'::jsonb),
  (101, 'invoice-generator', 'Invoice Generator', 'Create professional invoice PDFs', 'business', 'file-text', 'popular', false, true, 0, '{"runner":"business","mode":"invoice","keywords":[]}'::jsonb),
  (102, 'gst-calculator', 'GST Calculator', 'Calculate GST inclusive and exclusive amounts', 'business', 'calculator', null, false, true, 0, '{"runner":"business","mode":"gst","keywords":[]}'::jsonb),
  (103, 'emi-calculator', 'EMI Calculator', 'Calculate loan EMI with full schedule', 'business', 'calculator', null, false, true, 0, '{"runner":"calculator","mode":"emi","keywords":[]}'::jsonb),
  (104, 'profit-margin-calculator', 'Profit Margin Calculator', 'Calculate margin, markup and profit', 'business', 'calculator', null, false, true, 0, '{"runner":"business","mode":"margin","keywords":[]}'::jsonb),
  (105, 'salary-calculator', 'Salary Calculator', 'CTC to in-hand salary breakdown', 'business', 'calculator', null, false, true, 0, '{"runner":"business","mode":"salary","keywords":[]}'::jsonb),
  (106, 'receipt-generator', 'Receipt Generator', 'Generate payment receipt PDFs', 'business', 'file-text', null, false, true, 0, '{"runner":"business","mode":"receipt","keywords":[]}'::jsonb),
  (107, 'business-card-generator', 'Business Card Generator', 'Design and download business cards', 'business', 'user-square', null, false, true, 0, '{"runner":"business","mode":"card","keywords":[]}'::jsonb),
  (108, 'quotation-generator', 'Quotation Generator', 'Create quotation PDFs for clients', 'business', 'file-text', null, false, true, 0, '{"runner":"business","mode":"quotation","keywords":[]}'::jsonb),
  (109, 'youtube-thumbnail-downloader', 'YouTube Thumbnail Downloader', 'Download YouTube thumbnails in HD', 'social', 'video', 'popular', false, true, 0, '{"runner":"social","mode":"yt-thumb","keywords":[]}'::jsonb),
  (110, 'instagram-dp-downloader', 'Instagram DP Downloader', 'View and download Instagram profile photos', 'social', 'image', null, false, true, 0, '{"runner":"social","mode":"ig-dp","keywords":[]}'::jsonb),
  (111, 'instagram-caption-generator', 'Instagram Caption Generator', 'AI captions for your posts', 'social', 'pen', 'ai', true, true, 0, '{"runner":"ai-text","mode":"ig-caption","keywords":[]}'::jsonb),
  (112, 'hashtag-generator', 'Hashtag Generator', 'AI hashtag sets for any topic', 'social', 'hash', 'ai', true, true, 0, '{"runner":"ai-text","mode":"hashtags","keywords":[]}'::jsonb),
  (113, 'youtube-thumbnail-maker', 'YouTube Thumbnail Maker', 'Design 1280×720 thumbnails in your browser', 'social', 'image', null, false, true, 0, '{"runner":"social","mode":"thumb-maker","keywords":[]}'::jsonb),
  (114, 'youtube-tag-generator', 'YouTube Tag Generator', 'AI video tags for better reach', 'social', 'hash', 'ai', true, true, 0, '{"runner":"ai-text","mode":"yt-tags","keywords":[]}'::jsonb),
  (115, 'social-media-post-generator', 'Social Media Post Generator', 'AI post copy for any platform', 'social', 'share', 'ai', true, true, 0, '{"runner":"ai-text","mode":"post","keywords":[]}'::jsonb),
  (116, 'bio-generator', 'Bio Generator', 'AI bios for Instagram, X and LinkedIn', 'social', 'user-square', 'ai', true, true, 0, '{"runner":"ai-text","mode":"bio","keywords":[]}'::jsonb),
  (117, 'age-calculator', 'Age Calculator Pro', 'Exact age in years, months, days, hours & seconds — birthday countdown, zodiac, milestones, life stats & AI insights', 'calculator', 'clock', 'popular', false, true, 0, '{"runner":"age-calc","mode":"pro","keywords":["age calculator","date of birth","how old am i","birthday countdown","zodiac sign","life expectancy","milestones"]}'::jsonb),
  (118, 'bmi-calculator', 'BMI Calculator', 'Body mass index with category', 'calculator', 'calculator', null, false, true, 0, '{"runner":"calculator","mode":"bmi","keywords":[]}'::jsonb),
  (119, 'percentage-calculator', 'Percentage Calculator', 'All percentage calculations in one place', 'calculator', 'calculator', null, false, true, 0, '{"runner":"calculator","mode":"percentage","keywords":[]}'::jsonb),
  (120, 'loan-emi-calculator', 'Loan EMI Calculator', 'EMI, total interest and payment schedule', 'calculator', 'calculator', null, false, true, 0, '{"runner":"calculator","mode":"emi","keywords":[]}'::jsonb),
  (121, 'discount-calculator', 'Discount Calculator', 'Final price after discount and savings', 'calculator', 'calculator', null, false, true, 0, '{"runner":"calculator","mode":"discount","keywords":[]}'::jsonb),
  (122, 'scientific-calculator', 'Scientific Calculator', 'Full scientific calculator in your browser', 'calculator', 'calculator', null, false, true, 0, '{"runner":"calculator","mode":"scientific","keywords":[]}'::jsonb),
  (123, 'zip-creator', 'ZIP Creator', 'Compress files into a ZIP archive', 'file-converter', 'folder', 'popular', false, true, 0, '{"runner":"file-convert","mode":"zip-create","keywords":[]}'::jsonb),
  (124, 'zip-extractor', 'ZIP Extractor', 'Extract files from ZIP archives', 'file-converter', 'folder', null, false, true, 0, '{"runner":"file-convert","mode":"zip-extract","keywords":[]}'::jsonb),
  (125, 'csv-to-excel', 'CSV to Excel', 'Convert CSV files to Excel (XLSX)', 'file-converter', 'table', null, false, true, 0, '{"runner":"file-convert","mode":"csv2xlsx","keywords":[]}'::jsonb),
  (126, 'excel-to-csv', 'Excel to CSV', 'Convert Excel sheets to CSV', 'file-converter', 'table', null, false, true, 0, '{"runner":"file-convert","mode":"xlsx2csv","keywords":[]}'::jsonb),
  (127, 'xml-to-json', 'XML to JSON', 'Convert XML documents to JSON', 'file-converter', 'braces', null, false, true, 0, '{"runner":"file-convert","mode":"xml2json","keywords":[]}'::jsonb),
  (128, 'json-to-xml', 'JSON to XML', 'Convert JSON data to XML', 'file-converter', 'braces', null, false, true, 0, '{"runner":"file-convert","mode":"json2xml","keywords":[]}'::jsonb)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  category_slug = excluded.category_slug,
  icon = excluded.icon,
  badge = excluded.badge,
  is_ai_powered = excluded.is_ai_powered,
  is_active = true,
  meta = excluded.meta,
  updated_at = now();

-- Align serial sequence with max(id)
select setval(pg_get_serial_sequence('public.tools', 'id'), coalesce((select max(id) from public.tools), 1));

update public.tool_categories c
set tool_count = (
  select count(*)::int from public.tools t where t.category_slug = c.slug and t.is_active
);

-- Done: 15 categories, 140 tools


-- ========== END 10_seed_tools_catalog.sql ==========


-- ========== BEGIN 02_promote_super_admin.sql ==========

-- ============================================================
-- Farvixo Tools — Promote super admin by email (safe to re-run)
-- Run AFTER schema.sql and after the user has signed up OR
-- after scripts/bootstrap-admin.mjs created the account.
-- ============================================================

UPDATE public.profiles
SET
  role = 'SUPER_ADMIN',
  plan = 'ENTERPRISE',
  full_name = COALESCE(full_name, 'Faruk Mondal'),
  updated_at = now()
WHERE id = (
  SELECT id FROM auth.users
  WHERE lower(email) = lower('farukmondal106@gmail.com')
  LIMIT 1
);

-- Verify (optional — check result in Supabase SQL editor)
SELECT p.id, u.email, p.full_name, p.role, p.plan
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
WHERE lower(u.email) = lower('farukmondal106@gmail.com');


-- ========== END 02_promote_super_admin.sql ==========
