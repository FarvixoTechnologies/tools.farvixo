import { apiOk } from '@/lib/api-response';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const FALLBACK_PLANS = [
  {
    id: 'free',
    name: 'Free',
    price_monthly_cents: 0,
    features: ['5 jobs/day per tool', '500MB storage', '10 AI messages/day'],
    limits: { storage_mb: 500, ai_messages_day: 10 },
  },
  {
    id: 'pro',
    name: 'Pro',
    price_monthly_cents: 999,
    features: ['Unlimited tools', '100GB storage', 'Unlimited AI', 'No ads'],
    limits: { storage_mb: 102400, ai_messages_day: -1 },
  },
  {
    id: 'enterprise',
    name: 'Enterprise',
    price_monthly_cents: 0,
    features: ['Custom limits', 'API access', 'Priority support'],
    limits: {},
  },
];

/** GET /api/v1/plans — public plan catalog (DB `plans` or fallback). */
export async function GET(req: Request) {
  const rl = rateLimit(`v1plans:${clientIp(req)}`, 60, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  const admin = createAdminClient();
  if (admin) {
    const { data, error } = await admin
      .from('plans')
      .select('id, name, price_monthly_cents, features, limits, is_active')
      .eq('is_active', true)
      .order('price_monthly_cents');
    if (!error && data?.length) {
      return apiOk({ count: data.length, plans: data, source: 'db' });
    }
  }

  return apiOk({ count: FALLBACK_PLANS.length, plans: FALLBACK_PLANS, source: 'fallback' });
}
