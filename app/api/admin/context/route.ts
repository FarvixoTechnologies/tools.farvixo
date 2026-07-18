import { apiErr, apiOk } from '@/lib/api-response';
import { resolvePermissions } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

/** Current admin's role + effective permissions — powers client-side UI gating. */
export async function GET() {
  const ctx = await resolvePermissions();
  if (!ctx) return apiErr('Unauthorized', 401);
  return apiOk(ctx);
}
