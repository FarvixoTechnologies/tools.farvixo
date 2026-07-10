// Public Supabase config (URL + anon key). These are safe to ship in the
// client bundle by design — the anon key is protected by Row Level Security.
// Used as a build-time fallback so the app works even if the deployment
// platform's NEXT_PUBLIC_SUPABASE_* env vars are not set. Real env vars, when
// present, always take precedence.
const FALLBACK_URL = 'https://xtmcsndjbgalovoqipmb.supabase.co';
const FALLBACK_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh0bWNzbmRqYmdhbG92b3FpcG1iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5MTY2NTYsImV4cCI6MjA5ODQ5MjY1Nn0.e9Yw64oZbisJ0VldyspqW2XfXi7t5hnufuXBTGH6UQ4';

export function getSupabaseEnv(): { url: string; anonKey: string } | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || FALLBACK_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || FALLBACK_ANON_KEY;
  if (!url || !anonKey) return null;
  return { url, anonKey };
}
