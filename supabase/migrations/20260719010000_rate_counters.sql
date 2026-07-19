-- Migration: durable distributed rate counter (fixes P1 #2 anonymous quota bypass)
--
-- The in-memory rate limiter (lib/rate-limit.ts) is per-serverless-instance and
-- does not hold across Cloudflare Pages isolates. This table + RPC provide a
-- strongly-consistent, global daily counter reused by the AI endpoints for
-- anonymous callers (authenticated users flow through ai_usage / checkQuota).

create table if not exists public.rate_counters (
  bucket       text    not null,
  identity     text    not null,        -- sha256(ip + RATE_LIMIT_SECRET) hash or user id; no raw PII
  window_start date    not null,        -- UTC day bucket
  count        integer not null default 0,
  primary key (bucket, identity, window_start)
);

alter table public.rate_counters enable row level security;  -- no policies → service_role only

-- Atomically increment the counter for (bucket, identity, day) and return the
-- new count. The caller compares the returned value against its own limit.
create or replace function public.incr_rate_counter(
  p_bucket   text,
  p_identity text,
  p_window   date default (now() at time zone 'utc')::date
) returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_count integer;
begin
  insert into public.rate_counters (bucket, identity, window_start, count)
  values (p_bucket, p_identity, p_window, 1)
  on conflict (bucket, identity, window_start)
  do update set count = public.rate_counters.count + 1
  returning count into v_count;
  return v_count;
end;
$$;

revoke all on function public.incr_rate_counter(text, text, date)
  from public, anon, authenticated;
-- service_role (server admin client) retains execute implicitly.
