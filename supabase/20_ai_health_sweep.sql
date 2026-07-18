-- 20_ai_health_sweep.sql — Background health sweep (pure SQL; pg_cron/external
-- scheduler friendly). Auto-disables providers with a high recent failure rate.
-- Authoritative version applied via migration ai_health_sweep.

create or replace function public.ai_health_sweep()
returns integer language plpgsql security definer set search_path = public as $$
declare v_disabled integer := 0;
begin
  with stats as (
    select provider_id, count(*) as total, count(*) filter (where status='error') as errors
    from public.ai_usage where created_at >= now() - interval '6 hours' group by provider_id
  ),
  unhealthy as (select provider_id from stats where total >= 5 and errors::numeric/total >= 0.5),
  upd as (
    update public.ai_providers p set is_active=false from unhealthy u
    where p.id=u.provider_id and p.is_active=true returning p.id
  )
  select count(*) into v_disabled from upd;
  if v_disabled > 0 then
    insert into public.ai_logs (provider_id, kind, level, message, meta)
    values (null,'error','warn','ai_health_sweep auto-disabled '||v_disabled||' provider(s)','{"auto":true}'::jsonb);
  end if;
  return v_disabled;
end; $$;
revoke all on function public.ai_health_sweep() from public, anon, authenticated;
grant execute on function public.ai_health_sweep() to service_role;

-- Optional: schedule every 10 min (requires pg_cron extension enabled).
-- select cron.schedule('ai-health-sweep','*/10 * * * *',$$select public.ai_health_sweep()$$);
