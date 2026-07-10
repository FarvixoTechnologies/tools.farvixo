import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Service-role Supabase client — server only, bypasses RLS.
 * Returns null when Supabase env vars are not configured so callers
 * can degrade gracefully (e.g. in local dev without Supabase).
 */
// Server-only fallbacks so admin / server features work even when the
// deployment platform's env vars are not set. This file is never imported by
// client components, so the service-role key stays out of the browser bundle.
// Real env vars, when present, always take precedence.
const FALLBACK_URL = 'https://xtmcsndjbgalovoqipmb.supabase.co';
const FALLBACK_SERVICE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh0bWNzbmRqYmdhbG92b3FpcG1iIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjkxNjY1NiwiZXhwIjoyMDk4NDkyNjU2fQ.Lk7-HreWg29NQQ-4ltyWuoGxwkE18fm9A0jRKc825mc';

export function createAdminClient(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || FALLBACK_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || FALLBACK_SERVICE_KEY;
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
