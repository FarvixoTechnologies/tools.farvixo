-- 17_rbac_grants.sql — Permission-enforcement pass support.
-- Let the service-role admin client execute the gate RPCs, and keep admin
-- invitations effectively super-admin-only by removing roles.invite from ADMIN.

grant execute on function public.role_effective_permissions(text) to service_role;
grant execute on function public.current_user_has_permission(text) to service_role;

delete from public.role_permissions where role_key = 'ADMIN' and permission_key = 'roles.invite';
