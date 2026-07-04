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
  created_at timestamptz not null default now()
);

create index if not exists shares_token_idx on public.shares (token);
create index if not exists shares_expires_idx on public.shares (expires_at);

alter table public.shares enable row level security;
-- No public policies: only the service-role key (server) reads/writes shares.

-- Private storage bucket for shared files (25MB per object).
insert into storage.buckets (id, name, public, file_size_limit)
values ('shares', 'shares', false, 26214400)
on conflict (id) do nothing;
