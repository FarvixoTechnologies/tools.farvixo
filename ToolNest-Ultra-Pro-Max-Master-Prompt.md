# 🚀 Farvixo Tools — ULTRA PRO MAX MASTER PROMPT
### v3.0 — Complete End-to-End Build Specification for Cursor AI / Claude Code

**Project:** Farvixo Tools
**Company:** Farvixo Technologies · **Owner:** Faruk Mondal
**Production:** https://tools.farvixo.com | **Dev:** https://farvixo.vercel.app
**Mission:** *"One account, one history, one AI brain — across every tool."*
**Positioning:** Compete with Canva, Adobe Express, iLovePDF, Smallpdf, TinyWow, ChatGPT — but unified.

> This document is the **single source of truth**. Every other spec (homepage-only doc, tool catalog) is a subset of this file. Build strictly in the phased order in Section 24.

---

## 1. Executive Summary

Farvixo Tools is a fullstack SaaS platform with **15 categories, 139+ professional tools**, one login, one file history, one AI brain, and one design system shared across every tool page. The homepage is the flagship page and must match the approved mockup 100%. Every tool page inherits the same Universal Engines so the platform *feels like one product*, not 139 stitched-together micro-apps.

**Core Differentiator:** Competitors (iLovePDF, TinyWow) are single-purpose or fragmented. Farvixo Tools gives one account → one file history → one AI assistant that has context across every tool a user has ever touched.

---

## 2. Complete Tech Stack (Pinned)

| Layer | Technology | Notes |
|---|---|---|
| Framework | Next.js 15 (App Router) | Server Components by default |
| UI Library | React 19 | |
| Language | TypeScript (strict mode) | No `any` allowed |
| Styling | Tailwind CSS v4 | Custom design tokens, no hardcoded hex in components |
| Components | shadcn/ui | Radix primitives underneath |
| Animation | Framer Motion | See Section 18 of prior doc for timing |
| State | Zustand | Per-domain stores, no single mega-store |
| Backend | Next.js Route Handlers | Colocated in `app/api` |
| Database | Supabase (PostgreSQL) | Row Level Security enabled on all tables |
| Auth | Supabase Auth / Auth.js | Google, GitHub, Email/Password, Magic Link |
| File Storage | Cloudflare R2 | Signed URLs, 7-day expiry default |
| Queue/Jobs | BullMQ + Redis | Heavy processing (video, OCR, AI) offloaded here |
| Realtime | Socket.IO | Job progress push to client |
| Payments | Stripe | Checkout + Customer Portal + Webhooks |
| AI | Google Gemini (primary) | Streaming responses, function calling for tool actions |
| Heavy Media Processing | Python Workers (FastAPI) | video/audio transcode, yt-dlp for social downloads |
| Hosting | Vercel (frontend/API) + Fly.io or Railway (Python workers, Redis) | |
| Monitoring | Sentry + Vercel Analytics + Better Uptime | |
| Email | Resend | Transactional + newsletter |

---

## 3. Environment Variables

```env
# App
NEXT_PUBLIC_APP_URL=https://tools.farvixo.com
NEXT_PUBLIC_APP_NAME=Farvixo Tools

# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Auth
NEXTAUTH_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

# Storage
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=farvixo-files
R2_PUBLIC_URL=

# Queue
REDIS_URL=

# AI
GEMINI_API_KEY=

# Payments
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PRICE_ID_PRO_MONTHLY=
STRIPE_PRICE_ID_PRO_YEARLY=

# Email
RESEND_API_KEY=

# Monitoring
SENTRY_DSN=
NEXT_PUBLIC_VERCEL_ANALYTICS_ID=

# Python Worker
PYTHON_WORKER_URL=
PYTHON_WORKER_SECRET=
```

---

## 4. Design System — Compact Reference
*(Full detail lives in the Homepage Master Spec doc — this is the quick-reference)*

