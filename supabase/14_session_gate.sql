-- 14_session_gate.sql
-- Immediate session enforcement gate used by middleware. One lightweight lookup
-- returning a single reason string for the CALLER's own account + device.
-- SECURITY INVOKER: runs as the authenticated user and relies on the existing
-- select-own RLS on profiles + user_sessions (no privilege escalation).

create or replace function public.session_gate(p_device_id text)
returns text
language sql
stable
security invoker
set search_path = public
as $$
  select case
    when p.deleted_at is not null then 'deleted'
    when p.is_banned then 'banned'
    when p.suspended_until is not null and p.suspended_until > now() then 'suspended'
    when s.revoked_at is not null then 'revoked'
    else ''
  end
  from public.profiles p
  left join public.user_sessions s
    on s.user_id = p.id and s.device_id = p_device_id
  where p.id = auth.uid();
$$;

revoke all on function public.session_gate(text) from public, anon;
grant execute on function public.session_gate(text) to authenticated;
