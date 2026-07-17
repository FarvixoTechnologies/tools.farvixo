# Farvixo — Full Supabase Bootstrap (new project)

Project: `bujpwwxanaejfcyuigth`  
Dashboard → **SQL Editor** → Run each file **in order** (one at a time).

## Run order

| # | File | Required |
|---|---|---|
| 1 | `schema.sql` | Yes |
| 2 | `01_missing_admin.sql` | Yes (audit + contact columns) |
| 3 | `06_user_admin.sql` | Yes |
| 4 | `04_shares.sql` | Recommended |
| 5 | `07_notifications.sql` | Optional |
| 6 | `08_production_next_steps.sql` | Yes |
| 7 | `09_architecture_v3_foundation.sql` | Yes |
| 8 | `10_seed_tools_catalog.sql` | Yes |
| 9 | `11_admin_v3_hardening.sql` | Yes (role/plan lock + admin table RLS) |
| 10 | `02_promote_super_admin.sql` | Yes (after you sign up once) |

Or generate one merged file locally:

```bash
node scripts/merge-supabase-bootstrap.mjs
```

→ writes `supabase/FULL_BOOTSTRAP.generated.sql` (still prefer stepwise if errors).

## After SQL

1. Auth → URL Config (see `docs/NEXT_STEPS_BN.md`)
2. Google + GitHub providers ON
3. Cloudflare Pages env = new keys → Redeploy
4. Sign in once → run `02_promote_super_admin.sql`
5. Open https://tools.farvixo.com/admin

## Admin System v3 (code)

Nav + Phase 2 pages: AI · Tickets · Promo · Sessions · Maintenance · Security IPs  
Docs: `docs/ADMIN_SYSTEM_V3.md`

## Done vs remaining

See [`docs/DONE_VS_REMAINING.md`](../docs/DONE_VS_REMAINING.md) — code ✅ · Dashboard/Cloudflare ⬜