- **Theme:** Deep-space dark base (`#0A0A12`), Violet primary (`#7C3AED`), Gold premium (`#F5B93D`)
- **Category accents:** PDF red, Image green, Video purple, Audio orange, AI magenta, Developer blue, SEO teal, Business amber, Security crimson, Utility slate, Social pink, Calculator cyan, Government indigo, File-Converter lime
- **Typography:** Sora/Cabinet Grotesk (display) · Inter (body) · JetBrains Mono (data/code)
- **Radius scale:** 8 / 12 / 16 / 999px · **Spacing unit:** 4px base
- **Motion:** All hover states 0.15–0.2s easeOut; page-level fades 0.4–0.5s; respects `prefers-reduced-motion`

---

## 5. Individual Tool Page Template
*(Every one of the 128 tools renders through this shared template — `ToolPageTemplate.tsx`)*

### 5.1 Layout (top to bottom)
1. **Breadcrumb** — Home / [Category] / [Tool Name]
2. **Tool Header** — icon (category-accent color) + H1 tool name + 1-line description + trust row ("Used 2.4M times · ⭐4.9 · 100% Secure")
3. **Main Workspace** (2-column desktop, stacked mobile):
   - **Left (60%):** Universal Uploader
     - Drag/drop zone with dashed violet border, cloud-upload icon, "Drag & drop or click to browse" + supported formats + max size (tier-dependent, see Section 21 of prior doc)
     - Multi-file support where relevant (Merge PDF, Image to PDF)
     - Uploaded file preview thumbnail/list with remove (×) button
   - **Right (40%):** Options Panel
     - Tool-specific settings (e.g., Compress PDF → quality slider; Image Resizer → width/height/aspect-lock; AI Writer → tone/length dropdowns)
     - Primary CTA button: "{Verb} Now" (e.g., "Compress Now") — violet filled, disabled until file uploaded
4. **Processing State** (replaces workspace during job):
   - Circular or linear progress, live percentage via Socket.IO, animated status text ("Uploading... / Processing... / Finalizing...")
   - Cancel button
5. **Result State:**
   - Before/after preview where applicable (image/PDF tools)
   - Primary "Download" button (violet) + "Save to Cloud" (if logged in) + "Share Link" (Pro)
   - File size before → after comparison badge (compression tools)
   - Secondary CTA: "Process Another File"
6. **How It Works** — 3-step visual (Upload → Process → Download), icon + short text each
7. **FAQ Accordion** — 4–6 tool-specific Q&As (also feeds Schema.org FAQPage for SEO)
8. **Related Tools** — 4–5 tool cards from same category (reuses `<ToolCard />`)
9. **Trust/Feature strip** — reuses homepage Section 6 component

### 5.2 States every tool page must handle
- Empty (no file yet) · Uploading · Validating (wrong format/too large → inline error) · Queued (busy server) · Processing · Completed · Failed (retry CTA) · Pro-gated (locked feature with upgrade prompt)

### 5.3 SEO per tool page
- `<title>`: `{Tool Name} — Free Online {Category} Tool | Farvixo Tools`
- Meta description: unique, action-oriented, ≤155 chars
- Schema.org: `SoftwareApplication` + `FAQPage` + `BreadcrumbList`
- Canonical URL, OG image auto-generated per tool (category color + icon)

---

## 6. Category Landing Page Template

1. Category hero: icon, name, short description, tool count, category accent-colored gradient background
2. Filter/sort bar (reuses homepage Section 5.2 controls)
3. Full grid of that category's tools (reuses `<ToolGrid />`)
4. Category-specific content block (SEO-focused, 150–250 words, "Why use Farvixo's {Category} Tools")
5. Related categories strip at bottom

---

## 7. Dashboard / Account Area (Logged-in)

