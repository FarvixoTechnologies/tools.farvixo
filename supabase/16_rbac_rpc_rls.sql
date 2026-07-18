-- 16_rbac_rpc_rls.sql — RBAC inheritance RPCs, RLS, realtime.

create or replace function public.role_effective_permissions(p_role text)
returns table(permission_key text) language sql stable security invoker
set search_path = public as $$
  with recursive chain as (
    select key, inherits_from from public.roles where key = p_role
    union all
    select r.key, r.inherits_from from public.roles r join chain c on r.key = c.inherits_from
  )
  select distinct rp.permission_key from chain c
  join public.role_permissions rp on rp.role_key = c.key;
$$;

create or replace function public.current_user_has_permission(p_perm text)
returns boolean language sql stable security invoker set search_path = public as $$
  select exists (
    select 1 from public.profiles pr
    join public.role_effective_permissions(pr.role) ep on ep.permission_key = p_perm
    where pr.id = auth.uid()
  );
$$;

revoke all on function public.role_effective_permissions(text) from public, anon;
revoke all on function public.current_user_has_permission(text) from public, anon;
grant execute on function public.role_effective_permissions(text) to authenticated;
grant execute on function public.current_user_has_permission(text) to authenticated;

alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.admin_invitations enable row level security;

drop policy if exists roles_read on public.roles;
create policy roles_read on public.roles for select to authenticated using (true);
drop policy if exists permissions_read on public.permissions;
create policy permissions_read on public.permissions for select to authenticated using (true);
drop policy if exists role_permissions_read on public.role_permissions;
create policy role_permissions_read on public.role_permissions for select to authenticated using (true);
drop policy if exists admin_invitations_read_own on public.admin_invitations;
create policy admin_invitations_read_own on public.admin_invitations for select to authenticated
  using (lower(email) = lower(coalesce((auth.jwt() ->> 'email'), '')));

alter publication supabase_realtime add table public.roles;
alter publication supabase_realtime add table public.role_permissions;
alter publication supabase_realtime add table public.admin_invitations;
