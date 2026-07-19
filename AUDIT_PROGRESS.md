# Farvixo Tools — Enterprise Audit Progress

> **Single source of truth for the audit.**
> On any restart or new session: **READ THIS FILE FIRST** and continue from the last checkpoint below.
> **Never restart the audit from the beginning while this file exists.**
> Rule in effect: no source file is edited until the owner explicitly says **APPROVE**.
> This file is updated automatically after every completed step.

**Last updated:** 2026-07-19
**Overall status:** In progress — repository scan complete. P0 #1 fixed. Awaiting P0 #2.

---

## ▶ Current checkpoint (resume here)
- Repository overview: **COMPLETE** (do not rescan).
- Last completed step: **P1 #3 fixed** (durable daily limiter for AI chat quota/credit gating).
- Next action: await owner's next instruction / next issue.
- Open residuals: (1) revoke leaked Supabase token `sbp_a709…`; (2) revoke App Check debug token `3F7A6C97-…` (Firebase Console) + remove from `.env.example:58`; (3) apply migration `20260719000000_restrict_profiles_update_columns.sql`; (4) apply migration `20260719010000_rate_counters.sql` + set `RATE_LIMIT_SECRET` in Cloudflare Pages env; (5) apply migration `20260719020000_share_download_claim.sql` before deploying the share route change.

---

## Severity legend
- **P0** Critical — security, data loss, auth/billing integrity, production-breaking.
- **P1** High — correctness bugs, broken flows, missing validation.
- **P2** Medium — reliability, performance, maintainability.
- **P3** Low — style, minor cleanups.

---

## Findings & fixes

### P0 — Critical

#### P0 #1 — Live Supabase Personal Access Token stored in plaintext
- **Severity:** P0
- **File:** `C:\Users\Faruk\Farvixo\.mcp.json` (line 11)
- **Found:** 2026-07-19
- **Finding:** Hardcoded `SUPABASE_ACCESS_TOKEN` (`sbp_a709…`) committed in plaintext.
- **Verification (2026-07-19):**
  - OS env var `SUPABASE_ACCESS_TOKEN` exists (length 44, prefix `sbp_20ac`).
  - Hardcoded token (`sbp_a709…`) differs from env-var token (`sbp_20ac…`).
  - Live rotation status not confirmed via Supabase check.
- **Approved fix (2026-07-19):** Replaced hardcoded value with `${SUPABASE_ACCESS_TOKEN}`.
  ```diff
  -        "SUPABASE_ACCESS_TOKEN": "sbp_[REDACTED]"
  +        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
  ```
- **Status:** FIXED (2026-07-19).
- **Residual (owner action, OPEN):** Revoke the leaked token in Supabase dashboard — may still exist in older git history/session.

#### P0 #2 — Privilege escalation via unrestricted `profiles` self-update (RLS)
- **Severity:** P0
- **Files:**
  - `C:\Users\Faruk\Farvixo\supabase\schema.sql` (after `profiles_update_own` policy)
  - `C:\Users\Faruk\Farvixo\supabase\migrations\20260719000000_restrict_profiles_update_columns.sql` (new migration)
- **Found:** 2026-07-19
- **Finding:** `profiles_update_own` RLS policy allows updating one's own row with no column restriction; `profiles` holds `role`/`plan`. Any authenticated user could PATCH `profiles` (anon key + own JWT) to `role='SUPER_ADMIN'`/`plan='ENTERPRISE'` → RBAC + billing bypass.
- **Deeper review (RLS/DB):** Audited every profile UPDATE. Only session/anon writes: `account/settings:162`, `v1/users/me:69`, `auth/callback:57`, Flutter `profile_service:27,63` — all limited to `full_name`, `avatar_url`, `updated_at`. All role/plan/stripe writes use `service_role`.
- **Approved fix (2026-07-19):** Kept RLS policy; added `revoke update ... from anon, authenticated;` + `grant update (full_name, avatar_url, updated_at) ... to authenticated;`. INSERT/DELETE/SELECT, RPCs, service_role untouched. Corrected allowlist to include `updated_at`.
- **Verification (2026-07-19, static):** All user flows use granted columns; role/plan/stripe_*/tools_used_today blocked. No client-updatable column outside allowlist.
- **Status:** FIXED in schema + migration (2026-07-19).
- **Residual (owner action, OPEN):** Apply migration `20260719000000_...` to the live Supabase project (schema edit does not affect prod until migrated).

### P1 — High

