# FARVIXO ENTERPRISE DOCUMENTATION
# Cloudflare Setup for tools.farvixo.com

**Version:** 1.0  
**Last updated:** July 2026  
**Company:** Farvixo Technologies Pvt. Ltd.  
**Tagline:** Build Beyond.  
**Production URL:** https://tools.farvixo.com  
**Main website:** https://farvixo.com  
**Status:** Production Ready

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Final Architecture](#2-final-architecture)
3. [Domains](#3-domains)
4. [Cloudflare DNS](#4-cloudflare-dns)
5. [SSL / TLS](#5-ssl--tls)
6. [Speed & Performance](#6-speed--performance)
7. [Cache Rules](#7-cache-rules)
8. [Security (Cloudflare)](#8-security-cloudflare)
9. [Application Pages](#9-application-pages)
10. [Tool Catalog](#10-tool-catalog)
11. [API Standard Response](#11-api-standard-response)
12. [Complete API Reference](#12-complete-api-reference)
13. [Public Developer API (v1)](#13-public-developer-api-v1)
14. [Admin API](#14-admin-api)
15. [Authentication](#15-authentication)
16. [Cloudflare Workers & R2](#16-cloudflare-workers--r2)
17. [Supabase](#17-supabase)
18. [Workers AI](#18-workers-ai)
19. [Environment Variables](#19-environment-variables)
20. [Security Headers (Application)](#20-security-headers-application)
21. [SEO](#21-seo)
22. [Analytics & Monitoring](#22-analytics--monitoring)
23. [Deployment Pipeline](#23-deployment-pipeline)
24. [Project Folder Structure](#24-project-folder-structure)
25. [Production Checklist](#25-production-checklist)
26. [Final Goal](#26-final-goal)

---

## 1. Purpose

This document is the **single enterprise reference** for deploying and operating the **Farvixo Tools Platform** on Cloudflare's global edge network at:

**https://tools.farvixo.com**

The platform delivers **139+ online tools** across **15 categories**, powered by:

| Layer | Technology |
|---|---|
| Frontend | Next.js 15 (App Router), React 19, TypeScript |
| Hosting | Cloudflare Pages (production target) |
| Edge compute | Cloudflare Workers (API offload target) |
| Database & Auth | Supabase (PostgreSQL + Auth) |
| Object storage | Cloudflare R2 (uploads/exports target) |
| Bot protection | Cloudflare Turnstile |
| AI | Google Gemini (primary), Groq & OpenRouter (fallback) |
| Payments | Stripe |
| Email | Resend (transactional) |

Most tool processing runs **client-side in the browser** (PDF, image, video via WASM/ffmpeg). Server APIs handle auth, billing, AI proxying, search, analytics, sharing, and admin operations.

---

## 2. Final Architecture

```
Internet
    ↓
Cloudflare DNS
    ↓
Cloudflare CDN (WAF, Bot Fight, Rate Limiting, Turnstile)
    ↓
Cloudflare Pages  →  Next.js Application (SSR / ISR / Edge)
    ↓
┌───────────────────────────────────────────────────────────┐
│  Next.js Route Handlers  (/api/*)                         │
│  • Auth & profiles        • AI proxy                      │
│  • Billing (Stripe)       • Search & analytics            │
│  • Share links            • Public API v1                 │
│  • Admin panel            • Tool metadata                 │
└───────────────────────────────────────────────────────────┘
    ↓                              ↓
Supabase                      Cloudflare R2
(PostgreSQL, Auth,            (uploads, exports,
 Storage for shares)           media, temp, cache)
    ↓
Workers AI (optional edge AI offload)
```

### Request flow summary

| Path type | Handler | Cache |
|---|---|---|
| Static assets (`/_next/static/*`) | Cloudflare CDN | 1 year |
| Tool pages (`/tools/*`) | Next.js SSR/ISR | Dynamic HTML |
| Dashboard (`/dashboard/*`) | Next.js + Supabase session | Bypass cache |
| API (`/api/*`) | Next.js Route Handlers | No cache (except noted) |
| OG images (`/api/og`) | Edge runtime | Short CDN cache |

---

## 3. Domains

| Domain | Purpose |
|---|---|
| **farvixo.com** | Company website (Farvixo Technologies) |
| **tools.farvixo.com** | Farvixo Tools — 139+ online tools platform |
| **farvixo.vercel.app** | Staging / preview (optional) |

---

## 4. Cloudflare DNS

| Field | Value |
|---|---|
| **Type** | CNAME |
| **Name** | `tools` |
| **Target** | `<your-project>.pages.dev` |
| **Proxy** | ON (orange cloud) |
| **TTL** | Auto |

> Replace `<your-project>` with your Cloudflare Pages project subdomain after linking the GitHub repository.

---

## 5. SSL / TLS

| Setting | Value |
|---|---|
| Encryption mode | **Full (Strict)** |
| Always HTTPS | ON |
| Automatic HTTPS Rewrites | ON |
| Minimum TLS version | **1.3** |
| TLS 1.3 | Enabled |
| HTTP/3 | ON |
| 0-RTT | ON |

---

## 6. Speed & Performance

| Setting | Value | Notes |
|---|---|---|
| Auto Minify — HTML | ON | |
| Auto Minify — CSS | ON | |
| Auto Minify — JavaScript | ON | |
| Brotli | ON | |
| Early Hints | ON | |
| Rocket Loader | **OFF** | Breaks React hydration |
| HTTP/2 | ON | |
| HTTP/3 | ON | |
| Image Optimization | ON | |
| Polish | Lossless | |
| Mirage | ON | |

### Application-level performance

- Edge cache for public stats (`/api/stats/*`) — 5 min CDN TTL
- OpenAPI spec (`/api/v1/openapi.json`) — 1 hour cache
- Client-side tool engines (no server round-trip for PDF/image/video)
- Code splitting per tool runner
- Lazy-loaded hero graphics & ffmpeg WASM
- Font optimization via `next/font`
- `prefers-reduced-motion` respected

---

## 7. Cache Rules

Configure in **Cloudflare Dashboard → Caching → Cache Rules**:

| Rule | Match | Cache behavior |
|---|---|---|
| HTML pages | `tools.farvixo.com/*` (not `/api/*`, not `/dashboard/*`) | Cache dynamic / short TTL |
| Static files | `/_next/static/*`, `/favicon.svg`, `/manifest.json` | 1 year |
| Fonts | `*.woff2`, `*.woff` | 1 year |
| Images | `/public/*`, `*.png`, `*.jpg`, `*.webp`, `*.svg` | 1 year |
| JS bundles | `/_next/static/chunks/*` | 1 year |
| CSS | `/_next/static/css/*` | 1 year |
| API routes | `/api/*` | **Bypass cache** |
| Auth routes | `/login`, `/signup`, `/auth/*` | **Bypass cache** |
| Dashboard | `/dashboard/*` | **Bypass cache** |
| Admin | `/admin/*` | **Bypass cache** |

### Cacheable API exceptions (built-in headers)

| Endpoint | Cache-Control |
|---|---|
| `GET /api/stats/public` | `public, s-maxage=300, stale-while-revalidate=600` |
| `GET /api/stats/tools` | `public, s-maxage=300, stale-while-revalidate=600` |
| `GET /api/v1/openapi.json` | `public, max-age=3600` |

---

## 8. Security (Cloudflare)

| Feature | Setting |
|---|---|
| WAF | Enabled |
| Bot Protection | Enabled |
| Browser Integrity Check | ON |
| Security Level | Medium |
| DDoS Protection | ON |
| Rate Limiting | Enabled (edge rules + app-level limits) |

### Cloudflare Turnstile

Deploy on high-abuse surfaces:

| Surface | Status |
|---|---|
| Login (`/login`) | Recommended |
| Signup (`/signup`) | Recommended |
| Contact form (`/contact`) | Recommended |
| Feedback forms | Recommended |
| API abuse protection | Rate-limit rules on `/api/ai/*`, `/api/contact` |

**Environment variables:** See **[§19.4 Cloudflare](#194-grouped-reference)** (`NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET_KEY`).

---

## 9. Application Pages

### Public marketing

| Route | Page |
|---|---|
| `/` | Homepage |
| `/tools` | All tools directory |
| `/tools/[category]` | Category listing |
| `/tools/[category]/[tool]` | Individual tool page |
| `/blog` | Blog index |
| `/blog/[slug]` | Blog post |
| `/about` | About Farvixo |
| `/contact` | Contact form |
| `/help` | Help center |
| `/how-it-works` | How it works |
| `/developers` | Developer API docs |
| `/status` | Platform status |
| `/sitemap` | HTML sitemap |

### Authentication

| Route | Page |
|---|---|
| `/login` | Sign in (Google, GitHub, Email, Magic Link) |
| `/signup` | Create account |
| `/auth/callback` | OAuth / magic-link callback |
| `/auth/oauth` | OAuth initiation |
| `/unsubscribe` | Newsletter unsubscribe |

### User dashboard

| Route | Page |
|---|---|
| `/dashboard` | Overview |
| `/dashboard/history` | Tool usage history |
| `/dashboard/billing` | Subscription & invoices |
| `/dashboard/credits` | Credit balance & purchase |
| `/dashboard/api-keys` | API key management |
| `/dashboard/settings` | Profile & preferences |
| `/dashboard/notifications` | Notification center |

### Legal & trust

| Route | Page |
|---|---|
| `/privacy-policy` | Privacy policy |
| `/terms-of-service` | Terms of service |
| `/cookie-policy` | Cookie policy |
| `/refund-policy` | Refund policy |
| `/gdpr` | GDPR compliance |
| `/security` | Security practices |

### Sharing

| Route | Page |
|---|---|
| `/share/[token]` | Public file share download page |

### Admin panel

| Route | Page |
|---|---|
| `/admin` | Admin dashboard |
| `/admin/users` | User management |
| `/admin/tools` | Tool catalog admin |
| `/admin/analytics` | Platform analytics |
| `/admin/credits` | Credit management |
| `/admin/jobs` | Job history |
| `/admin/newsletter` | Newsletter subscribers |
| `/admin/contact` | Contact messages |
| `/admin/notifications` | Broadcast notifications |
| `/admin/settings` | Platform settings |
| `/admin/audit` | Audit log |
| `/admin/reports` | Reports |
| `/admin/team` | Admin team |
| `/admin/api-keys` | All API keys |
| `/admin/system` | System health |

---

## 10. Tool Catalog

**15 categories · 139+ tools** (source: `data/tools.ts`, `data/categories.ts`)

| Category | Slug | Tools |
|---|---|---|
| Government | `government` | 8 |
| PDF | `pdf` | 12 |
| Image | `image` | 12 |
| Video | `video` | 8 |
| Audio | `audio` | 8 |
| AI | `ai` | 12 |
| Developer | `developer` | 8 |
| Text | `text` | 8 |
| SEO | `seo` | 8 |
| Business | `business` | 8 |
| Social Media | `social` | 8 |
| Utility | `utility` | 8 |
| Security | `security` | 8 |
| Calculator | `calculator` | 6 |
| File Converter | `file-converter` | 6 |

Tool URLs follow: `/tools/{category}/{slug}`  
Example: `/tools/pdf/pdf-to-word`

---

## 11. API Standard Response

All JSON APIs (except raw binary endpoints) use this envelope:

```json
{
  "success": true,
  "data": { },
  "error": null,
  "meta": {
    "requestId": "uuid",
    "timestamp": "2026-07-09T12:00:00.000Z"
  }
}
```

**Error response:**

```json
{
  "success": false,
  "data": null,
  "error": "Human-readable error message",
  "meta": { "requestId": "uuid", "timestamp": "..." }
}
```

**Rate-limit response:** HTTP `429` with `Retry-After` header (seconds).

**Public API v1 auth:** `Authorization: Bearer fx_live_...`

---

## 12. Complete API Reference

Base URL: `https://tools.farvixo.com`

### 12.1 Health & Status

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/health` | None | Service health, version, uptime |

**Response `data`:**

```json
{
  "status": "ok",
  "service": "Farvixo API",
  "version": "1.0.0",
  "uptime": 12345.67,
  "timestamp": "2026-07-09T12:00:00.000Z"
}
```

---

### 12.2 Tools & Search

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/tools` | None | — | Full tool catalog with categories |
| `GET` | `/api/tools/[toolId]` | None | — | Single tool metadata by slug |
| `GET` | `/api/search` | None | — | Fuzzy search across all tools |

**`GET /api/tools` query params:**

| Param | Type | Default | Description |
|---|---|---|---|
| `category` | string | — | Filter by category slug |
| `sort` | string | `popular` | `popular` \| `name` \| `new` |

**`GET /api/search` query params:**

| Param | Type | Required | Description |
|---|---|---|---|
| `q` | string | Yes | Search query |
| `category` | string | No | Category filter |
| `limit` | number | 20 | Max results (max 50) |

**Search response `data`:**

```json
{
  "query": "pdf to word",
  "count": 3,
  "results": [
    {
      "slug": "pdf-to-word",
      "name": "PDF to Word",
      "description": "...",
      "category": "pdf",
      "badge": "popular",
      "href": "/tools/pdf/pdf-to-word"
    }
  ]
}
```

---

### 12.3 Statistics (Public)

| Method | Endpoint | Auth | CDN cache | Description |
|---|---|---|---|---|
| `GET` | `/api/stats/public` | None | 5 min | Platform user & job counts |
| `GET` | `/api/stats/tools` | None | 5 min | Per-tool usage counts |

**`GET /api/stats/public?tool=pdf-to-word`** — optional per-tool usage count.

---

### 12.4 User Profile & Account

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/me` | Session | — | Signed-in user profile, plan, role |
| `POST` | `/api/account/delete` | Session | 3 / min | Permanently delete account (GDPR) |

**`GET /api/me` response includes:** `id`, `email`, `name`, `avatar`, `plan` (`FREE` \| `PRO` \| `ENTERPRISE`), `role`, `storageUsedMb`, `isPro`.

---

### 12.5 Jobs & History

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/jobs` | Session | — | User's last 50 tool runs + today's count |
| `POST` | `/api/jobs` | Session (optional) | 30 / min | Record a tool usage event |

**`POST /api/jobs` body:**

```json
{
  "toolSlug": "pdf-compressor",
  "status": "used"
}
```

`status`: `used` \| `completed` \| `failed`

---

### 12.6 Credits

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/credits` | Session | Credit balance + last 50 ledger entries |

---

### 12.7 API Keys (Dashboard)

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/keys` | Session | — | List user's API keys (prefix only) |
| `POST` | `/api/keys` | Session | 10 / min | Create key — **full key returned once** |
| `DELETE` | `/api/keys?id={uuid}` | Session | — | Revoke a key |

Max **5 active keys** per user. Key format: `fx_live_...`

---

### 12.8 AI Endpoints

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `POST` | `/api/ai/chat` | Optional session | 12/min burst; 50/day free | Streaming AI chat (Gemini) |
| `POST` | `/api/ai/image-generate` | None | 10/min; 200/day | AI image generation proxy |

**`POST /api/ai/chat` body:**

```json
{
  "messages": [
    { "role": "user", "content": "Hello" }
  ],
  "system": "Optional system prompt",
  "model": "gemini-2.0-flash",
  "temperature": 0.7
}
```

- **Free users:** 50 server messages/day; then 1 credit/message if signed in
- **Pro/Enterprise:** Unlimited
- Returns **SSE stream** (`text/event-stream`)

**`POST /api/ai/image-generate` body:**

```json
{
  "prompt": "A violet hexagon in space",
  "negative": "blurry",
  "width": 1024,
  "height": 1024,
  "seed": 42,
  "model": "flux",
  "enhance": true
}
```

---

### 12.9 Billing (Stripe)

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/api/billing/checkout` | Session | Create Stripe Checkout for **Pro subscription** |
| `POST` | `/api/billing/credits-checkout` | Session | Create Stripe Checkout for **credit packs** |
| `POST` | `/api/billing/webhook` | Stripe signature | Webhook handler (no session) |

**Credit packs (`POST /api/billing/credits-checkout`):**

| Pack ID | Credits | Price |
|---|---|---|
| `starter` | 100 | $5.00 |
| `plus` | 500 | $20.00 |
| `mega` | 2,000 | $60.00 |

**Webhook events handled:**

- `checkout.session.completed` (subscription) → upgrade to PRO
- `checkout.session.completed` (credits) → grant credits
- `customer.subscription.deleted` → downgrade to FREE

---

### 12.10 Share Links

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/share` | Session | — | List user's active share links |
| `POST` | `/api/share` | Session | 10 / min | Upload file & create share link |
| `GET` | `/api/share/[token]` | None | 30 / min | Metadata or download |
| `DELETE` | `/api/share/[token]` | Session | — | Revoke share link |

**`POST /api/share`** — `multipart/form-data`:

| Field | Type | Description |
|---|---|---|
| `file` | File | Required, max 25 MB |
| `expiresInHours` | number | `1` \| `24` \| `168` \| `720` |
| `oneTime` | boolean | Single download |
| `password` | string | Optional, min 4 chars |
| `downloadLimit` | number | 1–100 |
| `toolSlug` | string | Source tool reference |

---

### 12.11 Notifications

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/notifications` | Session | — | List notifications + unread count |
| `PATCH` | `/api/notifications` | Session | — | Mark read |
| `DELETE` | `/api/notifications` | Session | — | Dismiss notifications |
| `POST` | `/api/notifications` | Session | 20 / min | Create client-side notification |

**`GET` query:** `limit` (max 50), `offset`

**`PATCH` body:** `{ "ids": ["uuid"], "all": false }`

**`DELETE` body:** `{ "ids": ["uuid"], "all": false, "readOnly": true }`

---

### 12.12 Newsletter & Contact

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `POST` | `/api/newsletter/subscribe` | None | 5 / min | Subscribe to newsletter |
| `POST` | `/api/newsletter/unsubscribe` | None | 5 / min | Unsubscribe |
| `POST` | `/api/contact` | None | 3 / 10 min | Contact form submission |

**Subscribe body:** `{ "email": "user@example.com", "source": "homepage" }`

**Contact body:** `{ "name": "...", "email": "...", "message": "..." }`

---

### 12.13 Analytics

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `POST` | `/api/analytics/track` | None | 60 / min | Fire-and-forget event tracking |

**Body:**

```json
{
  "event": "tool_card_clicked",
  "props": { "tool_slug": "pdf-to-word", "position": 1 },
  "userId": "optional-uuid"
}
```

**Standard events:** `homepage_hero_search_submitted`, `tool_card_clicked`, `tool_download_clicked`, `ai_assistant_opened`, `upgrade_to_pro_clicked`, `checkout_completed`, etc.

---

### 12.14 Tool Utility Proxies

| Method | Endpoint | Auth | Rate limit | Description |
|---|---|---|---|---|
| `GET` | `/api/fetch-pdf` | None | 15 / min | CORS-safe remote PDF proxy (max 50 MB) |
| `GET` | `/api/seo/analyze` | None | — | On-page SEO audit for a URL |
| `GET` | `/api/security/ssl` | None | — | SSL certificate check |
| `GET` | `/api/security/scan` | None | — | URL safety / phishing heuristics |
| `GET` | `/api/social/instagram` | None | — | Instagram profile photo resolver |
| `GET` | `/api/weather/enrich` | None | 60 / min | Weather alerts + moon data proxy |

**`GET /api/fetch-pdf?url=https://example.com/doc.pdf`**

**`GET /api/seo/analyze?url=https://example.com`**

**`GET /api/security/ssl?target=example.com`**

**`GET /api/security/scan?target=https://example.com`**

**`GET /api/social/instagram?user=username`**

**`GET /api/weather/enrich?lat=28.61&lon=77.23`**

---

### 12.15 Open Graph Image

| Method | Endpoint | Auth | Runtime | Description |
|---|---|---|---|---|
| `GET` | `/api/og` | None | Edge | Dynamic 1200×630 OG image |

**Query params:** `title`, `subtitle`, `badge`

Example: `/api/og?title=PDF%20to%20Word&subtitle=Free%20Online%20Tool&badge=PDF`

---

### 12.16 Cron / Maintenance

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/cron/cleanup-shares` | `Authorization: Bearer {CRON_SECRET}` | Delete expired shares + storage |

Schedule: daily via Cloudflare Cron Trigger or external scheduler.

---

## 13. Public Developer API (v1)

**Base URL:** `https://tools.farvixo.com/api/v1`  
**OpenAPI spec:** `GET /api/v1/openapi.json`  
**Auth:** `Authorization: Bearer fx_live_...` (create keys at `/dashboard/api-keys`)  
**Default rate limit:** 60 requests/minute per IP

### 13.1 Endpoints

| Method | Endpoint | Credits | Description |
|---|---|---|---|
| `GET` | `/openapi.json` | Free | OpenAPI 3.0 machine-readable spec |
| `GET` | `/tools` | Free | Full tool catalog (`?category=pdf`) |
| `GET` | `/me` | Free | Key info, balance, price list |
| `GET` | `/usage` | Free | Last 100 API calls with credit amounts |
| `POST` | `/chat` | 1 | AI chat completion |
| `POST` | `/summarize` | 1 | Summarize text |
| `POST` | `/translate` | 1 | Translate text |
| `POST` | `/write` | 1 | Generate content from brief |
| `POST` | `/qr` | Free | Generate QR code (PNG/SVG data URL) |
| `POST` | `/hash` | Free | Hash text (MD5/SHA family) |
| `GET` | `/uuid` | Free | Generate UUID v4s (`?count=5`) |

### 13.2 Example: AI Chat

```bash
curl -X POST https://tools.farvixo.com/api/v1/chat \
  -H "Authorization: Bearer fx_live_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{ "role": "user", "content": "Explain PDF compression" }],
    "system": "You are a helpful assistant.",
    "model": "gemini-2.0-flash"
  }'
```

**Success response:**

```json
{
  "success": true,
  "data": {
    "reply": "...",
    "credits": { "spent": 1, "remaining": 99 }
  },
  "error": null,
  "meta": { "requestId": "...", "timestamp": "..." }
}
```

**Error codes:** `401` invalid key · `402` insufficient credits · `429` rate limited · `502` AI failure (credit auto-refunded)

### 13.3 Example: Summarize

```bash
curl -X POST https://tools.farvixo.com/api/v1/summarize \
  -H "Authorization: Bearer fx_live_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Long article text...",
    "length": "medium",
    "language": "English"
  }'
```

### 13.4 Example: Translate

```bash
curl -X POST https://tools.farvixo.com/api/v1/translate \
  -H "Authorization: Bearer fx_live_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello world",
    "to": "Hindi",
    "from": "English"
  }'
```

### 13.5 Example: Write

```bash
curl -X POST https://tools.farvixo.com/api/v1/write \
  -H "Authorization: Bearer fx_live_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "brief": "Write about PDF tools for students",
    "tone": "professional",
    "format": "blog post",
    "words": 300
  }'
```

### 13.6 Example: QR Code

```bash
curl -X POST https://tools.farvixo.com/api/v1/qr \
  -H "Authorization: Bearer fx_live_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "https://tools.farvixo.com",
    "size": 512,
    "format": "png"
  }'
```

### 13.7 Example: Hash

```bash
curl -X POST https://tools.farvixo.com/api/v1/hash \
  -H "Authorization: Bearer fx_live_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "hello",
    "algorithm": "sha256"
  }'
```

### 13.8 Example: UUID

```bash
curl "https://tools.farvixo.com/api/v1/uuid?count=3" \
  -H "Authorization: Bearer fx_live_YOUR_KEY"
```

---

## 14. Admin API

**Base URL:** `https://tools.farvixo.com/api/admin`  
**Auth:** Admin session (Supabase) — roles: `ADMIN`, `SUPER_ADMIN`  
**Login:** `POST /api/admin/login`

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/login` | Admin email/password login |
| `GET` | `/stats` | Dashboard overview stats |
| `GET` | `/system` | System health & config status |
| `GET` | `/profile` | Admin profile |
| `PATCH` | `/profile` | Update admin profile |
| `GET` | `/settings` | Platform settings |
| `PATCH` | `/settings` | Update platform settings |
| `GET` | `/users` | Paginated user list |
| `PATCH` | `/users` | Bulk user actions |
| `GET` | `/users/[id]` | Single user detail |
| `PATCH` | `/users/[id]` | Update user (plan, ban, etc.) |
| `DELETE` | `/users/[id]` | Delete user |
| `POST` | `/users/[id]/actions` | User actions (reset, notify, etc.) |
| `GET` | `/tools` | Tool catalog admin view |
| `PATCH` | `/tools` | Update tool metadata/badges |
| `GET` | `/jobs` | All platform jobs |
| `GET` | `/analytics` | Analytics dashboard data |
| `GET` | `/search` | Search log analytics |
| `GET` | `/newsletter` | Newsletter subscribers |
| `GET` | `/contact` | Contact form messages |
| `PATCH` | `/contact` | Mark messages read/replied |
| `GET` | `/notifications` | Broadcast history |
| `POST` | `/notifications` | Send broadcast notification |
| `GET` | `/credits` | Credit ledger (all users) |
| `POST` | `/credits` | Grant or deduct credits |
| `GET` | `/keys` | All API keys across users |
| `DELETE` | `/keys?id=` | Revoke any user's key |
| `GET` | `/team` | Admin team members |
| `POST` | `/team` | Invite admin team member |
| `GET` | `/audit` | Audit log |
| `GET` | `/reports` | Generated reports |

---

## 15. Authentication

### Providers (Supabase Auth)

| Provider | Status |
|---|---|
| Google OAuth | ✅ |
| GitHub OAuth | ✅ |
| Email + Password | ✅ |
| Magic Link | ✅ |
| Passkeys | Roadmap |

### Auth routes

| Route | Purpose |
|---|---|
| `GET /auth/oauth` | Initiate OAuth flow |
| `GET /auth/callback` | Exchange code for session |
| `GET /login` | Login page |
| `GET /signup` | Signup page |

### Session middleware

Protected paths (Supabase session refresh):

- `/dashboard/*`
- `/admin`, `/admin/*`
- `/login`, `/signup`
- `/` (OAuth code redirect only)

### Plans

| Plan | AI chat | Tool usage | Storage | API |
|---|---|---|---|---|
| FREE | 50 msgs/day | Client-side unlimited | 500 MB | Pay-per-credit |
| PRO | Unlimited | Unlimited | 100 GB | Included credits |
| ENTERPRISE | Unlimited + priority | Unlimited | Custom | Custom |

---

## 16. Cloudflare Workers & R2

### Workers (target architecture)

Offload heavy processing to edge workers:

| Worker route | Purpose |
|---|---|
| `/api/image/*` | Image processing proxy |
| `/api/pdf/*` | PDF processing proxy |
| `/api/ocr/*` | OCR workloads |
| `/api/ai/*` | AI inference routing |
| `/api/weather/*` | Weather enrichment |
| `/api/text/*` | Text utilities |
| `/api/files/*` | Upload/download signed URLs |
| `/api/auth/*` | Auth edge helpers |

> **Current state:** Processing APIs run as Next.js Route Handlers. Workers migration is optional for scale.

### R2 Buckets

| Bucket | Purpose |
|---|---|
| `uploads` | User file uploads |
| `exports` | Processed output files |
| `images` | Image assets & thumbnails |
| `pdf` | PDF documents |
| `videos` | Video files |
| `audio` | Audio files |
| `cache` | Processing cache |
| `temp` | 24h auto-delete temp files |
| `ai` | AI-generated assets |
| `public` | Public CDN assets |
| `private` | Signed-URL-only objects |

**R2 environment variables:**

```env
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=farvixo-files
R2_PUBLIC_URL=
```

> **Current state:** Share links use Supabase Storage (`shares` bucket). R2 migration planned for production scale.

---

## 17. Supabase

### Services used

| Service | Purpose |
|---|---|
| **Auth** | Google, GitHub, Email, Magic Link |
| **PostgreSQL** | Users, jobs, credits, analytics, shares |
| **Storage** | Share link file storage |
| **Realtime** | Enabled (notifications, future job progress) |

### Key tables

| Table | Purpose |
|---|---|
| `profiles` | User plan, role, credits, storage |
| `jobs` | Tool usage history |
| `api_keys` | Developer API keys |
| `credit_ledger` | Credit transactions |
| `notifications` | In-app notifications |
| `shares` | File share metadata |
| `newsletter_subscribers` | Newsletter emails |
| `contact_messages` | Contact form |
| `search_logs` | Search analytics |
| `analytics_events` | Event tracking |
| `subscriptions` | Stripe subscription state |

### Environment variables

See **[§19 Environment Variables](#19-environment-variables)** for the complete list.

Minimum Supabase trio:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

---

## 18. Workers AI

Cloudflare Workers AI capabilities (optional edge offload):

| Capability | Use case |
|---|---|
| Text generation | AI Writer fallback |
| Image generation | AI Image Generator |
| Embeddings | Semantic search |
| Translation | AI Translator |
| Summaries | AI Summarizer |
| OCR | Image/PDF OCR |
| Vision | Image analysis |

**Primary AI in production:** Google Gemini via `GEMINI_API_KEY`  
**Fallbacks:** Groq (`GROQ_API_KEY`), OpenRouter (`OPENROUTER_API_KEY`)

---

## 19. Environment Variables

Complete reference for **every** environment variable used by Farvixo Tools — production, Cloudflare, Supabase, AI, billing, cron, and local dev.

### 19.1 Security rules

| Rule | Detail |
|---|---|
| `NEXT_PUBLIC_*` | Safe for browser — never put secrets here |
| No `NEXT_PUBLIC_` prefix | Server-only — never expose to client bundle |
| Cloudflare Pages | Set secrets in **Settings → Environment variables** (Production + Preview) |
| Local dev | Copy `.env.example` → `.env.local` (git-ignored) |
| Rotation | Rotate `CRON_SECRET`, `STRIPE_WEBHOOK_SECRET`, API keys on compromise |

---

### 19.2 Complete `.env` template (copy-paste)

```env
# ═══════════════════════════════════════════════════════════════════════════════
# FARVIXO TOOLS — FULL ENVIRONMENT VARIABLES
# Production: https://tools.farvixo.com
# ═══════════════════════════════════════════════════════════════════════════════

# ─── App (public) ────────────────────────────────────────────────────────────
NEXT_PUBLIC_APP_URL=https://tools.farvixo.com
NEXT_PUBLIC_APP_NAME=Farvixo Tools

# ─── Supabase — public (browser-safe) ────────────────────────────────────────
NEXT_PUBLIC_SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# ─── Supabase — server only ───────────────────────────────────────────────────
# Required for: newsletter, contact, analytics, search logs, Stripe webhook,
# share uploads, admin panel, API keys, credit ledger
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# ─── Google Gemini AI (primary) ──────────────────────────────────────────────
GEMINI_API_KEY=AIzaSy...
GEMINI_MODEL=gemini-2.0-flash

# ─── Groq (optional AI fallback) — console.groq.com ─────────────────────────
GROQ_API_KEY=gsk_...
GROQ_MODEL=llama-3.3-70b-versatile

# ─── OpenRouter (optional AI fallback) — openrouter.ai ───────────────────────
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_FREE_MODEL=meta-llama/llama-3.3-70b-instruct:free

# ─── OpenAI (optional — future / external integrations) ──────────────────────
OPENAI_API_KEY=sk-...

# ─── Pollinations (optional — premium AI image path) ─────────────────────────
POLLINATIONS_API_KEY=

# ─── Stripe (billing) ────────────────────────────────────────────────────────
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_ID_PRO_MONTHLY=price_...
STRIPE_PRICE_ID_PRO_YEARLY=price_...

# ─── Cron / scheduled jobs ───────────────────────────────────────────────────
# openssl rand -hex 32
# Cloudflare Cron / external scheduler:
#   GET https://tools.farvixo.com/api/cron/cleanup-shares
#   Authorization: Bearer <CRON_SECRET>
CRON_SECRET=

# ─── WeatherAPI.com (optional) — weatherapi.com free tier ────────────────────
WEATHERAPI_KEY=

# ─── Cloudflare Turnstile (bot protection) ───────────────────────────────────
NEXT_PUBLIC_TURNSTILE_SITE_KEY=0x4AAAAAAA...
TURNSTILE_SECRET_KEY=0x4AAAAAAA...

# ─── Cloudflare R2 (object storage — production target) ──────────────────────
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=farvixo-files
R2_PUBLIC_URL=https://files.tools.farvixo.com

# ─── Email (Resend) — transactional + newsletter ─────────────────────────────
RESEND_API_KEY=re_...

# ─── Monitoring & analytics ──────────────────────────────────────────────────
SENTRY_DSN=https://xxxx@sentry.io/xxxx
NEXT_PUBLIC_VERCEL_ANALYTICS_ID=

# ─── Queue / workers (optional — heavy media offload) ──────────────────────────
REDIS_URL=redis://...
PYTHON_WORKER_URL=https://worker.farvixo.internal
PYTHON_WORKER_SECRET=

# ─── Ads (optional — free-tier monetization) ─────────────────────────────────
ADSTERRA_API_KEY=

# ─── Admin bootstrap (local script only — npm run admin:bootstrap) ───────────
# Never commit real values. Used by scripts/bootstrap-admin.mjs only.
ADMIN_EMAIL=admin@farvixo.com
ADMIN_PASSWORD=
ADMIN_NAME=Faruk Mondal
ADMIN_ROLE=SUPER_ADMIN

# ─── Runtime (auto-set by platform — do not set manually) ────────────────────
# NODE_ENV=production
```

---

### 19.3 Master variable table

| Variable | Exposure | Required | Default | Used by |
|---|---|---|---|---|
| `NEXT_PUBLIC_APP_URL` | Public | **Yes** | `https://tools.farvixo.com` | Canonical URLs, OAuth redirects, Stripe success/cancel URLs, share links, OpenAPI base, SEO |
| `NEXT_PUBLIC_APP_NAME` | Public | No | `Farvixo Tools` | Branding / metadata (spec) |
| `NEXT_PUBLIC_SUPABASE_URL` | Public | **Yes** | — | Supabase client, auth, database |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public | **Yes** | — | Supabase client, RLS-scoped queries |
| `SUPABASE_SERVICE_ROLE_KEY` | Server | **Yes** | — | Admin client, webhooks, newsletter, contact, analytics, shares, API keys, credits |
| `GEMINI_API_KEY` | Server | **Yes** | — | `/api/ai/chat`, `/api/v1/chat`, summarize, translate, write |
| `GEMINI_MODEL` | Server | No | `gemini-2.0-flash` | Default Gemini model when client does not specify |
| `GROQ_API_KEY` | Server | No | — | AI chat fallback (Llama 3.3 70B) |
| `GROQ_MODEL` | Server | No | `llama-3.3-70b-versatile` | Groq model id |
| `OPENROUTER_API_KEY` | Server | No | — | AI chat fallback (free models) |
| `OPENROUTER_FREE_MODEL` | Server | No | `meta-llama/llama-3.3-70b-instruct:free` | OpenRouter model id |
| `OPENAI_API_KEY` | Server | No | — | Future integrations / external AI (roadmap) |
| `POLLINATIONS_API_KEY` | Server | No | — | `/api/ai/image-generate` premium Pollinations path |
| `STRIPE_SECRET_KEY` | Server | **Yes** | — | `/api/billing/checkout`, `/api/billing/credits-checkout` |
| `STRIPE_WEBHOOK_SECRET` | Server | **Yes** | — | `/api/billing/webhook` signature verification |
| `STRIPE_PRICE_ID_PRO_MONTHLY` | Server | **Yes** | — | Pro subscription Checkout line item |
| `STRIPE_PRICE_ID_PRO_YEARLY` | Server | No | — | Annual Pro plan (when enabled) |
| `CRON_SECRET` | Server | **Yes** | — | `/api/cron/cleanup-shares` Bearer auth |
| `WEATHERAPI_KEY` | Server | No | — | `/api/weather/enrich` alerts + moon data |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Public | No | — | Login, signup, contact Turnstile widget |
| `TURNSTILE_SECRET_KEY` | Server | No | — | Server-side Turnstile token verification |
| `R2_ACCOUNT_ID` | Server | No | — | Cloudflare R2 S3-compatible API |
| `R2_ACCESS_KEY_ID` | Server | No | — | R2 access key |
| `R2_SECRET_ACCESS_KEY` | Server | No | — | R2 secret key |
| `R2_BUCKET_NAME` | Server | No | `farvixo-files` | Default R2 bucket name |
| `R2_PUBLIC_URL` | Server | No | — | Public CDN URL for R2 objects |
| `RESEND_API_KEY` | Server | No | — | Transactional email (welcome, receipts) |
| `SENTRY_DSN` | Server | No | — | Error tracking (Sentry) |
| `NEXT_PUBLIC_VERCEL_ANALYTICS_ID` | Public | No | — | Vercel / Web Analytics |
| `REDIS_URL` | Server | No | — | BullMQ job queue (heavy processing workers) |
| `PYTHON_WORKER_URL` | Server | No | — | FFmpeg / yt-dlp worker base URL |
| `PYTHON_WORKER_SECRET` | Server | No | — | Worker request authentication |
| `ADSTERRA_API_KEY` | Server | No | — | Publisher API for ad dashboard (`lib/ads`) |
| `ADMIN_EMAIL` | Local script | No | — | `npm run admin:bootstrap` only |
| `ADMIN_PASSWORD` | Local script | No | — | `npm run admin:bootstrap` only |
| `ADMIN_NAME` | Local script | No | `Faruk Mondal` | `npm run admin:bootstrap` only |
| `ADMIN_ROLE` | Local script | No | `SUPER_ADMIN` | `npm run admin:bootstrap` only |
| `NODE_ENV` | System | Auto | `development` | Cookie `secure` flag, build mode |

> **Alias note:** Some docs use `R2_ACCESS_KEY`, `R2_SECRET_KEY`, `R2_BUCKET`, `WEATHER_API_KEY`, or `SUPABASE_SERVICE_ROLE`. The **correct names in this codebase** are `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `WEATHERAPI_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`.

---

### 19.4 Grouped reference

#### App & branding

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_APP_URL` | Production origin. Must match Cloudflare custom domain and Supabase redirect URLs. Example: `https://tools.farvixo.com` |
| `NEXT_PUBLIC_APP_NAME` | Display name in manifests and meta tags |

#### Supabase (auth + database + storage)

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL from Supabase Dashboard → Settings → API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `anon` `public` key — safe in browser, respects RLS |
| `SUPABASE_SERVICE_ROLE_KEY` | `service_role` key — **bypasses RLS**. Server-only. Powers admin ops, webhooks, share storage |

**Supabase Dashboard redirect URLs to add:**

```
https://tools.farvixo.com/auth/callback
https://tools.farvixo.com/**
http://localhost:3000/auth/callback
```

#### AI providers

| Variable | Description |
|---|---|
| `GEMINI_API_KEY` | Primary AI — Google AI Studio / Gemini API. Required for v1 API and most AI tools |
| `GEMINI_MODEL` | Override default model (e.g. `gemini-2.0-flash`, `gemini-1.5-pro`) |
| `GROQ_API_KEY` | Optional fallback when Gemini quota exceeded. Free tier: ~30 req/min |
| `GROQ_MODEL` | Groq model id |
| `OPENROUTER_API_KEY` | Optional second fallback. Free models without credit card |
| `OPENROUTER_FREE_MODEL` | OpenRouter model slug |
| `OPENAI_API_KEY` | Reserved for OpenAI direct integration (roadmap) |
| `POLLINATIONS_API_KEY` | Unlocks `gen.pollinations.ai` premium image endpoint; without it free `image.pollinations.ai` still works |

**Minimum AI config:** at least one of `GEMINI_API_KEY`, `GROQ_API_KEY`, or `OPENROUTER_API_KEY` for `/api/ai/chat`.

#### Stripe billing

| Variable | Description |
|---|---|
| `STRIPE_SECRET_KEY` | Secret key (`sk_live_...` production, `sk_test_...` staging) |
| `STRIPE_WEBHOOK_SECRET` | Signing secret from Stripe Dashboard → Webhooks → endpoint for `https://tools.farvixo.com/api/billing/webhook` |
| `STRIPE_PRICE_ID_PRO_MONTHLY` | Recurring price id for Pro monthly subscription |
| `STRIPE_PRICE_ID_PRO_YEARLY` | Recurring price id for Pro annual (optional) |

**Webhook events to subscribe:** `checkout.session.completed`, `customer.subscription.deleted`

#### Cloudflare

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Turnstile site key (visible in HTML widget) |
| `TURNSTILE_SECRET_KEY` | Turnstile secret for server-side `siteverify` API |
| `R2_ACCOUNT_ID` | Cloudflare account id |
| `R2_ACCESS_KEY_ID` | R2 API token access key |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret |
| `R2_BUCKET_NAME` | Bucket for uploads/exports (default: `farvixo-files`) |
| `R2_PUBLIC_URL` | Custom domain or `r2.dev` public URL for signed/public objects |

**R2 bucket layout (recommended):**

`uploads` · `exports` · `images` · `pdf` · `videos` · `audio` · `cache` · `temp` · `ai` · `public` · `private`

#### Operations & cron

| Variable | Description |
|---|---|
| `CRON_SECRET` | Random 32+ byte hex string. Protects `/api/cron/cleanup-shares` |
| `REDIS_URL` | Redis connection for BullMQ job queue (video/audio workers) |
| `PYTHON_WORKER_URL` | FastAPI worker for ffmpeg / yt-dlp |
| `PYTHON_WORKER_SECRET` | Shared secret between Next.js and Python worker |

#### Third-party services

| Variable | Description |
|---|---|
| `WEATHERAPI_KEY` | WeatherAPI.com key for `/api/weather/enrich`. Tool still works via Open-Meteo without it |
| `RESEND_API_KEY` | Resend.com for transactional email |
| `SENTRY_DSN` | Sentry project DSN for error monitoring |
| `NEXT_PUBLIC_VERCEL_ANALYTICS_ID` | Analytics id if using Vercel Analytics |
| `ADSTERRA_API_KEY` | Adsterra publisher API (optional ads for free tier) |

#### Admin bootstrap (local only)

Run once after fresh Supabase setup:

```bash
ADMIN_EMAIL=you@farvixo.com ADMIN_PASSWORD='secure-pass' npm run admin:bootstrap
```

| Variable | Description |
|---|---|
| `ADMIN_EMAIL` | First super-admin email |
| `ADMIN_PASSWORD` | Initial password (user should change after login) |
| `ADMIN_NAME` | Display name on profile |
| `ADMIN_ROLE` | `SUPER_ADMIN` or `ADMIN` |

---

### 19.5 Environment matrix by deployment

| Variable | Local `.env.local` | Cloudflare Preview | Cloudflare Production |
|---|---|---|---|
| `NEXT_PUBLIC_APP_URL` | `http://localhost:3000` | Preview URL | `https://tools.farvixo.com` |
| `NEXT_PUBLIC_SUPABASE_*` | Dev project or shared | Staging project | Production project |
| `SUPABASE_SERVICE_ROLE_KEY` | Dev key | Staging key | Production key |
| `STRIPE_*` | `sk_test_...` | `sk_test_...` | `sk_live_...` |
| `GEMINI_API_KEY` | Dev key | Dev/shared key | Production key |
| `CRON_SECRET` | Any random string | Unique per env | Unique per env |
| `SENTRY_DSN` | Optional | Staging DSN | Production DSN |

---

### 19.6 Cloudflare Pages — where to set variables

1. **Cloudflare Dashboard** → **Workers & Pages** → your project → **Settings** → **Environment variables**
2. Add each variable for **Production** and **Preview** separately
3. Mark all server secrets as **Encrypted**
4. Redeploy after changing any `NEXT_PUBLIC_*` variable (baked in at build time)

| Setting | Value |
|---|---|
| Framework preset | Next.js |
| Build command | `npm run build` |
| Build output directory | Per `@cloudflare/next-on-pages` adapter or static export |
| Node version | 20+ |
| Environment variables | All variables from §19.2 |

---

### 19.7 Health check — verify env is wired

`GET /api/admin/system` (admin session) returns which services are configured:

```json
{
  "serviceRole": true,
  "gemini": true,
  "stripe": true,
  "appUrl": true,
  "nodeEnv": "production"
}
```

Public health: `GET /api/health` → `{ "status": "ok" }`

---

## 20. Security Headers (Application)

Configured in `next.config.mjs` for all routes:

| Header | Value |
|---|---|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` |
| `X-Frame-Options` | `DENY` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `camera=(), microphone=(self), geolocation=(), payment=()` |
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Embedder-Policy` | `credentialless` |

> CSP is intentionally relaxed — tool engines load WASM from CDNs and call external APIs at runtime.

---

## 21. SEO

| Feature | Implementation |
|---|---|
| Canonical URLs | Per-page `<link rel="canonical">` |
| Sitemap | `/sitemap.xml` (dynamic from `data/tools.ts`) |
| Robots | `/robots.txt` — allow `/`, disallow `/api/`, `/dashboard/`, `/admin/` |
| Open Graph | Per-page OG tags + `/api/og` dynamic images |
| Twitter Cards | `summary_large_image` |
| Schema.org | `Organization`, `WebApplication`, `SoftwareApplication`, `FAQPage`, `BreadcrumbList` |

**Homepage title:** `Farvixo Tools — 139+ Free Online AI & Productivity Tools`

---

## 22. Analytics & Monitoring

| Source | Data |
|---|---|
| Cloudflare Analytics | Visitors, bandwidth, countries, devices |
| `/api/analytics/track` | Custom event taxonomy |
| `/api/stats/public` | Real user & job counts |
| `/api/health` | Uptime monitoring |
| Supabase Logs | Database & auth errors |
| Workers Logs | Edge function errors |
| Sentry (optional) | Error tracking |

**Footer status indicator:** Links to `/status` page (Better Uptime compatible).

---

## 23. Deployment Pipeline

```
GitHub (main branch)
    ↓
Cloudflare Pages (auto-deploy on push)
    ↓
Build: npm run build
    ↓
Global CDN propagation
    ↓
Live at tools.farvixo.com
```

### Post-deploy verification

1. `GET https://tools.farvixo.com/api/health` → `status: ok`
2. Homepage loads with tool grid
3. `GET https://tools.farvixo.com/api/v1/openapi.json` → valid OpenAPI
4. Login flow (Google/GitHub/Email)
5. Stripe webhook test event
6. Cron: `GET /api/cron/cleanup-shares` with `CRON_SECRET`

---

## 24. Project Folder Structure

```
farvixo-tools/
├── app/
│   ├── page.tsx                    # Homepage
│   ├── layout.tsx                  # Root layout
│   ├── globals.css                 # Design tokens
│   ├── tools/                      # Tool pages
│   │   ├── page.tsx
│   │   └── [category]/[tool]/page.tsx
│   ├── dashboard/                  # User dashboard
│   ├── admin/                      # Admin panel
│   ├── api/                        # All API routes (62 endpoints)
│   │   ├── health/
│   │   ├── tools/
│   │   ├── search/
│   │   ├── ai/
│   │   ├── billing/
│   │   ├── v1/                     # Public developer API
│   │   └── admin/                  # Admin API
│   ├── auth/                       # OAuth callbacks
│   ├── blog/
│   └── (legal pages)/
├── components/
│   ├── layout/                     # Header, Footer, Nav
│   ├── homepage/                   # Hero, Stats, ToolGrid
│   ├── tool/                       # Tool runners & uploaders
│   ├── ai/                         # AI Assistant
│   └── admin/
├── data/
│   ├── tools.ts                    # 139+ tool catalog
│   └── categories.ts               # 15 categories
├── lib/
│   ├── engines/                    # Per-tool processing engines
│   ├── supabase/                   # Auth & DB clients
│   ├── gemini/                     # AI providers
│   ├── credits.ts                  # Credit system
│   ├── api-v1.ts                   # Public API plumbing
│   └── rate-limit.ts
├── public/                         # Static assets, logos, manifest
├── supabase/
│   └── schema.sql                  # Database schema
├── docs/
│   └── Farvixo-Cloudflare-Enterprise-Setup.md  # This file
├── middleware.ts                   # Auth session refresh
├── next.config.mjs                 # Security headers
└── package.json
```

---

## 25. Production Checklist

| Item | Status |
|---|---|
| Cloudflare DNS (CNAME → Pages) | ☐ |
| SSL Full (Strict) + TLS 1.3 | ☐ |
| HTTP/3 enabled | ☐ |
| Cache rules configured | ☐ |
| WAF + Bot Protection | ☐ |
| Turnstile on login/signup/contact | ☐ |
| R2 buckets created | ☐ |
| Cloudflare Pages connected to GitHub | ☐ |
| All environment variables set | ☐ |
| Supabase production project + RLS | ☐ |
| Stripe live keys + webhook verified | ☐ |
| `CRON_SECRET` + scheduled cleanup | ☐ |
| `GEMINI_API_KEY` configured | ☐ |
| Security headers verified | ☐ |
| `/api/health` returns 200 | ☐ |
| Sitemap submitted to Google Search Console | ☐ |
| All 139+ tool routes return 200 | ☐ |
| Lighthouse Mobile ≥ 90 | ☐ |
| Legal pages published | ☐ |

---

## 26. Final Goal

**tools.farvixo.com** will be a **world-class AI-powered online tools platform** capable of serving millions of users through Cloudflare's global edge network.

The platform delivers:

- **Enterprise-grade performance** — edge CDN, HTTP/3, Brotli, ISR
- **Enterprise-grade security** — WAF, Turnstile, HSTS, rate limiting, signed URLs
- **Enterprise-grade scalability** — client-side processing, R2 storage, Workers offload
- **Enterprise-grade reliability** — health checks, cron cleanup, Stripe webhooks, Supabase RLS
- **Seamless user experience** — one login, one history, one AI brain across 139+ tools

---

© 2026 Farvixo Technologies Pvt. Ltd. · **Build Beyond.**
