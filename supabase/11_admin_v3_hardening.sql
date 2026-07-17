-- Admin v3 hardening: lock privileged profile columns + RLS on admin tables
-- Applied via MCP on project bujpwwxanaejfcyuigth

create or replace function public.protect_profile_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'Cannot change role';
  end if;
  if new.plan is distinct from old.plan then
    raise exception 'Cannot change plan';
  end if;
  if new.credits is distinct from old.credits then
    raise exception 'Cannot change credits';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_profile_privileged on public.profiles;
create trigger trg_protect_profile_privileged
  before update on public.profiles
  for each row
  execute procedure public.protect_profile_privileged_columns();

alter table if exists public.promo_codes enable row level security;
alter table if exists public.failed_logins enable row level security;
alter table if exists public.blocked_ips enable row level security;
alter table if exists public.security_events enable row level security;
alter table if exists public.webhook_logs enable row level security;
alter table if exists public.background_tasks enable row level security;
alter table if exists public.deleted_accounts enable row level security;
