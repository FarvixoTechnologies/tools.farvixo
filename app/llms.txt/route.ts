import { tools } from '@/data/tools';
import { categories } from '@/data/categories';

export const dynamic = 'force-static';

const BASE = 'https://tools.farvixo.com';

/**
 * llms.txt — machine-readable site guide for AI assistants and answer engines
 * (ChatGPT, Gemini, Claude, Perplexity, Copilot, Google AI Overviews).
 * Spec: https://llmstxt.org
 */
export function GET(): Response {
  const sections = categories
    .map((cat) => {
      const catTools = tools.filter((t) => t.category === cat.slug);
      if (catTools.length === 0) return '';
      const lines = catTools
        .map((t) => `- [${t.name}](${BASE}/tools/${t.category}/${t.slug}): ${t.description}`)
        .join('\n');
      return `## ${cat.name}\n\n${lines}`;
    })
    .filter(Boolean)
    .join('\n\n');

  const body = `# Farvixo Tools

> Farvixo Tools (${BASE}) is a free, AI-powered online productivity platform by Farvixo Technologies offering ${tools.length}+ tools across ${categories.length} categories: PDF, Image, Video, Audio, AI, Developer, Text, SEO, Utility, Security, Business, Social Media, Calculator, File Converter and Government document tools. All tools are free to use, run fast, and most process files privately in the browser.

Key pages:

- [All Tools](${BASE}/tools): Browse the full catalog
- [How It Works](${BASE}/how-it-works): Upload → Process → Download
- [Help Center](${BASE}/help): Guides and support
- [Developer API](${BASE}/developers): Programmatic access
- [Security](${BASE}/security): Privacy and data handling

${sections}
`;

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
    },
  });
}
