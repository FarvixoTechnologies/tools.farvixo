-- 12_user_lifecycle.sql
-- User Management lifecycle: temporary suspension + soft delete/restore.
-- Ban already exists (is_banned/banned_at/ban_reason). These add Suspend and
-- Delete/Restore states used by the admin Users panel.

alter table public.profiles
  add column if not exists suspended_until  timestamptz,
  add column if not exists suspended_at     timestamptz,
  add column if not exists suspended_reason text,
  add column if not exists deleted_at       timestamptz,
  add column if not exists deleted_by       uuid references auth.users(id) on delete set null;

create index if not exists profiles_deleted_at_idx     on public.profiles (deleted_at);
create index if not exists profiles_suspended_until_idx on public.profiles (suspended_until);

comment on column public.profiles.suspended_until is 'When set and in the future, the account is temporarily suspended.';
comment on column public.profiles.deleted_at       is 'Soft-delete marker; hidden from the default admin list and restorable.';