#### P1 #1 — App Check debug token committed in non-git-ignored production env file
- **Severity:** P1
- **Files:**
  - `C:\Users\Faruk\Farvixo\.env.production` (removed debug token, was line 20)
  - `C:\Users\Faruk\Farvixo\.gitignore` (added `.env.production` + `.env.production.*`)
- **Found:** 2026-07-19
- **Finding:** `NEXT_PUBLIC_FIREBASE_APPCHECK_DEBUG_TOKEN` committed and client-bundled (App Check bypass); `.gitignore` did not ignore `.env.production`.
- **Approved fix (2026-07-19):**
  - Removed the debug token line from `.env.production` (replaced with a warning comment).
  - Added `.env.production` and `.env.production.*` to `.gitignore`.
- **Verification (2026-07-19):**
  - `grep APPCHECK_DEBUG_TOKEN .env.production` → 0 matches (removed).
  - `git check-ignore .env.production` → ignored.
  - Only `.gitignore` + `.env.production` modified by this fix (other diff entries are pre-existing session changes).
- **Status:** FIXED (2026-07-19).
- **Residual (owner action, OPEN):** Revoke/delete the exposed debug token `3F7A6C97-…` in Firebase Console → App Check → Manage debug tokens; if `.env.production` was already committed, purge with `git rm --cached .env.production`. RESOLVED 2026-07-19: `.env.example` debug token replaced with placeholder `your_appcheck_debug_token_here`. Verified no real secrets remain in `.env.example` (only `NEXT_PUBLIC_FIREBASE_API_KEY`, public-by-design). Firebase Console token still needs revoking by owner.

#### P1 #2 — Anonymous AI image-generation quota bypass (in-memory limiter on Cloudflare)
- **Severity:** P1
- **Files:**
  - `app/api/ai/image-generate/route.ts` (durable limiter + salted IP hash)
  - `supabase/migrations/20260719010000_rate_counters.sql` (new table + `incr_rate_counter` RPC)
  - `.env.example` (documented `RATE_LIMIT_SECRET`)
- **Found:** 2026-07-19
- **Finding:** Daily free cap enforced by in-memory `rateLimit()` (per-isolate, resets); `checkQuota` returns `allowed` for anonymous (`engine.ts:119`). On Cloudflare Pages (many isolates), anonymous callers bypass the daily cap → abuse of external image API + paid Pollinations key.
- **Deployment verified:** No CF KV / Durable Objects / wrangler config in repo; Supabase is the existing durable store. Chose Supabase counter (zero new infra).
- **Approved fix (2026-07-19):** Added `rate_counters` table + atomic `incr_rate_counter(bucket, identity, window)` SECURITY DEFINER RPC (search_path pinned, execute revoked from anon/authenticated). Anonymous requests hashed as `SHA256(ip + RATE_LIMIT_SECRET)` → RPC → deny when `count > DAILY_LIMIT`. Missing `RATE_LIMIT_SECRET` → 500 config error (no unsalted fallback). RPC returns count only (no `p_limit`); API does the comparison. Signed-in users unchanged (`checkQuota`). Removed unused `DAY_MS`.
- **Verification (2026-07-19):** Typecheck clean for the route. Durable across isolates via Supabase; authenticated path untouched.
- **Status:** FIXED in code + migration (2026-07-19).
- **Residual (owner action, OPEN):** Apply migration `20260719010000_rate_counters.sql` to live Supabase; set `RATE_LIMIT_SECRET` in Cloudflare Pages env (Production + Preview).

