import { apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';

export const dynamic = 'force-dynamic';

/** GET /api/v1/wallet — balance from wallet table or profiles.credits. */
export async function GET(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user, admin } = gate.ctx;

  const client = admin ?? supabase;

  const { data: wallet } = await client
    .from('wallet')
    .select('balance, currency, updated_at')
    .eq('user_id', user.id)
    .maybeSingle();

  if (wallet) {
    return apiOk({ wallet, source: 'wallet' });
  }

  const { data: profile } = await supabase.from('profiles').select('credits, plan').eq('id', user.id).maybeSingle();

  return apiOk({
    wallet: {
      balance: profile?.credits ?? 0,
      currency: 'CREDITS',
      updated_at: null,
      plan: profile?.plan ?? 'FREE',
    },
    source: 'profiles.credits',
  });
}