| Page | Purpose |
|---|---|
| `/dashboard` | Overview: recent files, quick-access recent tools, storage usage bar, plan status |
| `/dashboard/history` | Full job history table (tool, date, status, download link), filter by category/date |
| `/dashboard/files` | Cloud storage file manager (grid/list), folder support (Pro) |
| `/dashboard/billing` | Current plan, invoice history, "Upgrade/Downgrade", Stripe Customer Portal link |
| `/dashboard/settings` | Profile, password, connected accounts (Google/GitHub), notification preferences, danger zone (delete account) |
| `/dashboard/api-keys` | (Pro/Enterprise) generate/revoke API keys for programmatic tool access |

---

## 8. Authentication Flows

1. **Signup:** Email+password OR Google/GitHub OAuth → email verification (Resend) → onboarding
2. **Login:** Same providers, "Remember me", rate-limited (5 attempts/15min)
3. **Magic Link:** passwordless option on login screen
4. **Password Reset:** email link → 1-hour expiry token → new password form
5. **Onboarding (first login only, 3-step modal):**
   - Step 1: "What will you use Farvixo Tools for most?" (chips: PDF, Image, Video, AI, Dev, Other) → personalizes homepage tool-recommendation order
   - Step 2: Quick tour tooltip overlay on Search, AI Assistant, Upgrade to Pro
   - Step 3: "You're all set!" + CTA to try a tool
6. **Session:** JWT via Supabase, refreshed silently, `middleware.ts` protects `/dashboard/**` and Pro-gated API routes

---

## 9. Notification System

**In-app (bell icon, header):**
- Job completed / failed
- Storage nearing limit (90%+)
- New tool launched
- Subscription renewal reminder (3 days before)

**Email triggers (via Resend):**
- Welcome email (on signup)
- Email verification
- Password reset
- Large job completed (video/AI processing >30s) — "Your file is ready"
- Weekly digest (Pro users, optional) — usage summary
- Payment receipt / payment failed
- Re-engagement (7 days inactive)

---

## 10. Analytics Event Taxonomy

All events fired via Universal Analytics Engine → stored + forwarded to Vercel Analytics:

```
homepage_hero_search_submitted        { query }
homepage_chip_clicked                 { chip_label }
homepage_cta_clicked                  { cta: 'explore_tools' | 'try_ai_assistant' | 'upgrade_pro' }
tool_card_clicked                     { tool_slug, category, position_in_grid }
tool_card_load_more_clicked           { current_count }
category_sidebar_selected             { category_slug }
tool_upload_started                   { tool_slug, file_type, file_size_mb }
tool_processing_completed             { tool_slug, duration_ms }
tool_processing_failed                { tool_slug, error_code }
tool_download_clicked                 { tool_slug }
ai_assistant_opened                   { source: 'header' | 'hero' }
ai_message_sent                       { char_count }
newsletter_subscribed                 { source }
signup_completed                      { provider }
upgrade_to_pro_clicked                { source_component }
checkout_completed                    { plan, amount }
```

---

## 11. SEO Strategy (Site-wide)

- **Homepage title:** `Farvixo Tools — 139+ Free Online AI & Productivity Tools`
- **Sitemap:** dynamic `sitemap.xml` generated from `data/tools.ts` + `data/categories.ts` + blog posts
- **Robots.txt:** allow all except `/dashboard`, `/api`
- **Structured data:** `Organization` on every page (footer), `WebApplication` on homepage, `SoftwareApplication` per tool, `FAQPage` per tool, `BreadcrumbList` on all nested pages
- **Internal linking:** every tool page links to 4–5 related tools + its category; every category links back to homepage sections
- **Core Web Vitals:** LCP <2.0s (hero image lazy + priority split), CLS <0.1 (reserve space for all async-loaded cards), INP <200ms

---

## 12. Content / Blog Architecture

`/blog` — for SEO + authority building:
- `/blog/[slug]` — long-form guides ("How to Compress a PDF Without Losing Quality", "10 Best AI Writing Tools in 2026")
- Categories mirror tool categories for internal linking
- Each post: author bio, related tools CTA block, reading time, table of contents (auto-generated from headings)

---

## 13. Legal & Trust Pages

