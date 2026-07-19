import { apiErr, apiOk } from '@/lib/api-response';
import { requireSession } from '@/lib/api-v1';
import { getSupabaseEnv } from '@/lib/supabase/env';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

/* ------------------------------------------------------------------ */
/* Types                                                               */
/* ------------------------------------------------------------------ */

interface SettingsPayload {
  profile: { full_name: string; avatar_url: string | null };
  settings: {
    locale: string;
    theme: string;
    email_notifications: boolean;
    push_notifications: boolean;
    marketing_opt_in: boolean;
    bio: string;
  };
  socials: {
    github_username: string | null;
    twitter_handle: string | null;
    website: string | null;
  };
  loginHistory: Array<{
    provider: string | null;
    success: boolean;
    ip: string | null;
    user_agent: string | null;
    created_at: string;
  }>;
}

const THEMES = new Set(['light', 'dark', 'system']);
const LOCALES = new Set(['en', 'hi', 'bn', 'es', 'pt', 'fr', 'de', 'ar']);

/* ------------------------------------------------------------------ */
/* Validation helpers (no external deps)                               */
/* ------------------------------------------------------------------ */

function asString(v: unknown, max: number): string | undefined {
  if (typeof v !== 'string') return undefined;
  return v.slice(0, max).trim();
}

function asBool(v: unknown): boolean | undefined {
  return typeof v === 'boolean' ? v : undefined;
}

function cleanHandle(v: unknown): string | null | undefined {
  const s = asString(v, 60);
  if (s === undefined) return undefined;
  if (s === '') return null;
  return s.replace(/^@+/, '').replace(/[^a-zA-Z0-9_.-]/g, '').slice(0, 40) || null;
}

function cleanUrl(v: unknown): string | null | undefined {
  const s = asString(v, 200);
  if (s === undefined) return undefined;
  if (s === '') return null;
  try {
    const u = new URL(s.startsWith('http') ? s : `https://${s}`);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
    return u.toString();
  } catch {
    return null;
  }
}

/* ------------------------------------------------------------------ */
/* GET — load everything the settings page needs                       */
/* ------------------------------------------------------------------ */

export async function GET(req: Request) {
  if (!getSupabaseEnv()) return apiErr('Auth not configured', 503);

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  const [profileRes, settingsRes, socialsRes, historyRes] = await Promise.all([
    supabase.from('profiles').select('full_name, avatar_url, plan, role, created_at').eq('id', user.id).maybeSingle(),
    supabase.from('settings').select('locale, theme, email_notifications, push_notifications, marketing_opt_in, prefs').eq('user_id', user.id).maybeSingle(),
    supabase.from('user_socials').select('github_username, twitter_handle, website').eq('user_id', user.id).maybeSingle(),
    supabase.from('login_history').select('provider, success, ip, user_agent, created_at').eq('user_id', user.id).order('created_at', { ascending: false }).limit(8),
  ]);

  const s = settingsRes.data;
  const prefs = (s?.prefs ?? {}) as { bio?: string };

  const payload: SettingsPayload = {
    profile: {
      full_name: profileRes.data?.full_name ?? user.user_metadata?.full_name ?? '',
      avatar_url: profileRes.data?.avatar_url ?? null,
    },
    settings: {
      locale: s?.locale ?? 'en',
      theme: s?.theme ?? 'dark',
      email_notifications: s?.email_notifications ?? true,
      push_notifications: s?.push_notifications ?? true,
      marketing_opt_in: s?.marketing_opt_in ?? false,
      bio: prefs.bio ?? '',
    },
    socials: {
      github_username: socialsRes.data?.github_username ?? null,
      twitter_handle: socialsRes.data?.twitter_handle ?? null,
      website: socialsRes.data?.website ?? null,
    },
    loginHistory: (historyRes.data ?? []).map((h) => ({
      provider: h.provider,
      success: h.success,
      ip: h.ip ? String(h.ip) : null,
      user_agent: h.user_agent,
      created_at: h.created_at,
    })),
  };

  return apiOk(payload);
}

