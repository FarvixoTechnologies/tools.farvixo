import { apiErr, apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';
import { getSupabaseEnv } from '@/lib/supabase/env';

export const dynamic = 'force-dynamic';

/**
 * GET /api/billing/status — plan, credits, renew date, whether Stripe is configured.
 * Accepts cookie session or Authorization Bearer (Flutter).
 */
export async function GET(req: Request) {
  if (!getSupabaseEnv()) return apiErr('Auth is not configured', 503);

  const billingConfigured = Boolean(
    process.env.STRIPE_SECRET_KEY && process.env.STRIPE_PRICE_ID_PRO_MONTHLY,
  );

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const [profileRes, subRes] = await Promise.all([
    supabase
      .from('profiles')
      .select(
        'plan, credits, ai_credits, cloud_storage_mb, storage_used_mb, stripe_customer_id, stripe_subscription_id',
      )
      .eq('id', user.id)
      .maybeSingle(),
    supabase
      .from('subscriptions')
      .select('plan, status, current_period_end, cancel_at_period_end')
      .eq('user_id', user.id)
      .maybeSingle(),
  ]);

  const profile = profileRes.data;
  const sub = subRes.data;
  const planRaw = (sub?.plan || profile?.plan || 'FREE').toString();
  const plan = planRaw.toLowerCase() === 'pro' || planRaw === 'PRO' ? 'pro' : planRaw.toLowerCase();

  const credits =
    typeof profile?.ai_credits === 'number'
      ? profile.ai_credits
      : typeof profile?.credits === 'number'
        ? profile.credits
        : 0;

  const storageMaxMb =
    typeof profile?.cloud_storage_mb === 'number' ? profile.cloud_storage_mb : plan === 'pro' ? 102400 : 512;
  const storageUsedMb =
    typeof profile?.storage_used_mb === 'number' ? profile.storage_used_mb : 0;

  return apiOk({
    billingConfigured,
    plan,
    planLabel: plan === 'pro' ? 'Pro' : plan === 'enterprise' ? 'Enterprise' : 'Free',
    credits,
    creditsMax: plan === 'pro' || plan === 'enterprise' ? 10000 : 500,
    storageUsedGb: Number((storageUsedMb / 1024).toFixed(2)),
    storageMaxGb: Number((storageMaxMb / 1024).toFixed(2)),
    renewDate: sub?.current_period_end ?? null,
    subscriptionStatus: sub?.status ?? (plan === 'pro' ? 'active' : 'inactive'),
    cancelAtPeriodEnd: sub?.cancel_at_period_end ?? false,
    stripeCustomerId: profile?.stripe_customer_id ?? null,
  });
}