`/privacy-policy` · `/terms-of-service` · `/cookie-policy` · `/refund-policy` · `/gdpr` · `/security` (dedicated page detailing SSL, encryption, GDPR compliance — referenced by footer "Trusted & Secure" badge) · `/sitemap` (HTML version) · `/status` (uptime page, links to Better Uptime status page)

---

## 14. Internationalization (Post-MVP, Architecture Now)

- `next-intl` or built-in App Router i18n routing: `/[locale]/...`
- Launch locales: English (default) → Hindi → Spanish → Portuguese
- Language selector in header (already in mockup) wires to locale switch, persists in cookie
- All tool names/descriptions/UI strings externalized to translation JSON from day one, even if only English is populated at launch

---

## 15. Security Checklist

- [ ] Row Level Security on every Supabase table (users only read/write their own rows)
- [ ] Signed, expiring URLs for all file downloads (never public R2 URLs)
- [ ] Rate limiting on `/api/ai/*`, `/api/upload`, `/api/auth/*` (per-IP + per-user)
- [ ] File upload validation: MIME-type sniffing (not just extension), max size enforced server-side, virus/malware scan hook before processing
- [ ] Stripe webhook signature verification
- [ ] CSRF protection on all mutating routes
- [ ] Content-Security-Policy headers, `X-Frame-Options: DENY`
- [ ] Secrets never exposed client-side (`NEXT_PUBLIC_*` prefix audit)
- [ ] Auto-delete uploaded files after 24h for free tier (storage hygiene + privacy), configurable retention for Pro
- [ ] 2FA available for account settings (TOTP)

---

## 16. Testing Strategy

| Layer | Tool | Coverage Target |
|---|---|---|
| Unit | Vitest | Utils, engines, Zustand stores |
| Component | React Testing Library | ToolCard, SearchBar, Sidebar, Forms |
| Integration | Vitest + MSW (mocked API) | Upload → Process → Download flow |
| E2E | Playwright | Signup→Upgrade→Use Tool→Download critical path; homepage visual regression against mockup |
| Accessibility | axe-core (CI) | Zero critical violations on homepage + tool template |
| Load | k6 | `/api/upload` and `/api/ai/chat` under concurrent load |

---

## 17. CI/CD Pipeline (GitHub Actions)

```yaml
on: [push, pull_request]
jobs:
  lint-typecheck-test:
    steps:
      - run: pnpm lint
      - run: pnpm typecheck
      - run: pnpm test
      - run: pnpm test:e2e (on PR to main only)
  preview-deploy:
    # Vercel auto preview per PR
  production-deploy:
    if: branch == main
    steps:
      - run: pnpm build
      - deploy to Vercel production
      - run Lighthouse CI, fail build if score <90 mobile
```

---

## 18. Monitoring & Observability

- **Sentry:** frontend + API route error tracking, source maps uploaded on deploy
- **Vercel Analytics + Speed Insights:** Core Web Vitals real-user monitoring
- **Better Uptime (or similar):** pings `/api/health` every 60s, powers the footer "Status 🟢" indicator
- **BullMQ dashboard (Bull Board):** internal-only, monitor job queue health
- **Structured logging:** every API route logs `requestId`, `userId`, `route`, `durationMs`, `status`

---

## 19. Full Per-Tool Micro-Spec (All 128 Tools)

*Format: **Tool** — Input → Output | Type | Primary Engine*
AI = Gemini-backed · STD = deterministic/library-based · Type badge shown on homepage card matches this.

### 🏛 Government Tools (STD, image-processing engine)
1. Passport Photo Maker — Photo → Cropped ID photo (country presets)
2. Passport Signature Resizer — Signature image → Resized/DPI-corrected image
3. PAN Card Photo Resizer — Photo → Compliant-size photo
4. Aadhaar Photo Resizer — Photo → Compliant-size photo
5. Aadhaar PDF Compressor — PDF → Compressed PDF (size target for UIDAI upload)
6. Voter ID Photo Resizer — Photo → Compliant-size photo
7. Driving Licence Photo Resizer — Photo → Compliant-size photo
8. Exam Photo & Signature Resizer — Photo + Signature → Dual compliant outputs

