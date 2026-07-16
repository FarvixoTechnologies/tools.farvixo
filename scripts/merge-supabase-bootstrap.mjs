/**
 * Merge Farvixo SQL bootstrap into one file (optional).
 * Prefer running files step-by-step in Dashboard if a statement fails.
 *
 *   node scripts/merge-supabase-bootstrap.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const order = [
  'schema.sql',
  '01_missing_admin.sql',
  '06_user_admin.sql',
  '04_shares.sql',
  '07_notifications.sql',
  '08_production_next_steps.sql',
  '09_architecture_v3_foundation.sql',
  '10_seed_tools_catalog.sql',
  '02_promote_super_admin.sql',
];

const parts = [
  `-- Farvixo FULL BOOTSTRAP (generated ${new Date().toISOString()})`,
  `-- Project: bujpwwxanaejfcyuigth`,
  `-- Prefer stepwise apply via supabase/BOOTSTRAP.md if errors occur.`,
  '',
];

for (const file of order) {
  const p = path.join(root, 'supabase', file);
  if (!fs.existsSync(p)) {
    console.warn('skip missing', file);
    continue;
  }
  parts.push(`\n-- ========== BEGIN ${file} ==========\n`);
  parts.push(fs.readFileSync(p, 'utf8'));
  parts.push(`\n-- ========== END ${file} ==========\n`);
}

const out = path.join(root, 'supabase', 'FULL_BOOTSTRAP.generated.sql');
fs.writeFileSync(out, parts.join('\n'), 'utf8');
console.log('Wrote', out, `(${(fs.statSync(out).size / 1024).toFixed(1)} KB)`);
