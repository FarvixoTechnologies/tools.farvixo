// Public Supabase config (URL + anon key). These are safe to ship in the
// client bundle by design — the anon key is protected by Row Level Security.
// Used as a build-time fallback so the app works even if the deployment
// platform's NEXT_PUBLIC_SUPABASE_* env vars are not set. Real env vars, when
// present, always take precedence.
const FALLBACK_URL = 'https://bujpwwxanaejfcyuigth.supabase.co';
const FALLBACK_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1anB3d3hhbmFlamZjeXVpZ3RoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM5NTc3MTEsImV4cCI6MjA5OTUzMzcxMX0._U_Vrgl55wWs0jXbFXyXdD56SRFdoV9bjYj7raQa4Es';

export function getSupabaseEnv(): { url: string; anonKey: string } | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || FALLBACK_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || FALLBACK_ANON_KEY;
  if (!url || !anonKey) return null;
  return { url, anonKey };
}
