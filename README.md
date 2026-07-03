# 🚀 ToolNest — One Platform. Infinite Tools. Powered by AI.

**ToolNestFM** · Faruk Mondal | Fam Cloud Pvt. Ltd. · https://toolnestfm.com

A full Next.js 15 platform with **130 working tools across 15 categories** — PDF, Image, Video, Audio, AI, Developer, Text, SEO, Business, Social, Utility, Security, Calculator, File Converter and Government tools. The homepage matches the approved deep-space/violet mockup.

## ▶ Run it

```bash
npm install
npm run dev        # development → http://localhost:3000
```

Production:

```bash
npm run build
npm start
```

> Node.js 18.18+ (Node 20 LTS recommended). First `npm install` takes a few minutes.

## ✨ What's included

| Area | Status |
|---|---|
| Homepage (Hero, Stats, Explorer, Features, Newsletter) | ✅ |
| 130 tools × dedicated SEO pages | ✅ |
| 15 category landing pages | ✅ |
| ⌘K command palette + AI Assistant panel | ✅ |
| Auth (login/signup) + Dashboard | ✅ |
| Legal pages (Privacy, Terms, GDPR, etc.) | ✅ |
| Blog + Help + Status + Contact | ✅ |
| API routes (health, search, tools, newsletter) | ✅ |
| Sitemap (XML + HTML) + robots.txt | ✅ |

## ✨ How the tools work

- **Everything runs in the browser** wherever possible — files never leave the device (privacy by design).
- **PDF tools** — pdf-lib + pdf.js (merge, split, compress, protect w/ real AES encryption, sign, edit, convert).
- **Image tools** — Canvas engine (convert/compress/resize/crop/rotate/watermark/upscale/enhance) + Indian govt photo presets (PAN, Aadhaar, Passport, SSC/UPSC/IBPS/NEET).
- **Background Remover / Changer** — real AI model (@imgly, WASM) loaded from CDN on first use (~40MB, cached).
- **Video/Audio tools** — FFmpeg WebAssembly (convert, compress, trim, merge, split, watermark, GIF, voice changer, noise remover). First use downloads the engine (~30MB, cached).
- **OCR** — Tesseract.js (8 languages) for images and scanned PDFs.
- **AI tools** — work FREE out of the box (Pollinations fallback). For best quality, add your own **Google Gemini API key** via the ✨ AI Assistant → ⚙ settings (stored only in your browser; free key at aistudio.google.com).
- **AI Image Generator** — free generation via Pollinations.
- **Server-side tools** — SEO Analyzer, SSL Checker, URL Scanner, Instagram DP use Next.js API routes.

## 🗂 Structure

```
app/                  pages, API routes, sitemap, robots, legal, auth, dashboard
components/           layout, homepage, GlobalUI (⌘K, AI panel, toasts, theme)
components/tool/      ToolRunner dispatcher + 21 runner engines powering all 130 tools
data/                 categories.ts (15) · tools.ts (130 tools — single source of truth)
lib/                  ai.ts · pdf.ts · image.ts · auth.ts · api-response.ts
```

Adding a tool = add one entry in `data/tools.ts` → it automatically appears in search, sitemap, its category grid and gets its own SEO-ready page.

## 🔌 API endpoints

| Route | Method | Purpose |
|---|---|---|
| `/api/health` | GET | Uptime / status check |
| `/api/search?q=` | GET | Fuzzy search across all tools |
| `/api/tools` | GET | List tools (filter by category, sort) |
| `/api/newsletter/subscribe` | POST | Newsletter signup |
| `/api/seo/analyze` | POST | SEO Analyzer backend |
| `/api/security/ssl` | POST | SSL Checker backend |
| `/api/security/scan` | POST | URL Scanner backend |
| `/api/social/instagram` | GET | Instagram DP fetch |

## 👤 Auth & Dashboard

- `/login` · `/signup` — client-side auth (localStorage demo; wire to Supabase Auth in production)
- `/dashboard` — overview, storage, quick-access tools
- `/dashboard/history` · `/billing` · `/settings` — account management

## ⌨ Tips

- **⌘K / Ctrl+K** — command palette (search all tools)
- Theme toggle, notifications, AI Assistant — top right
- Deploy on Vercel: import repo → deploy (zero config)

## 🚀 Production checklist

Connect these env vars for full production (see `CLAUDE.md` for full list):

- `GEMINI_API_KEY` — server-side AI (optional; users can bring their own key)
- `NEXT_PUBLIC_SUPABASE_URL` + keys — real auth & database
- `STRIPE_SECRET_KEY` — Pro billing checkout
- `RESEND_API_KEY` — transactional email
