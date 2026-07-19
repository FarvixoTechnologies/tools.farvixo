import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Service-role Supabase client — server only, bypasses RLS.
 * Returns null when Supabase env vars are not configured so callers
 * can degrade gracefully (e.g. in local dev without Supabase).
 */
// The project URL is public (not a secret); a fallback keeps local dev working.
// The service-role key must come from the SUPABASE_SERVICE_ROLE_KEY env var and
// is intentionally NOT hardcoded — it grants full, RLS-bypassing DB access.
// When it is absent this returns null and callers degrade gracefully.
const FALLBACK_URL = 'https://bujpwwxanaejfcyuigth.supabase.co';

export function createAdminClient(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || FALLBACK_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
