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