/* ------------------------------------------------------------------ */
/* PATCH — partial update of profile / settings / socials             */
/* ------------------------------------------------------------------ */

export async function PATCH(req: Request) {
  const rl = rateLimit(`account-settings:${clientIp(req)}`, 20, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  if (!getSupabaseEnv()) return apiErr('Auth not configured', 503);

  const gate = await requireSession(req);
  if (!gate.ok) return gate.response;
  const { supabase, user } = gate.ctx;

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return apiErr('Invalid JSON body', 400);
  }

  const now = new Date().toISOString();
  const profileIn = (body.profile ?? {}) as Record<string, unknown>;
  const settingsIn = (body.settings ?? {}) as Record<string, unknown>;
  const socialsIn = (body.socials ?? {}) as Record<string, unknown>;

  /* ---- profiles ---- */
  const profileUpdate: Record<string, unknown> = {};
  const fullName = asString(profileIn.full_name, 80);
  if (fullName !== undefined) {
    if (fullName.length < 1) return apiErr('Name cannot be empty', 400);
    profileUpdate.full_name = fullName;
  }
  if ('avatar_url' in profileIn) {
    const av = profileIn.avatar_url;
    profileUpdate.avatar_url = av === null ? null : asString(av, 400) ?? null;
  }
  if (Object.keys(profileUpdate).length > 0) {
    profileUpdate.updated_at = now;
    const { error } = await supabase.from('profiles').update(profileUpdate).eq('id', user.id);
    if (error) return apiErr(error.message, 400);
  }

  /* ---- settings (upsert on user_id) ---- */
  const settingsUpdate: Record<string, unknown> = {};
  const locale = asString(settingsIn.locale, 8);
  if (locale !== undefined) settingsUpdate.locale = LOCALES.has(locale) ? locale : 'en';
  const theme = asString(settingsIn.theme, 12);
  if (theme !== undefined) settingsUpdate.theme = THEMES.has(theme) ? theme : 'system';
  const emailN = asBool(settingsIn.email_notifications);
  if (emailN !== undefined) settingsUpdate.email_notifications = emailN;
  const pushN = asBool(settingsIn.push_notifications);
  if (pushN !== undefined) settingsUpdate.push_notifications = pushN;
  const mkt = asBool(settingsIn.marketing_opt_in);
  if (mkt !== undefined) settingsUpdate.marketing_opt_in = mkt;

  const bio = asString(settingsIn.bio, 280);
  if (bio !== undefined) {
    // Merge into prefs jsonb without clobbering other keys.
    const { data: cur } = await supabase.from('settings').select('prefs').eq('user_id', user.id).maybeSingle();
    const prefs = { ...((cur?.prefs as Record<string, unknown>) ?? {}), bio };
    settingsUpdate.prefs = prefs;
  }

  if (Object.keys(settingsUpdate).length > 0) {
    settingsUpdate.user_id = user.id;
    settingsUpdate.updated_at = now;
    const { error } = await supabase.from('settings').upsert(settingsUpdate, { onConflict: 'user_id' });
    if (error) return apiErr(error.message, 400);
  }

  /* ---- socials (upsert on user_id) ---- */
  const socialsUpdate: Record<string, unknown> = {};
  const gh = cleanHandle(socialsIn.github_username);
  if (gh !== undefined) socialsUpdate.github_username = gh;
  const tw = cleanHandle(socialsIn.twitter_handle);
  if (tw !== undefined) socialsUpdate.twitter_handle = tw;
  const web = cleanUrl(socialsIn.website);
  if (web !== undefined) socialsUpdate.website = web;

  if (Object.keys(socialsUpdate).length > 0) {
    socialsUpdate.user_id = user.id;
    socialsUpdate.updated_at = now;
    const { error } = await supabase.from('user_socials').upsert(socialsUpdate, { onConflict: 'user_id' });
    if (error) return apiErr(error.message, 400);
  }

  return apiOk({ saved: true }, 200, { message: 'Settings saved' });
}
