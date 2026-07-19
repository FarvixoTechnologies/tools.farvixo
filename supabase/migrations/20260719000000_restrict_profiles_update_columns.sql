-- Migration: restrict column-level UPDATE on public.profiles
-- Fixes P0 #2 — privilege escalation via RLS.
--
-- The RLS policy "profiles_update_own" authorizes a user to update their OWN
-- row but does NOT restrict which columns change, allowing an authenticated
-- user to rewrite role / plan / stripe_* / tools_used_today on their own row.
-- role / plan / stripe_* / tools_used_today are managed only server-side via
-- the service_role client (which bypasses these column grants).
--
-- This migration leaves the RLS policy, INSERT/DELETE/SELECT grants, RPC
-- functions, and service_role permissions unchanged. It only tightens the
-- UPDATE column privileges for anon / authenticated.

revoke update on public.profiles from anon, authenticated;
grant update (full_name, avatar_url, updated_at) on public.profiles to authenticated;
