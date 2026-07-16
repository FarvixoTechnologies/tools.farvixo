# Farvixo Admin System v3.0

Enterprise Admin · Multi Role · AI Ready · Future Proof  
App: `/admin` · Host: Cloudflare Pages · DB: Supabase (`bujpwwxanaejfcyuigth`)

---

## Principle

Same as Database v3: **ship working surfaces first**. Nav lists only routes that have pages + APIs. Empty shells are not shipped.

---

## Gap matrix (code-ready)

| v3 Module | Status | Route / API |
|---|---|---|
| **Core Dashboard** | ✅ | `/admin`, `/admin/analytics`, `/admin/reports`, `/admin/system`, `/admin/maintenance` |
| Live / Realtime Monitor | ⬜ Phase 3 | Realtime on `jobs`, `notifications` |
| **User Management** | ✅ | `/admin/users`, `/admin/users/[id]`, `/admin/sessions`, `/admin/team`, `/admin/create-admin` |
| KYC / Verification UI | ⬜ Phase 3 | DB: `verification` (09) |
| **AI Management** | ✅ | `/admin/ai` → `/api/admin/ai` |
| **Tool Management** | ✅ | `/admin/tools`, `/admin/categories`, `/admin/jobs`, `/admin/files` |
| Reviews / Trending admin | ⬜ Phase 3 | DB: `tool_reviews`, `tool_usage` |
| **Content** | ✅ | blog, notifications, ads, email-templates, newsletter |
| Banners / FAQs / Pages CMS | ⬜ Phase 3 | |
| **Subscription & Finance** | ✅ | subscriptions, pricing, credits, **promo**, api-keys |
| Refunds UI | ⬜ Phase 3 | Stripe + `transactions` |
| **Storage** | ✅ | `/admin/files` |
| **Support** | ✅ | `/admin/tickets`, `/admin/contact` |
| **Security** | ✅ | `/admin/security` (blocked IPs), audit, search, api-keys, team |
| **Monitoring** | ✅ | system, jobs |
| Cron / Queue UI | ⬜ Phase 3 | |
| **Remote Config** | ✅ | features, settings, maintenance |
| **Developer** | ✅ | api-keys, system env |
| Swagger / Webhooks UI | ⬜ Phase 3 | |
| **Audit** | ✅ | `/admin/audit` |
| **Enterprise** | Partial | roles on `profiles`; workspace admin Phase 3 |

---

## Phase roadmap

### Phase 1 — Harden what ships ✅
1. Admin nav → v3 section titles (`lib/admin-nav.ts`)  
2. SQL order: see `supabase/BOOTSTRAP.md`  
3. Cloudflare Pages env = new Supabase keys  
4. Promote first SUPER_ADMIN after signup  

### Phase 2 — High value gaps ✅ (code)
| Page | API | Tables |
|---|---|---|
| `/admin/ai` | `/api/admin/ai` | `ai_usage`, `ai_providers`, `ai_models` |
| `/admin/tickets` | `/api/admin/tickets` | `tickets`, `ticket_messages` |
| `/admin/promo` | `/api/admin/promo` | `promo_codes` |
| `/admin/security` | `/api/admin/security` | `blocked_ips`, `failed_logins` |
| `/admin/maintenance` | `/api/admin/maintenance` | `maintenance`, feature flags |
| `/admin/sessions` | `/api/admin/sessions` | `user_sessions`, `devices`, `login_history` |

> Pages show a “run 09 SQL” notice if tables are missing — UI is ready before/after migrate.

### Phase 3 — Enterprise
Realtime dashboard · Multi-tenant org admin · CSV/PDF exporters expanded · Backup/restore UI · A/B experiments · Affiliate finance · KYC UI

---

## RBAC (current)

| Role | Access |
|---|---|
| `USER` | No `/admin` |
| `ADMIN` | Admin panel (non–super actions) |
| `SUPER_ADMIN` | Full + create admins, settings |

Policy: `lib/admin-auth.ts` + `profiles.role`. Service role = server APIs only.

---

## Nav

See [`lib/admin-nav.ts`](../lib/admin-nav.ts).

---

## Production checklist

| Item | Status |
|---|---|
| Dashboard + Analytics + Reports | ✅ |
| Users ban/suspend/role | ✅ |
| Sessions & devices | ✅ |
| Tools / Categories / Jobs | ✅ |
| Credits / Subscriptions / Pricing / Promo | ✅ |
| AI admin console | ✅ |
| Tickets console | ✅ |
| Maintenance mode | ✅ |
| Blocked IPs | ✅ |
| Audit + Team + Feature flags | ✅ |
| Contact inbox | ✅ |
| Realtime monitor | ⬜ Phase 3 |
| Finance / Affiliate | ⬜ Phase 3 |
| DB SQL applied on new project | ⬜ Dashboard (manual) |
| SUPER_ADMIN promoted | ⬜ After first signup |
| Cloudflare env + redeploy | ⬜ Manual |