### 📄 PDF Tools (STD, PDF engine — pdf-lib/pdf.js + Python worker for OCR)
9. PDF Converter — Any doc → PDF / PDF → Any
10. PDF Editor — PDF → Edited PDF (text/annotate)
11. Merge PDF — Multiple PDFs → 1 PDF
12. Split PDF — PDF → Multiple PDFs
13. Compress PDF — PDF → Smaller PDF
14. PDF OCR — Scanned PDF → Searchable PDF **(AI/OCR engine)**
15. PDF to Word — PDF → DOCX
16. Word to PDF — DOCX → PDF
17. PDF to Excel — PDF → XLSX
18. Excel to PDF — XLSX → PDF
19. Protect PDF — PDF → Password-protected PDF
20. Sign PDF — PDF → Digitally signed PDF

### 🖼 Image Tools (STD + AI hybrid)
21. Image Converter — Image → Image (format change)
22. Image Compressor — Image → Smaller image
23. Image Resizer — Image → Resized image
24. Crop Image — Image → Cropped image
25. Rotate & Flip Image — Image → Transformed image
26. Background Remover — Image → Transparent-bg image **(AI)**
27. Background Changer — Image → New-bg image **(AI)**
28. AI Image Upscaler — Image → Higher-res image **(AI)**
29. AI Photo Enhancer — Image → Enhanced image **(AI)**
30. AI Object Remover — Image + mask → Cleaned image **(AI)**
31. Image OCR — Image → Extracted text **(AI/OCR)**
32. Watermark Image — Image + text/logo → Watermarked image

### 🎥 Video Tools (STD via ffmpeg Python worker + AI subtitle)
33. Video Converter — Video → Video (format change)
34. Video Compressor — Video → Smaller video
35. Video Trimmer — Video → Trimmed clip
36. Video Merger — Multiple videos → 1 video
37. Video Splitter — Video → Multiple clips
38. Video Watermark — Video + logo → Watermarked video
39. Video to GIF — Video → GIF
40. AI Subtitle Generator — Video → SRT/VTT + burned-in subtitles **(AI)**

### 🎵 Audio Tools (STD via ffmpeg + AI)
41. Audio Converter — Audio → Audio (format change)
42. Audio Compressor — Audio → Smaller audio
43. Audio Cutter — Audio → Trimmed clip
44. Audio Merger — Multiple audio → 1 file
45. Text to Speech — Text → Audio **(AI)**
46. Speech to Text — Audio → Text **(AI)**
47. Voice Changer — Audio → Modified voice audio **(AI)**
48. AI Noise Remover — Audio → Cleaned audio **(AI)**

### 🤖 AI Tools (all AI, Gemini engine)
49. AI Chat — Prompt → Streamed chat response
50. AI Writer — Brief → Long-form text
51. AI Image Generator — Prompt → Generated image
52. AI Resume Builder — Form input → Formatted resume PDF
53. AI Translator — Text → Translated text
54. AI Summarizer — Text/doc → Summary
55. AI Email Writer — Brief → Drafted email
56. AI SEO Writer — Keyword/brief → SEO-optimized article
57. AI Code Generator — Prompt → Code snippet
58. AI Research Assistant — Query → Synthesized answer + sources
59. AI Presentation Maker — Topic/outline → PPTX
60. AI PDF Assistant — PDF + question → Answer (RAG over uploaded PDF)

### 💻 Developer Tools (STD, client-side where possible)
61. JSON Formatter — JSON → Pretty JSON
62. JSON Validator — JSON → Validation result
63. Base64 Encoder & Decoder — Text/file ↔ Base64
64. URL Encoder & Decoder — Text ↔ URL-encoded
65. JWT Decoder — JWT → Decoded payload
66. UUID Generator — — → UUID(s)
67. Hash Generator — Text/file → Hash (MD5/SHA family)
68. API Tester — Request config → Response viewer

