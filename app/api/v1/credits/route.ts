import { apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';

export const dynamic = 'force-dynamic';

/** GET /api/v1/credits — balance + recent ledger (session). */
export async function GET(req: Request) {
  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const [{ data: profile }, { data: ledger, error }] = await Promise.all([
    supabase.from('profiles').select('credits').eq('id', user.id).maybeSingle(),
    supabase
      .from('credit_ledger')
      .select('id, amount, balance_after, reason, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50),
  ]);

  if (error) {
    return apiOk({ balance: profile?.credits ?? 0, ledger: [] });
  }

  return apiOk({ balance: profile?.credits ?? 0, ledger: ledger ?? [] });
}
