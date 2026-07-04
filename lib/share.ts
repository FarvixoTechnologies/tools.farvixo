import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'crypto';
import { createRouteHandlerClient } from '@/lib/supabase/route-handler';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { planFromDb, type UserPlan } from '@/lib/auth';

const SALT_LEN = 16;
const KEY_LEN = 32;

export function hashSharePassword(password: string): string {
  const salt = randomBytes(SALT_LEN);
  const key = scryptSync(password, salt, KEY_LEN);
  return `${salt.toString('hex')}:${key.toString('hex')}`;
}

export function verifySharePassword(password: string, stored: string): boolean {
  const [saltHex, keyHex] = stored.split(':');
  if (!saltHex || !keyHex) return false;
  const salt = Buffer.from(saltHex, 'hex');
  const expected = Buffer.from(keyHex, 'hex');
  const actual = scryptSync(password, salt, KEY_LEN);
  if (expected.length !== actual.length) return false;
  return timingSafeEqual(expected, actual);
}

export function sharePublicUrl(origin: string, token: string): string {
  return `${origin}/share/${token}`;
}

export function shareApiUrl(origin: string, token: string): string {
  return `${origin}/api/share/${token}`;
}

export async function getCallerPlan(): Promise<{ userId: string | null; plan: UserPlan }> {
  if (!getSupabaseEnv()) return { userId: null, plan: 'free' };
  try {
    const { supabase } = await createRouteHandlerClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return { userId: null, plan: 'free' };
    const { data: profile } = await supabase
      .from('profiles')
      .select('plan')
      .eq('id', user.id)
      .maybeSingle();
    return { userId: user.id, plan: planFromDb(profile?.plan ?? 'FREE') };
  } catch {
    return { userId: null, plan: 'free' };
  }
}

export function isProPlan(plan: UserPlan): boolean {
  return plan === 'pro' || plan === 'enterprise';
}

export function deviceHint(req: Request): string {
  const ua = req.headers.get('user-agent') ?? '';
  if (/mobile|android|iphone/i.test(ua)) return 'mobile';
  if (/tablet|ipad/i.test(ua)) return 'tablet';
  return 'desktop';
}

export function eventFingerprint(req: Request): string {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  const ua = req.headers.get('user-agent') ?? '';
  return createHash('sha256').update(`${ip}:${ua}`).digest('hex').slice(0, 16);
}