### 📝 Text Tools (STD, client-side)
69. Case Converter — Text → Case-transformed text
70. Word Counter — Text → Count stats
71. Character Counter — Text → Count stats
72. Text Compare — 2 texts → Diff view
73. Remove Duplicate Lines — Text → De-duplicated text
74. Reverse Text — Text → Reversed text
75. Text Sorter — Text lines → Sorted lines
76. Lorem Ipsum Generator — Params → Placeholder text

### 🌐 SEO Tools (STD + light AI)
77. SEO Analyzer — URL → Audit report
78. Meta Tag Generator — Page info → Meta tag snippet
79. Sitemap Generator — Site URL/list → sitemap.xml
80. Robots.txt Generator — Rules form → robots.txt
81. Open Graph Generator — Page info → OG tag snippet
82. Schema Markup Generator — Content type/form → JSON-LD snippet
83. Keyword Density Checker — Text/URL → Density report
84. Canonical URL Generator — URL → Canonical tag snippet

### ⚙ Utility Tools (STD, client-side)
85. QR Code Generator — Text/URL → QR image
86. Barcode Generator — Data → Barcode image
87. Password Generator — Params → Password
88. Password Strength Checker — Password → Strength score
89. Unit Converter — Value+unit → Converted value
90. Currency Converter — Amount+currency → Converted amount (live rates API)
91. Timestamp Converter — Timestamp ↔ Human date
92. Random Number Generator — Range params → Number(s)

### 🔐 Security Tools (STD)
93. MD5 Generator — Text/file → MD5 hash
94. SHA1 Generator — Text/file → SHA1 hash
95. SHA256 Generator — Text/file → SHA256 hash
96. SHA512 Generator — Text/file → SHA512 hash
97. File Checksum Generator — File → Checksum
98. SSL Checker — Domain → SSL report
99. URL Scanner — URL → Safety report
100. Encryption Tool — Text/file + key → Encrypted output

### 💼 Business Tools (STD)
101. Invoice Generator — Form data → Invoice PDF
102. GST Calculator — Amount+rate → GST breakdown
103. EMI Calculator — Loan params → EMI schedule
104. Profit Margin Calculator — Cost/price → Margin %
105. Salary Calculator — CTC params → In-hand breakdown
106. Receipt Generator — Form data → Receipt PDF
107. Business Card Generator — Form + template → Card design (PDF/PNG)
108. Quotation Generator — Form data → Quotation PDF

### 📱 Social Media Tools (STD + AI + external fetch)
109. YouTube Thumbnail Downloader — Video URL → Thumbnail image
110. Instagram DP Downloader — Profile URL → Profile photo
111. Instagram Caption Generator — Topic → Caption **(AI)**
112. Hashtag Generator — Topic → Hashtag set **(AI)**
113. YouTube Thumbnail Maker — Assets/template → Thumbnail design
114. YouTube Tag Generator — Topic → Tag list **(AI)**
115. Social Media Post Generator — Brief → Post copy **(AI)**
116. Bio Generator — Keywords → Bio text **(AI)**

### 🧮 Calculator Tools (STD, client-side)
117. Age Calculator — DOB → Age breakdown
118. BMI Calculator — Height/weight → BMI + category
119. Percentage Calculator — Values → Percentage result
120. Loan EMI Calculator — Loan params → EMI schedule
121. Discount Calculator — Price+discount → Final price
122. Scientific Calculator — Expression → Result

### 📦 File Converter Tools (STD)
123. ZIP Creator — Files → ZIP archive
124. ZIP Extractor — ZIP → Extracted files
125. CSV to Excel — CSV → XLSX
126. Excel to CSV — XLSX → CSV
127. XML to JSON — XML → JSON
128. JSON to XML — JSON → XML

---

## 20. Homepage — Restated Full Layout Order

