import { apiOk } from '@/lib/api-response';
import { requireAdmin } from '@/lib/admin-auth';
import { createAdminClient } from '@/lib/supabase/admin';
import { getSupabaseEnv } from '@/lib/supabase/env';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const env = getSupabaseEnv();
  const checks = {
    supabase: Boolean(env?.url && env?.anonKey),
    serviceRole: createAdminClient() !== null,
    gemini: Boolean(process.env.GEMINI_API_KEY || process.env.GROQ_API_KEY),
    stripe: Boolean(process.env.STRIPE_SECRET_KEY),
    appUrl: Boolean(process.env.NEXT_PUBLIC_APP_URL),
  };

  // Health is computed inline. Do NOT fetch our own /api/health here: on
  // Cloudflare, fetching the Worker's own hostname re-enters the same Worker
  // (WORKER_SELF_REFERENCE), exhausting its resource limits → Error 1102.
  const health: { status: string; uptime: number } = {
    status: 'ok',
    uptime: process.uptime(),
  };

  return apiOk({
    nodeEnv: process.env.NODE_ENV ?? 'unknown',
    nextVersion: '15.1.11',
    checks,
    // Core path: Supabase + service role. Optional integrations don't fail "all green".
    allGreen: checks.supabase && checks.serviceRole && checks.appUrl,
    health,
    timestamp: new Date().toISOString(),
  });
}
