# Farvixo - Next Steps Checklist

Project: `bujpwwxanaejfcyuigth` | App: https://tools.farvixo.com | Host: Cloudflare Pages

Full Bangla+EN status: see `docs/DONE_VS_REMAINING.md`
API v3: `docs/API_ARCHITECTURE_V3.md` | DB v3: `docs/DATABASE_ARCHITECTURE_V3.md` | Admin v3: `docs/ADMIN_SYSTEM_V3.md`

---

## Status summary

| Area | Code/SQL | Your action |
|---|---|---|
| Google / GitHub OAuth | READY | Dashboard Providers ON + Redirect URLs |
| Email + Magic Link | READY | SMTP (Resend) for delivery |
| Database + Storage + RLS | SQL files ready | Run in SQL Editor |
| Tools catalog seed | 10_seed ready | Run SQL |
| Admin System v3 Phase 1-2 | READY | SUPER_ADMIN promote + login |
| API Architecture v3 Phase 1 | /api/v1 ready | Open /api/v1/docs after deploy |
| Cloudflare deploy | builds for Pages | env = new keys + Redeploy |
| Testing | - | device/browser check |

---

## 1. URL Configuration (Dashboard)

Supabase -> Authentication -> URL Configuration

| Field | Value |
|---|---|
| Site URL | `https://tools.farvixo.com` |

Redirect URLs (one per line):

```
https://tools.farvixo.com/**
https://farvixo.com/**
https://www.farvixo.com/**
http://localhost:3000/**
com.farvixo.app://login-callback
com.farvixo.app://login-callback/**
```

---

## 2. OAuth (code READY - Dashboard ON needed)

- Google Client ID/Secret -> Authentication -> Providers -> Google -> Enable
- GitHub Client ID/Secret -> Providers -> GitHub -> Enable
- Callback: `https://bujpwwxanaejfcyuigth.supabase.co/auth/v1/callback`

Android package: `com.farvixo.app`
Debug SHA-1: `02:80:49:D2:B9:07:7D:6D:63:67:EF:F5:E4:01:21:F5:C4:FD:40:9E`

---

## 3. SMTP (manual - for Magic Link / verify email)

Project Settings -> Authentication -> SMTP | Recommended: Resend

| Field | Example |
|---|---|
| Host | `smtp.resend.com` |
| Port | `465` or `587` |
| Username | `resend` |
| Password | Resend API key |
| Sender name | `Farvixo` |
| Sender email | `noreply@farvixo.com` |

Verify `farvixo.com` domain in Resend DNS.

---

## 4-6. Database + Storage + RLS

See `supabase/BOOTSTRAP.md` - run in order:

1. schema.sql
2. 01_missing_admin.sql
3. 06_user_admin.sql
4. 04_shares.sql (recommended)
5. 07_notifications.sql (optional)
6. 08_production_next_steps.sql
7. 09_architecture_v3_foundation.sql
8. 10_seed_tools_catalog.sql
9. 02_promote_super_admin.sql (AFTER signup: farukmondal106@gmail.com)

Or: `node scripts/merge-supabase-bootstrap.mjs` -> FULL_BOOTSTRAP.generated.sql

New project is NOT in MCP - SQL only via Dashboard SQL Editor.

Storage path: `{user_id}/filename.ext`

---

## 7. Testing (manual)

Flutter: Google, GitHub, Email, Magic Link, Logout, deep link
Next.js: OAuth/Email, session, logout, /admin
Backend: JWT on APIs, storage own-folder, RLS isolation

---

## 8. Cloudflare Pages

Workers & Pages -> Settings -> Environment variables (Production + Preview):

| Variable | Value |
|---|---|
| NEXT_PUBLIC_SUPABASE_URL | https://bujpwwxanaejfcyuigth.supabase.co |
| NEXT_PUBLIC_SUPABASE_ANON_KEY | anon JWT from .env.local |
| SUPABASE_SERVICE_ROLE_KEY | service_role (Encrypt) |
| NEXT_PUBLIC_APP_URL | https://tools.farvixo.com |
| GEMINI_API_KEY | if used |

Then Deployments -> Retry deployment.

Guide: Farvixo-Cloudflare-Enterprise-Setup.md

API docs after deploy: https://tools.farvixo.com/api/v1/docs
