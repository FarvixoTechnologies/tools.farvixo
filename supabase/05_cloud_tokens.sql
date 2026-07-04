-- OAuth tokens for Google Drive / Dropbox cloud integrations.

create table if not exists public.user_cloud_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('google', 'dropbox')),
  access_token text not null,
  refresh_token text,
  expires_at timestamptz,
  scope text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider)
);

create index if not exists user_cloud_tokens_user_idx on public.user_cloud_tokens (user_id);

alter table public.user_cloud_tokens enable row level security;

create policy "Users read own cloud tokens"
  on public.user_cloud_tokens for select
  using (auth.uid() = user_id);

create policy "Users delete own cloud tokens"
  on public.user_cloud_tokens for delete
  using (auth.uid() = user_id);
