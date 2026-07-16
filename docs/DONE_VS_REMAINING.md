# Farvixo — Done vs Remaining

Last MD scope: Next Steps + Database Architecture v3 + Admin System v3  
Project: `bujpwwxanaejfcyuigth` · https://tools.farvixo.com

---

## ✅ Complete in repo (no more code needed for this scope)

| Item | Where |
|---|---|
| Google / GitHub / Email / Magic Link (Flutter + Next) | `Flutter/lib`, `lib/auth-oauth.ts` |
| Package `com.farvixo.app` + deep link | Android |
| Env templates | `.env.example`, `Flutter/.env` |
| Core + v3 foundation SQL | `supabase/schema.sql` … `09_…` |
| Tools catalog seed | `10_seed_tools_catalog.sql` |
| Merged bootstrap | `FULL_BOOTSTRAP.generated.sql` |
| Admin v3 Phase 1–2 UI + APIs | `/admin/*`, `/api/admin/*` |
| Admin nav | `lib/admin-nav.ts` |
| **API Architecture v3 Phase 1** | `/api/v1/*`, OpenAPI, Swagger `/api/v1/docs` |
| Docs | `NEXT_STEPS_BN`, `DATABASE_ARCHITECTURE_V3`, `ADMIN_SYSTEM_V3`, `API_ARCHITECTURE_V3` |
| Bootstrap guide | `supabase/BOOTSTRAP.md` |

---

## ⬜ Remaining — only you (Dashboard / Cloudflare / test)

এগুলো agent remote apply করতে পারে না (নতুন Supabase প্রজেক্ট MCP-তে নেই)।

1. **Supabase URL Config** — Site URL + Redirect list (`NEXT_STEPS_BN` §1)  
2. **Providers ON** — Google + GitHub  
3. **SMTP** — Resend (`NEXT_STEPS_BN` §3)  
4. **SQL run order** — `BOOTSTRAP.md` (1→8), তারপর signup → `02_promote_super_admin.sql`  
5. **Cloudflare Pages env** — নতুন Supabase keys → Retry deployment  
6. **Manual test** — Flutter + web login, `/admin`, upload/RLS  

---

## ⬜ Explicitly NOT in this “complete” pass (Phase 3+)

Phone OTP · Apple · Passkeys · MFA · Realtime admin monitor · Affiliate finance · KYC UI · Social graph · full pgvector search · Swarm of empty tables from the giant architecture dump · `/api/v1/storage/*` · AI audio/video/embed · `/api/v2`  

এগুলো product feature আসলে পরে। See [`API_ARCHITECTURE_V3.md`](API_ARCHITECTURE_V3.md).

---

## Quick start (তোমার ৩০ মিনিট)

```
1. SQL Editor → schema → 01 → 06 → 04 → 08 → 09 → 10
2. Auth URL + Google/GitHub ON
3. Cloudflare env + Redeploy
4. Sign up farukmondal106@gmail.com → run 02_promote → /admin
5. (Optional) Resend SMTP → Magic Link test
```
