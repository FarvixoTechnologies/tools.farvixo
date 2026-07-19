# Settings Backend Wiring

Flutter Settings calls the Farvixo Tools Next.js API with the signed-in Supabase access token (`Authorization: Bearer`).

## Flutter env (`Flutter/.env`)

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Auth session + RLS tables (`user_settings`, …) |
| `API_BASE_URL` | Base URL ending in `/api` (default `https://tools.farvixo.com/api`) |

## Server env (Next.js / Vercel)

| Variable | Purpose |
|---|---|
| `STRIPE_SECRET_KEY` | Checkout + billing configured probe |
| `STRIPE_PRICE_ID_PRO_MONTHLY` | Pro subscription price |
| `STRIPE_WEBHOOK_SECRET` | Webhook signature verification |
| `NEXT_PUBLIC_SUPABASE_*` / `SUPABASE_SERVICE_ROLE_KEY` | Auth + account delete |

## Endpoints used by Settings

| Method | Path | Feature |
|---|---|---|
| `GET` | `/billing/status` | Plan, credits, renew date, `billingConfigured` |
| `POST` | `/billing/checkout` | Stripe Checkout URL |
| `GET` | `/account/export` | GDPR JSON export |
| `POST` | `/account/delete` | Account deletion |
| `GET` | `/account/identities` | Linked OAuth providers |
| `PATCH` | `/account/settings` | Email / marketing prefs (web `settings` table) |

Password change uses Supabase Auth `updateUser(password:)` locally (no API).

## Still deferred

- MFA / 2FA
- SMS alerts and Quiet Hours (no delivery provider)
- Microsoft / Discord / LinkedIn linking
