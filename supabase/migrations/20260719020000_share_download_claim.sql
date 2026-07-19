-- Migration: atomic share-download slot claim/release (fixes P2 #2 TOCTOU race)
--
-- The download-limit check in app/api/share/[token]/route.ts read `downloads`
-- and wrote `downloads + 1` in two separate steps, so concurrent requests could
-- over-download one-time / limited links. These RPCs make claim and release
-- atomic. Both are service_role-only.

-- Atomically claim a download slot: increments `downloads` only while the link
-- is unexpired and under its limit. Returns true iff a slot was claimed.
create or replace function public.claim_share_download(p_token text)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_ok boolean;
begin
  update public.shares
     set downloads = downloads + 1
   where token = p_token
     and expires_at > now()
     and (max_downloads is null or downloads < max_downloads)
  returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

-- Compensating release: atomically decrement a previously claimed slot when the
-- download could not be completed (e.g. signed-URL generation failed). Never
-- goes below zero.
create or replace function public.release_share_download(p_token text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.shares
     set downloads = greatest(downloads - 1, 0)
   where token = p_token;
end;
$$;

revoke all on function public.claim_share_download(text) from public, anon, authenticated;
revoke all on function public.release_share_download(text) from public, anon, authenticated;
-- service_role (server admin client) retains execute implicitly.
