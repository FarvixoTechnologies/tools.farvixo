import { apiErr, apiOk } from '@/lib/api-response';
import { requireAdmin } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

/** All permissions, grouped by module — feeds the permission matrix. */
export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const { data, error } = await admin
    .from('permissions')
    .select('key, resource, action, description, group_name')
    .order('group_name', { ascending: true })
    .order('key', { ascending: true });
  if (error) return apiErr(error.message, 500);

  const groups: Record<string, typeof data> = {};
  for (const p of data ?? []) (groups[p.group_name] ??= []).push(p);

  return apiOk({ permissions: data ?? [], groups });
}