1. Sticky Header (logo, nav, search, AI Assistant, locale, theme, bell, avatar+PRO)
2. Hero (headline, search, CTAs, social proof, 3D cube, "Why Farvixo Tools?" card)
3. Stats Bar (6 metrics)
4. Tools Explorer (Category Sidebar + Tool Grid, 15 cards + Load More)
5. Feature Strip (5 trust pillars)
6. Newsletter Section
7. Footer (6 columns + bottom bar)

*(Full pixel/token/animation detail for each of the above is in the companion "Homepage Master Build Specification" document — this Ultra Pro Max doc adds everything around it: architecture, data, ops, growth, and the per-tool contract table in Section 19.)*

---

## 21. Growth & Retention Hooks (Technical)

- **Referral system:** `/api/referral/generate` → unique code per user, tracked in `referrals` table, both parties get +5GB storage or 1 free Pro month
- **Affiliate program** (footer link) — cookie-based attribution, 30-day window, Stripe Connect payout
- **Recently Used Tools** — homepage sidebar personalizes order post-onboarding based on `jobs` table history for logged-in users
- **"Continue where you left off"** — dashboard widget resuming an incomplete job
- **Streak/usage badges** (optional gamification, Phase 2) — not required for MVP

---

## 22. Launch Checklist

- [ ] Lighthouse Mobile ≥90 on homepage + top 10 tool pages
- [ ] All 128 tool routes return 200, have unique meta title/description
- [ ] Sitemap submitted to Google Search Console
- [ ] Stripe live keys swapped in, webhook verified in production
- [ ] Legal pages published and linked from footer
- [ ] Error monitoring (Sentry) confirmed receiving events
- [ ] Status page live, uptime monitor pinging `/api/health`
- [ ] Backup strategy confirmed for Supabase (daily automated)
- [ ] Rate limits verified under load test (k6)
- [ ] GDPR data-export / delete-account flow tested end-to-end

---

## 23. Non-Negotiable Build Rules (Fable AI / Cursor / Claude Code)

- Always production-ready code — no TODO placeholders unless explicitly requested
- Reusable components only — no copy-pasted tool pages; everything flows through `ToolPageTemplate`
- Never hardcode colors/spacing — always design tokens
- Server Components by default; `"use client"` only where interactivity requires it
- Every mutating API route validates input with Zod before touching the database
- Every new tool added to `data/tools.ts` automatically appears in search, sitemap, and its category grid — zero manual wiring
- WCAG AA minimum on every shipped page
- Enterprise-grade error handling over quick fixes, always

---

## 24. Master Phased Build Order (Final)

1. Design tokens + theme engine
2. Static layout shell (Header/Nav/Footer/Sidebar)
3. `data/categories.ts` + `data/tools.ts` (all 128 tools from Section 19)
4. Static homepage sections (Hero, Stats, Features, Newsletter)
5. Tools Explorer wired to data layer (client-side filter/sort)
6. Search Engine + `⌘K` command palette
7. Supabase schema + RLS + Auth Engine (signup/login/OAuth/onboarding)
8. Universal Upload/Processing/Download Engines — pilot on **Compress PDF**
9. Roll out remaining PDF + Image tools (STD engine reuse)
10. AI Engine (Gemini) — AI Assistant chat, then AI Tools category (12 tools)
11. Video/Audio tools via Python worker + ffmpeg
12. Dashboard (`/dashboard/*`) — history, files, settings
13. Billing Engine — Stripe Checkout, Pro gating (Section 21 of prior doc)
14. Remaining categories: Developer → Text → SEO → Utility → Security → Business → Social → Calculator → File Converter → Government
15. Notifications (in-app + email) + Analytics event wiring
16. Blog + legal pages + i18n scaffolding
17. Testing pass (unit → integration → E2E → accessibility)
18. CI/CD pipeline + monitoring/observability setup
19. Security audit against Section 15 checklist
20. Performance pass — Lighthouse ≥90 mobile site-wide
21. Launch checklist (Section 22) → production deploy

---

**End of Ultra Pro Max Master Prompt.** This document + the companion Homepage Master Build Specification together form the complete build contract for Farvixo Tools.
