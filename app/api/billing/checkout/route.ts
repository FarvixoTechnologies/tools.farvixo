import { apiErr, apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';
import { getSupabaseEnv } from '@/lib/supabase/env';

/**
 * POST /api/billing/checkout — create a Stripe Checkout session for the Pro plan.
 * Uses the Stripe REST API directly (no SDK dependency).
 * Accepts cookie session or Authorization Bearer (Flutter).
 */
export async function POST(req: Request) {
  const stripeKey = process.env.STRIPE_SECRET_KEY;
  const priceId = process.env.STRIPE_PRICE_ID_PRO_MONTHLY;
  if (!stripeKey || !priceId) {
    return apiErr(
      'Billing is not configured yet — set STRIPE_SECRET_KEY and STRIPE_PRICE_ID_PRO_MONTHLY',
      503,
    );
  }
  if (!getSupabaseEnv()) return apiErr('Auth is not configured', 503);

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { user } = gate.ctx;
  if (!user.email) return apiErr('Sign in to upgrade', 401);

  let successUrl: string | undefined;
  let cancelUrl: string | undefined;
  try {
    const body = (await req.json()) as {
      successUrl?: string;
      cancelUrl?: string;
      success_url?: string;
      cancel_url?: string;
    };
    successUrl = body.successUrl ?? body.success_url;
    cancelUrl = body.cancelUrl ?? body.cancel_url;
  } catch {
    // optional body
  }

  const origin = process.env.NEXT_PUBLIC_APP_URL || new URL(req.url).origin;

  const params = new URLSearchParams({
    mode: 'subscription',
    'line_items[0][price]': priceId,
    'line_items[0][quantity]': '1',
    client_reference_id: user.id,
    customer_email: user.email,
    success_url: successUrl || `${origin}/dashboard/billing?checkout=success`,
    cancel_url: cancelUrl || `${origin}/dashboard/billing?checkout=cancelled`,
  });

  const res = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${stripeKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params.toString(),
  });

  const session = (await res.json()) as { url?: string; error?: { message?: string } };
  if (!res.ok || !session.url) {
    console.error('[billing] checkout failed:', session.error?.message);
    return apiErr('Could not start checkout — please try again later', 502);
  }

  return apiOk({ url: session.url });
}
