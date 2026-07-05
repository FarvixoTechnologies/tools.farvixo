import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

/** GET /api/stats/tools — real per-tool usage counts (public, CDN-cached).
 *  Powers "Used N times" chips and Popular sorting on the All Tools page. */
export async function GET() {
  const counts: Record<string, number> = {};

  const admin = createAdminClient();
  if (admin) {
    // jobs is small (thousands, not millions) — count client-side per slug.
    const { data } = await admin.from('jobs').select('tool_slug').limit(50_000);
    for (const row of data ?? []) {
      const slug = (row as { tool_slug?: string }).tool_slug;
      if (slug) counts[slug] = (counts[slug] ?? 0) + 1;
    }
  }

  return new Response(
    JSON.stringify({ success: true, data: { counts }, error: null }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
      },
    },
  );
}
