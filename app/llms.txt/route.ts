import { tools } from '@/data/tools';
import { categories } from '@/data/categories';

export const dynamic = 'force-static';

const BASE = 'https://tools.farvixo.com';
const VERSION = '3.0';
const LAST_UPDATED = '2026-07-17';

/**
 * llms.txt — enterprise AI discovery document for LLM crawlers and agents
 * (ChatGPT, Gemini, Claude, Copilot, Perplexity, Meta AI, Mistral, Grok).
 * Spec: https://llmstxt.org
 */
export function GET(): Response {
  const catalog = categories
    .map((cat) => {
      const catTools = tools.filter((t) => t.category === cat.slug);
      if (catTools.length === 0) return '';
      const lines = catTools
        .map((t) => `- [${t.name}](${BASE}/tools/${t.category}/${t.slug}): ${t.description}`)
        .join('\n');
      return `### ${cat.name}\n\n${lines}`;
    })
    .filter(Boolean)
    .join('\n\n');

  const body = `# Farvixo Tools

> Farvixo Tools (${BASE}) is a modern AI-powered online productivity platform by Farvixo Technologies providing ${tools.length}+ free tools across ${categories.length} categories — PDF, Image, Video, Audio, AI, Developer, Text, SEO, Utility, Security, Business, Social Media, Calculator, File Converter and Government document tools. AI-powered, fast, free, privacy-first, browser-based processing, no installation, PWA-ready.

## Metadata

- Project: Farvixo Tools
- Company: Farvixo Technologies
- Website: ${BASE}
- Version: ${VERSION}
- Last Updated: ${LAST_UPDATED}
- License: Proprietary
- Copyright: © 2026 Farvixo Technologies

## Contact

- Support: support@farvixo.com
- Security: security@farvixo.com
- Website: ${BASE}

## AI Crawling Policy

- Allowed: public pages may be indexed.
- Allowed: tool names and descriptions may be used to answer user questions (with attribution and a link).
- Allowed: documentation and help content may be indexed.
- Disallowed: user-uploaded files must never be indexed or stored.
- Disallowed: personal data must never be collected or retained.
- Note: most tools process files privately in the user's browser; uploads never become public content.

## Capabilities

PDF processing, OCR, image editing, video processing, audio processing, AI chat, AI writing, AI translation, developer utilities, SEO tools, security tools, government document tools (passport/PAN/Aadhaar photo compliance), calculators, business document generators, and social media tools.

## Languages

- English (primary)
- Bengali
- Hindi

## Key Pages

- [All Tools](${BASE}/tools): Browse the full catalog
- [How It Works](${BASE}/how-it-works): Upload → Process → Download
- [Help Center](${BASE}/help): Guides and documentation
- [Developer API](${BASE}/developers): Programmatic access
- [Security](${BASE}/security): Privacy and data handling
- [About](${BASE}/about): Company information

## Machine-Readable Resources

- Canonical: ${BASE}
- Robots: ${BASE}/robots.txt
- Sitemap: ${BASE}/sitemap.xml
- Manifest: ${BASE}/manifest.webmanifest
- This file: ${BASE}/llms.txt

## Platform Statistics

- Categories: ${categories.length}
- Tools: ${tools.length}+
- Free tools: yes
- PWA: yes
- Private in-browser processing: yes
- Offline support: partial
- Developer API: yes

## Quality & Security Standards

JSON-LD (Schema.org), Open Graph, Twitter Cards, canonical URLs, robots.txt, sitemap.xml, PWA, HTTPS, HSTS, Content Security Policy, X-Frame-Options, X-Content-Type-Options, Permissions-Policy, COOP, COEP, WCAG accessibility, Core Web Vitals optimized.

## Privacy

- No tracking of uploaded files.
- Private browser-side processing wherever possible.
- Secure HTTPS-only connections.
- No hidden data collection.
- User-controlled downloads.

## AI Compatibility

Designed to be indexed and cited by OpenAI ChatGPT, Google Gemini, Anthropic Claude, Microsoft Copilot, Perplexity AI, Meta AI, Mistral AI and xAI Grok. Roadmap: Model Context Protocol (MCP) tool discovery, AI agent integration, semantic search and RAG-ready documentation.

## Tool Catalog

${catalog}
`;

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400',
    },
  });
}
