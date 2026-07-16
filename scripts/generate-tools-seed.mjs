/**
 * Generate supabase/10_seed_tools_catalog.sql from data/*.ts
 * Run: node scripts/generate-tools-seed.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function sqlStr(s) {
  if (s == null) return 'null';
  return `'${String(s).replace(/'/g, "''")}'`;
}

function sqlBool(b) {
  return b ? 'true' : 'false';
}

function parseCategories(src) {
  const out = [];
  const re =
    /\{\s*slug:\s*'([^']+)',\s*name:\s*'((?:\\'|[^'])*)',\s*shortName:\s*'((?:\\'|[^'])*)',\s*icon:\s*'([^']+)',\s*accent:\s*'([^']+)'/g;
  let m;
  while ((m = re.exec(src))) {
    out.push({
      slug: m[1],
      name: m[2].replace(/\\'/g, "'"),
      icon: m[4],
      accent: m[5],
    });
  }
  return out;
}

function parseTools(src) {
  const out = [];
  // Match each tool object starting with id
  const blocks = src.match(/\{\s*id:\s*\d+[\s\S]*?\},?/g) || [];
  for (const b of blocks) {
    const id = +(b.match(/id:\s*(\d+)/) || [])[1];
    const slug = (b.match(/slug:\s*'([^']+)'/) || [])[1];
    const name = (b.match(/name:\s*'((?:\\'|[^'])*)'/) || [])[1]?.replace(/\\'/g, "'");
    const description = (b.match(/description:\s*'((?:\\'|[^'])*)'/) || [])[1]?.replace(/\\'/g, "'");
    const category = (b.match(/category:\s*'([^']+)'/) || [])[1];
    const icon = (b.match(/icon:\s*'([^']+)'/) || [])[1];
    const badge = (b.match(/badge:\s*'([^']+)'/) || [])[1] || null;
    const runner = (b.match(/runner:\s*'([^']+)'/) || [])[1];
    const mode = (b.match(/mode:\s*'([^']+)'/) || [])[1];
    if (!id || !slug || !name || !category) continue;
    const isAi =
      badge === 'ai' ||
      category === 'ai' ||
      (runner || '').startsWith('ai-') ||
      ['bg-remove', 'bg-remover-advanced', 'ocr', 'speech'].includes(runner);
    const kwMatch = b.match(/keywords:\s*\[([^\]]*)\]/);
    const keywords = kwMatch
      ? [...kwMatch[1].matchAll(/'([^']+)'/g)].map((x) => x[1])
      : [];
    out.push({
      id,
      slug,
      name,
      description: description || '',
      category,
      icon: icon || 'grid',
      badge,
      runner,
      mode,
      keywords,
      isAi,
    });
  }
  return out;
}

const catSrc = fs.readFileSync(path.join(root, 'data/categories.ts'), 'utf8');
const toolSrc = fs.readFileSync(path.join(root, 'data/tools.ts'), 'utf8');
const categories = parseCategories(catSrc);
const tools = parseTools(toolSrc);

if (!categories.length || !tools.length) {
  console.error(`Parse failed: ${categories.length} cats, ${tools.length} tools`);
  process.exit(1);
}

const lines = [];
lines.push('-- ============================================================');
lines.push('-- Farvixo — Seed tool catalog (generated from data/categories.ts + data/tools.ts)');
lines.push(`-- Generated: ${new Date().toISOString()}`);
lines.push('-- Run AFTER 09_architecture_v3_foundation.sql');
lines.push('-- Regenerate: node scripts/generate-tools-seed.mjs');
lines.push('-- ============================================================');
lines.push('');
lines.push('-- Categories');
lines.push(
  'insert into public.tool_categories (slug, name, icon, accent, sort_order, tool_count, is_active) values',
);

const catRows = categories.map((c, i) => {
  const count = tools.filter((t) => t.category === c.slug).length;
  return `  (${sqlStr(c.slug)}, ${sqlStr(c.name)}, ${sqlStr(c.icon)}, ${sqlStr(c.accent)}, ${i + 1}, ${count}, true)`;
});
lines.push(catRows.join(',\n'));
lines.push('on conflict (slug) do update set');
lines.push('  name = excluded.name,');
lines.push('  icon = excluded.icon,');
lines.push('  accent = excluded.accent,');
lines.push('  sort_order = excluded.sort_order,');
lines.push('  tool_count = excluded.tool_count,');
lines.push('  is_active = true;');
lines.push('');

lines.push('-- Tools');
lines.push(
  'insert into public.tools (id, slug, name, description, category_slug, icon, badge, is_ai_powered, is_active, usage_count, meta) values',
);

const toolRows = tools.map((t) => {
  const meta = {
    runner: t.runner,
    mode: t.mode,
    keywords: t.keywords,
  };
  return `  (${t.id}, ${sqlStr(t.slug)}, ${sqlStr(t.name)}, ${sqlStr(t.description)}, ${sqlStr(t.category)}, ${sqlStr(t.icon)}, ${t.badge ? sqlStr(t.badge) : 'null'}, ${sqlBool(t.isAi)}, true, 0, ${sqlStr(JSON.stringify(meta))}::jsonb)`;
});
lines.push(toolRows.join(',\n'));
lines.push('on conflict (slug) do update set');
lines.push('  name = excluded.name,');
lines.push('  description = excluded.description,');
lines.push('  category_slug = excluded.category_slug,');
lines.push('  icon = excluded.icon,');
lines.push('  badge = excluded.badge,');
lines.push('  is_ai_powered = excluded.is_ai_powered,');
lines.push('  is_active = true,');
lines.push('  meta = excluded.meta,');
lines.push('  updated_at = now();');
lines.push('');
lines.push(`-- Align serial sequence with max(id)`);
lines.push(
  `select setval(pg_get_serial_sequence('public.tools', 'id'), coalesce((select max(id) from public.tools), 1));`,
);
lines.push('');
lines.push(`update public.tool_categories c
set tool_count = (
  select count(*)::int from public.tools t where t.category_slug = c.slug and t.is_active
);`);
lines.push('');
lines.push(`-- Done: ${categories.length} categories, ${tools.length} tools`);

const out = path.join(root, 'supabase/10_seed_tools_catalog.sql');
fs.writeFileSync(out, lines.join('\n') + '\n', 'utf8');
console.log(`Wrote ${out} (${categories.length} categories, ${tools.length} tools)`);
