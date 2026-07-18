import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

export async function GET() {
  const auth = await requirePermission('billing.read');
  if (!auth.ok) return auth.response;
  const { admin } = auth.ctx;

  const { data, error } = await admin
    .from('promo_codes')
    .select('code, discount_pct, credit_bonus, max_redemptions, redemptions, expires_at, is_active')
    .order('code');

  if (error) {
    return apiOk({ ready: false, codes: [], error: error.message });
  }
  return apiOk({ ready: true, codes: data ?? [] });
}

export async function POST(req: Request) {
  const auth = await requirePermission('billing.write');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: {
    code?: string;
    discount_pct?: number;
    credit_bonus?: number;
    max_redemptions?: number;
    expires_at?: string | null;
    is_active?: boolean;
  };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }

  const code = body.code?.trim().toUpperCase();
  if (!code || code.length < 3) return apiErr('Code must be 3+ characters', 400);

  const row = {
    code,
    discount_pct: body.discount_pct ?? null,
    credit_bonus: body.credit_bonus ?? null,
    max_redemptions: body.max_redemptions ?? null,
    expires_at: body.expires_at || null,
    is_active: body.is_active ?? true,
  };

  const { error } = await admin.from('promo_codes').upsert(row, { onConflict: 'code' });
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'promo.upsert', code, row);
  return apiOk({ saved: true, code });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('billing.write');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let body: { code?: string; is_active?: boolean };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return apiErr('Invalid body', 400);
  }
  if (!body.code) return apiErr('Code required', 400);

  const { error } = await admin
    .from('promo_codes')
    .update({ is_active: !!body.is_active })
    .eq('code', body.code);
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'promo.toggle', body.code, { is_active: body.is_active });
  return apiOk({ updated: true });
}
