/**
 * Apply Farvixo bootstrap SQL to a remote Postgres (Supabase).
 *
 * Usage (PowerShell):
 *   $env:DATABASE_URL = "postgresql://postgres.[REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres"
 *   node scripts/apply-supabase-bootstrap.mjs
 *
 * Or:
 *   $env:SUPABASE_DB_PASSWORD = "your-db-password"
 *   $env:SUPABASE_PROJECT_REF = "bujpwwxanaejfcyuigth"
 *   node scripts/apply-supabase-bootstrap.mjs
 *
 * Get password: Supabase Dashboard → Project Settings → Database → Database password
 * Connection: Settings → Database → Connection string → URI (Session or Transaction pooler)
 *
 * Skips 02_promote_super_admin.sql unless APPLY_PROMOTE=1 (needs user signed up first).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const ORDER = [
  'schema.sql',
  '01_missing_admin.sql',
  '06_user_admin.sql',
  '04_shares.sql',
  '07_notifications.sql',
  '08_production_next_steps.sql',
  '09_architecture_v3_foundation.sql',
  '10_seed_tools_catalog.sql',
];

const PROMOTE = '02_promote_super_admin.sql';

function buildUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  const password = process.env.SUPABASE_DB_PASSWORD;
  const ref = process.env.SUPABASE_PROJECT_REF || 'bujpwwxanaejfcyuigth';
  const host =
    process.env.SUPABASE_DB_HOST ||
    `db.${ref}.supabase.co`;
  if (!password) {
    console.error(`
Missing credentials.

Set one of:
  DATABASE_URL=postgresql://postgres:[PASSWORD]@db.${ref}.supabase.co:5432/postgres
  or SUPABASE_DB_PASSWORD=... (uses db.${ref}.supabase.co)

Dashboard → Project Settings → Database → Reset / copy password + Connection string.
`);
    process.exit(1);
  }
  const enc = encodeURIComponent(password);
  return `postgresql://postgres:${enc}@${host}:5432/postgres`;
}

async function runFile(client, file) {
  const p = path.join(root, 'supabase', file);
  if (!fs.existsSync(p)) {
    console.warn('skip missing', file);
    return;
  }
  const sql = fs.readFileSync(p, 'utf8');
  console.log(`\n>>> Applying ${file} (${sql.length} bytes)...`);
  await client.query(sql);
  console.log(`<<< OK ${file}`);
}

async function main() {
  const url = buildUrl();
  const client = new pg.Client({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();
  const { rows } = await client.query('select current_database() as db, current_user as usr');
  console.log('Connected:', rows[0]);

  for (const file of ORDER) {
    try {
      await runFile(client, file);
    } catch (err) {
      console.error(`FAILED on ${file}:`, err.message);
      await client.end();
      process.exit(1);
    }
  }

  if (process.env.APPLY_PROMOTE === '1') {
    try {
      await runFile(client, PROMOTE);
    } catch (err) {
      console.warn(`Promote skipped/failed (sign up first?): ${err.message}`);
    }
  } else {
    console.log(`\nSkipped ${PROMOTE} (set APPLY_PROMOTE=1 after first signup)`);
  }

  const check = await client.query(`
    select
      (select count(*) from information_schema.tables where table_schema='public') as public_tables,
      (select count(*) from public.tool_categories) as categories,
      (select count(*) from public.tools) as tools
  `).catch(() => null);

  if (check?.rows?.[0]) console.log('\nVerify:', check.rows[0]);
  else console.log('\nVerify: tool tables may use different names — check Dashboard.');

  await client.end();
  console.log('\nBootstrap complete.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
