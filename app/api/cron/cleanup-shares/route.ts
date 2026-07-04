import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

/** Cron: delete expired shares and storage objects. Protect with CRON_SECRET header. */
export async function GET(req: Request) {
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers.get('authorization') !== `Bearer ${secret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const admin = createAdminClient();
  if (!admin) return NextResponse.json({ error: 'No admin client' }, { status: 503 });

  const { data: expired } = await admin
    .from('shares')
    .select('id, storage_path')
    .lt('expires_at', new Date().toISOString())
    .limit(200);

  const rows = expired ?? [];
  if (rows.length > 0) {
    const paths = rows.map((r) => r.storage_path);
    await admin.storage.from('shares').remove(paths);
    await admin.from('shares').delete().in('id', rows.map((r) => r.id));
  }

  return NextResponse.json({ cleaned: rows.length });
}