### P1 #3 — AI chat daily-quota & credit-charging bypass via in-memory limiter
- **Severity:** P1 (upgraded from P2 #3 after tracing `resolveChain`)
- **File:** `app/api/ai/chat/route.ts` (lines 81–128)
- **Found:** 2026-07-19
- **Finding:** Non-Pro daily cap (50/day) enforced by in-memory `rateLimit()` — per-Cloudflare-isolate, resets. `checkQuota` is a no-op for anonymous and when no `ai_quotas` rows exist. Credit charge only triggered after the broken counter → free/anon users exceed 50/day unmetered.
- **Paid-provider trace (`lib/ai/router.ts`):** `resolveChain` selects providers purely from DB (gemini/openai/anthropic/groq/openrouter/ollama), Vault-key-first then env (`OPENAI_API_KEY`/`ANTHROPIC_API_KEY`). Route applies no free-only restriction to anon/free users → **real paid-upstream cost bypass possible** ⇒ High.
- **Approved fix (2026-07-19):** Replaced in-memory `ai:daily` with durable `incr_rate_counter('ai:daily', identity)` (reused P1 #2 table/RPC — no new migration). Identity = `user:<id>` or `ip:SHA256(ip+RATE_LIMIT_SECRET)`. Credits charged only when `count > FREE_DAILY_LIMIT`; anon fallback preserved. Burst limiter unchanged. Removed unused `DAY_MS`.
- **Verification (2026-07-19):** Typecheck clean. Counter increments once/request; quota decision precedes `resolveChain`/`streamChat`/`streamWithFallback` (all providers gated); Pro/Enterprise bypass unchanged; Flutter (bearer) + Web (cookie) auth paths intact.
- **Status:** FIXED in code (2026-07-19). No migration needed (reuses `20260719010000_rate_counters.sql`).
- **Residual:** requires `RATE_LIMIT_SECRET` set in Cloudflare Pages env (already tracked under P1 #2).

### P2 — Medium

#### P2 #1 — Open redirect via unvalidated Stripe checkout success/cancel URLs
- **Severity:** P2
- **File:** `C:\Users\Faruk\Farvixo\app\api\billing\checkout\route.ts`
- **Found:** 2026-07-19
- **Finding:** `successUrl`/`cancelUrl` from request body forwarded to Stripe `success_url`/`cancel_url` with no origin validation → open redirect anchored to a trusted Stripe page (phishing aid).
- **Deeper review (payments):** Verified both clients only ever send the web origin —
  - Flutter `settings_capability_services.dart:47–50` sends `https://tools.farvixo.com/dashboard/billing?checkout=success|cancelled`.
  - Web `dashboard/billing/page.tsx:33` sends no body (server default).
  - Only custom scheme `com.farvixo.app://login-callback` (`app_config.dart:17`) is auth-only, not billing. iOS registers no custom scheme.
  - Allowlist: `https://tools.farvixo.com` (+ request-origin fallback). No custom schemes needed → strict same-origin is safe.
- **Approved fix (2026-07-19):** Added `sameOrigin()` helper (with open-redirect comment); validate both URLs; keep default fallbacks; warn on rejection without logging the URL. No payment/Stripe/auth/pricing/webhook/session logic changed.
- **Verification (2026-07-19):** Flutter URLs ACCEPT; web no-body → default; external/custom-scheme/protocol-relative REJECT→default; same-origin ACCEPT; typecheck clean.
- **Status:** FIXED (2026-07-19).

#### P2 #2 — Share download-limit / one-time-link bypass (TOCTOU race)
- **Severity:** P2
- **Files:**
  - `app/api/share/[token]/route.ts` (atomic claim + compensating release)
  - `supabase/migrations/20260719020000_share_download_claim.sql` (new RPCs)
- **Found:** 2026-07-19
- **Finding:** Download limit read `downloads` then wrote `downloads+1` non-atomically → concurrent requests over-download one-time / limited links.
- **Note:** File-upload area otherwise clean — stored-XSS mitigated (signed URL on `*.supabase.co`, `Content-Disposition: attachment`); auth/size/filename/128-bit token all sound.
- **Approved fix (2026-07-19):** Added `claim_share_download(p_token)` (atomic `UPDATE … WHERE unexpired AND downloads<max_downloads RETURNING`) + `release_share_download(p_token)` compensating decrement; both SECURITY DEFINER, `search_path=public`, execute revoked from public/anon/authenticated. Route now claims a slot before signing and releases it if signing fails. Removed the old non-atomic check + `downloads++`.
- **Verification (2026-07-19):** Typecheck clean. metaOnly returns before claim; expiry re-checked in RPC; password/expiry/signed-URL logic preserved; no permanent slot loss on sign failure.
- **Status:** FIXED in code + migration (2026-07-19).
- **Residual (owner action, OPEN):** Apply migration `20260719020000_share_download_claim.sql` to live Supabase (before deploying the route change).

### P3 — Low
_None recorded yet._

---

## Skipped / deferred issues
_None recorded yet._

---

## Remaining tasks
- [ ] Receive and process **P0 Issue #2** (and any further findings from the completed scan).
- [ ] Owner: revoke leaked Supabase token `sbp_a709…`.
- [ ] Owner: confirm env-var token `sbp_20ac…` is valid; restart MCP server/session to pick up env value.

---

## Changelog
- 2026-07-19 — Created audit tracker; repository overview marked complete.
- 2026-07-19 — P0 #1 logged (OPEN) after verifying env var + token mismatch.
- 2026-07-19 — P0 #1 fix applied to `.mcp.json`; status → FIXED.
- 2026-07-19 — Tracker expanded to full schema (findings, approved fixes, skipped, progress, remaining, paths, severity, timestamps).
