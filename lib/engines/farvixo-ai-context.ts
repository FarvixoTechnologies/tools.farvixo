import { categories } from '@/data/categories';
import { searchTools, tools, type Tool } from '@/data/tools';

const PRODUCTION_URL = 'https://tools.farvixo.com';

export function getFarvixoBaseUrl(): string {
  if (typeof window !== 'undefined' && window.location?.origin) {
    return window.location.origin;
  }
  return process.env.NEXT_PUBLIC_APP_URL?.replace(/\/$/, '') || PRODUCTION_URL;
}

export function toolPath(category: string, slug: string): string {
  return `/tools/${category}/${slug}`;
}

export function toolUrl(category: string, slug: string): string {
  return `${getFarvixoBaseUrl()}${toolPath(category, slug)}`;
}

export function formatToolLine(t: Tool): string {
  return `- **${t.name}** — ${t.description} → [Open](${toolUrl(t.category, t.slug)})`;
}

function aiBehaviorRules(base: string): string {
  return `
## Farvixo AI rules (always follow)
- You are embedded INSIDE Farvixo Tools — the user is already on the platform.
- When the user wants a tool (PDF converter, compress, merge, etc.), give a **direct markdown link**. Example: [PDF Converter](${base}/tools/pdf/pdf-converter)
- NEVER say "visit the website", "click the PDF tab", or "go to tools.farvixo.com" — they are already here.
- NEVER invent tools or URLs. Only use the catalog below.
- Prefer the **most specific** tool (PDF to Word → pdf-to-word; general convert → pdf-converter).
- Keep answers short: 1–2 sentences + direct link + optional tip.
- PDF category → ${base}/tools/pdf · All tools → ${base}/tools
`.trim();
}

function pdfToolsSection(base: string): string {
  const pdfTools = tools.filter((t) => t.category === 'pdf');
  return ['## PDF tools (direct links)', ...pdfTools.map(formatToolLine)].join('\n').replaceAll(getFarvixoBaseUrl(), base);
}

function categorySection(base: string): string {
  const lines = categories.map(
    (c) => `- **${c.name}** → [Browse](${base}/tools/${c.slug})`,
  );
  return `## Categories\n${lines.join('\n')}`;
}

export function buildRelevantToolsContext(query: string, limit = 8): string {
  const q = query.trim();
  if (!q) return '';
  const matches = searchTools(q).slice(0, limit);
  if (!matches.length) return '';
  return ['## Best matching tools for this request', ...matches.map(formatToolLine)].join('\n');
}

/** Full system context for Farvixo AI. */
export function buildFarvixoAiContext(userQuery?: string): string {
  const base = getFarvixoBaseUrl();
  const parts = [
    `You are Farvixo AI — in-app assistant for Farvixo Tools (${PRODUCTION_URL}).`,
    `Site origin: ${base}. Tagline: Build Beyond. 139+ free AI & productivity tools.`,
    aiBehaviorRules(base),
    pdfToolsSection(base),
    categorySection(base),
  ];

  if (userQuery?.trim()) {
    const relevant = buildRelevantToolsContext(userQuery);
    if (relevant) parts.push(relevant.replaceAll(getFarvixoBaseUrl(), base));
  }

  return parts.join('\n\n');
}

export function buildFarvixoDefaultSystem(userQuery?: string): string {
  return buildFarvixoAiContext(userQuery);
}
