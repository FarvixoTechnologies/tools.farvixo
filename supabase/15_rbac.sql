-- 15_rbac.sql — Enterprise RBAC: roles (inheritance), permissions (grouped),
-- role_permissions matrix, admin_invitations. Keys match existing
-- profiles.role values (USER/ADMIN/SUPER_ADMIN); custom roles allowed.
-- (See migrations rbac_roles_permissions + rbac_rpc_rls_realtime for the
-- authoritative applied version.)

create table if not exists public.roles (
  key text primary key, name text not null, description text,
  is_system boolean not null default false,
  inherits_from text references public.roles(key) on delete set null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.permissions (
  key text primary key, resource text not null, action text not null,
  description text, group_name text not null default 'General',
  created_at timestamptz not null default now()
);
create table if not exists public.role_permissions (
  role_key text not null references public.roles(key) on delete cascade,
  permission_key text not null references public.permissions(key) on delete cascade,
  primary key (role_key, permission_key)
);
create table if not exists public.admin_invitations (
  id uuid primary key default gen_random_uuid(),
  email text not null, role_key text not null references public.roles(key) on delete cascade,
  token text not null unique, status text not null default 'pending',
  invited_by uuid references auth.users(id) on delete set null,
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_at timestamptz not null default now(), accepted_at timestamptz
);
create index if not exists role_permissions_role_idx on public.role_permissions (role_key);
create index if not exists admin_invitations_email_idx on public.admin_invitations (email);
create index if not exists admin_invitations_status_idx on public.admin_invitations (status);

insert into public.roles (key, name, description, is_system, inherits_from, sort_order) values
  ('USER','User','Standard end-user, no admin access.',true,null,0),
  ('ADMIN','Admin','Operational admin. Inherits User.',true,'USER',1),
  ('SUPER_ADMIN','Super Admin','Full control. Inherits Admin.',true,'ADMIN',2)
on conflict (key) do nothing;

insert into public.permissions (key, resource, action, description, group_name) values
  ('users.read','users','read','View users','Users'),
  ('users.write','users','write','Edit users, plans, credits','Users'),
  ('users.suspend','users','suspend','Ban / suspend / restore','Users'),
  ('users.delete','users','delete','Delete users','Users'),
  ('roles.read','roles','read','View roles & permissions','Roles'),
  ('roles.write','roles','write','Create / edit roles','Roles'),
  ('roles.delete','roles','delete','Delete roles','Roles'),
  ('roles.invite','roles','invite','Invite / provision admins','Roles'),
  ('tools.read','tools','read','View tools & jobs','Tools'),
  ('tools.write','tools','write','Manage tools & categories','Tools'),
  ('content.read','content','read','View content','Content'),
  ('content.write','content','write','Manage blogs / ads / email','Content'),
  ('billing.read','billing','read','View subscriptions & credits','Billing'),
  ('billing.write','billing','write','Manage plans / promos','Billing'),
  ('ai.read','ai','read','View AI usage','AI'),
  ('ai.manage','ai','manage','Manage providers & limits','AI'),
  ('support.read','support','read','View tickets & messages','Support'),
  ('support.write','support','write','Reply / assign tickets','Support'),
  ('security.read','security','read','View audit & security logs','Security'),
  ('security.manage','security','manage','Manage IP bans & sessions','Security'),
  ('system.read','system','read','View system health','System'),
  ('system.manage','system','manage','Manage config & maintenance','System')
on conflict (key) do nothing;

insert into public.role_permissions (role_key, permission_key)
select 'ADMIN', key from public.permissions
where key not in ('roles.delete','users.delete','system.manage','security.manage','roles.write')
on conflict do nothing;
insert into public.role_permissions (role_key, permission_key)
select 'SUPER_ADMIN', key from public.permissions on conflict do nothing;
