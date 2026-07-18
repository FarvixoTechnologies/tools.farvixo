-- 19_ai_key_vault.sql — Real at-rest encryption for AI provider API keys via
-- Supabase Vault (pgsodium). ai_api_keys stores only vault_secret_id + a masked
-- preview. ai_key_store/ai_key_read are SECURITY DEFINER, service_role only.
-- (Authoritative version applied via migration ai_key_vault_encryption.)

alter table public.ai_api_keys add column if not exists vault_secret_id uuid;

create or replace function public.ai_key_store(p_secret text, p_name text)
returns uuid language plpgsql security definer set search_path = vault, public as $$
declare v_id uuid;
begin
  v_id := vault.create_secret(p_secret, p_name || '-' || gen_random_uuid()::text, 'AI provider API key');
  return v_id;
end; $$;

create or replace function public.ai_key_read(p_id uuid)
returns text language sql stable security definer set search_path = vault, public as $$
  select decrypted_secret from vault.decrypted_secrets where id = p_id;
$$;

revoke all on function public.ai_key_store(text, text) from public, anon, authenticated;
revoke all on function public.ai_key_read(uuid) from public, anon, authenticated;
grant execute on function public.ai_key_store(text, text) to service_role;
grant execute on function public.ai_key_read(uuid) to service_role;
