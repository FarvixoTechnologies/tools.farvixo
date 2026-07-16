# Farvixo API Architecture v3.0

REST · JSON · HTTPS · JWT · `/api/v1` · OpenAPI · Rate Limit · Pagination  
Host: Cloudflare Pages · Auth: Supabase JWT + API keys (`fx_live_…`)

---

## Principle

Ship **working `/api/v1` surfaces** first. Do not reimplement Supabase Auth as custom `/auth/signup` servers when the client SDK already owns sessions. Version path is `/api/v1`; legacy `/api/*` stays for the web app.

---

## Standards (shipped)

| Standard | Status | Notes |
|---|---|---|
| REST + JSON + HTTPS | ✅ | Next.js route handlers |
| Versioning `/api/v1` | ✅ | `/api/v2` reserved (not created) |
| JWT (session cookie) | ✅ | `requireSession` — browser apps |
| API Keys | ✅ | `requireApiKey` — `Authorization: Bearer fx_live_…` |
| Rate limiting | ✅ | `lib/rate-limit.ts` (IP buckets) |
| Pagination / sort helpers | ✅ | `parsePagination`, `parseSort` in `lib/api-v1.ts` |
| OpenAPI 3 | ✅ | `GET /api/v1/openapi.json` |
| Swagger UI | ✅ | `GET /api/v1/docs` |
| Envelope + structured errors | ✅ | `lib/api-response.ts` (`message`, `errorDetail`) |
| RLS | ✅ | Supabase policies on user tables |
| RBAC / Audit | ✅ | Admin APIs + `admin_audit_log` |
| Webhooks / Queue | Partial | Stripe webhook · BullMQ Phase 2 |
| Helmet | Partial | Security headers via platform / Cloudflare |

---

## Response envelope

```json
{
  "success": true,
  "message": "",
  "data": {},
  "error": null,
  "errorDetail": null,
  "meta": { "requestId": "uuid", "timestamp": "iso", "page": 1, "pageSize": 25, "total": 100 }
}
```

Error:

```json
{
  "success": false,
  "message": "…",
  "data": null,
  "error": "…",
  "errorDetail": { "code": "UNAUTHORIZED", "message": "…" },
  "meta": { "requestId": "uuid", "timestamp": "iso", "code": "UNAUTHORIZED" }
}
```

`error` string kept for older clients (`adminFetch`).

---

## Auth model (important)

| Spec path | Farvixo reality |
|---|---|
| `POST /auth/signup\|login\|google\|github\|magic-link` | **Supabase Auth client** (Next `lib/auth-oauth.ts`, Flutter `signInWithOAuth` / `signInWithOtp`) — not duplicated as custom REST |
| `POST /auth/logout\|refresh\|verify` | Supabase SDK |
| `POST /auth/apple` | ⬜ Phase 2 |
| `GET /auth/me` | ✅ `GET /api/v1/auth/me` (session) |

Docs + redirect URLs: [`NEXT_STEPS_BN.md`](NEXT_STEPS_BN.md).

---

## Gap matrix → `/api/v1`

| Spec | Status | Route |
|---|---|---|
| **Auth me** | ✅ | `/api/v1/auth/me` |
| **Users me** GET/PATCH | ✅ | `/api/v1/users/me` |
| Users delete | Partial | `501` → use `/api/account/delete` |
| Users devices | ⬜ Phase 2 | DB: `devices` (08) · admin has `/admin/sessions` |
| Avatar upload | ⬜ Phase 2 | Storage `avatars` bucket |
| **AI chat** | ✅ | `/api/v1/ai/chat` (+ `/api/v1/chat`) |
| AI image/audio/video/embed | Partial / ⬜ | image: `/api/ai/image-generate`; audio/video/embed Phase 2 |
| AI history | ⬜ Phase 2 | `ai_conversations` (09) |
| **Tools list** | ✅ | `/api/v1/tools` |
| **Tools categories** | ✅ | `/api/v1/tools/categories` |
| **Tools :id** | ✅ | `/api/v1/tools/[id]` |
| **Tools search** | ✅ | `/api/v1/tools/search?q=` |
| **Tools favorite** | ✅ | `/api/v1/tools/favorite` |
| Tools recent | ⬜ Phase 2 | `history` table |
| Storage upload/signed-url | Partial | app upload flows; dedicated v1 routes Phase 2 |
| **Plans** | ✅ | `/api/v1/plans` |
| Subscribe / cancel | Partial | `/api/billing/checkout` (+ Stripe portal later) |
| **Wallet / credits** | ✅ | `/api/v1/wallet`, `/api/v1/credits` |
| **Notifications** | ✅ | `/api/v1/notifications` |
| Admin dashboard/users/… | ✅ | Existing `/api/admin/*` (not under v1 prefix — RBAC gated) |
| Status | ✅ | `/api/v1/status` |
| Docs | ✅ | `/api/v1/docs` · OpenAPI |

Developer utilities already on v1: `chat`, `summarize`, `translate`, `write`, `qr`, `hash`, `uuid`, `me` (API key), `usage`.

---

## Phase roadmap

### Phase 1 — Foundation ✅ (this pass)
- Envelope v3 · pagination helpers · session + API key auth  
- Core user/tools/plans/wallet/credits/notifications routes  
- OpenAPI + Swagger UI · AI chat alias  

### Phase 2
- `/api/v1/storage/*` signed upload/download  
- `/api/v1/tools/recent` · devices · subscription cancel/status  
- AI history · image/audio/video/embed under `/api/v1/ai/*`  
- Apple auth · webhook verification UI  

### Phase 3
- `/api/v2` when breaking changes needed  
- Redis global rate limits · queue visibility · OpenAPI codegen clients  

---

## Quick links

| | |
|---|---|
| Swagger | https://tools.farvixo.com/api/v1/docs |
| OpenAPI | https://tools.farvixo.com/api/v1/openapi.json |
| Status | https://tools.farvixo.com/api/v1/status |
| API keys UI | `/dashboard/api-keys` |

---

## Security checklist

- [x] JWT session for user routes  
- [x] API keys for public developer API  
- [x] Rate limit on v1 gates  
- [x] Input size caps on AI routes  
- [x] RLS on user data tables (SQL)  
- [x] Admin RBAC separate from v1  
- [ ] Global Redis rate limit (Phase 2)  
- [ ] Dedicated Helmet middleware package (Cloudflare WAF covers edge)  
