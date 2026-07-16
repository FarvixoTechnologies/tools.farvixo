# Farvixo Database Architecture v3.0

Enterprise · AI Native · Multi Platform · Offline First · Future Proof  
**Stack:** Supabase PostgreSQL 17 · UUID · JSONB · Realtime · Storage · RLS · Extensions

---

## Principle

v3 is a **phased blueprint**. Production ships **Phase 1 foundation** now; remaining domains land when product features need them. Do **not** create 150 empty tables day one.

---

## Apply order (new project `bujpwwxanaejfcyuigth`)

Canonical list: [`supabase/BOOTSTRAP.md`](../supabase/BOOTSTRAP.md)

| Step | File | What |
|---|---|---|
| 1 | [`schema.sql`](../supabase/schema.sql) | Core: profiles, jobs, credits ledger, notifications, analytics, api_keys |
| 2 | [`01_missing_admin.sql`](../supabase/01_missing_admin.sql) | Audit / contact / admin gaps |
| 3 | [`06_user_admin.sql`](../supabase/06_user_admin.sql) | Admin profile columns |
| 4 | [`04_shares.sql`](../supabase/04_shares.sql) | Shares + `shares` bucket |
| 5 | [`07_notifications.sql`](../supabase/07_notifications.sql) | Broadcasts (optional) |
| 6 | [`08_production_next_steps.sql`](../supabase/08_production_next_steps.sql) | wallet, subscriptions, favorites, history, settings, devices, sessions, buckets |
| 7 | [`09_architecture_v3_foundation.sql`](../supabase/09_architecture_v3_foundation.sql) | **v3 Phase 1** — extensions, AI, workspace, tools schema, offline, security, views |
| 8 | [`10_seed_tools_catalog.sql`](../supabase/10_seed_tools_catalog.sql) | Catalog seed — `node scripts/generate-tools-seed.mjs` |
| 9 | [`02_promote_super_admin.sql`](../supabase/02_promote_super_admin.sql) | After first signup |

Dashboard → **SQL Editor** → paste → Run (each file once).

---

## Map: Spec domain → Current status

| Domain | Status | Notes |
|---|---|---|
| User System | Partial → Phase 1 | `profiles` + 08 settings/devices/sessions + 09 prefs/socials/login_history/… |
| Auth | App-layer | Google/GitHub/Email/Magic Link wired; Phone/Apple/Passkeys/MFA later |
| AI System | Phase 1 core | providers, models, conversations, messages, usage, feedback, embeddings scaffold |
| Workspace | Phase 1 scaffold | workspaces, members, folders, tags, notes, bookmarks, recent |
| Tools | Phase 1 + seed later | `tools`, `tool_categories`, usage, reviews (sync from `data/tools.ts`) |
| Payments | Phase 1 | plans, transactions, promo, invoices + existing wallet/credits/subscriptions |
| Storage | Phase 1 | buckets in 08+09; `storage_files` metadata table |
| Notifications | Done + prefs | notifications + preferences + push_tokens |
| Search | Phase 1 | search_history, saved_searches (cache/index = Phase 2) |
| Analytics | Done | analytics_events, admin_audit_log |
| Security | Phase 1 | failed_logins, blocked_ips, security_events |
| Social | Phase 2 | followers/friends/comments — not in foundation |
| Support | Phase 1 | tickets, ticket_messages (+ existing contact_messages) |
| Remote Config | Phase 1 | feature_flags, remote_config, maintenance |
| Admin | Existing | admin_settings, audit, broadcasts |
| API | Partial | api_keys + webhooks + background_tasks + jobs |
| Offline Sync | Phase 1 | offline_queue, sync_logs |
| Realtime | Config | Enable Realtime on tables in Dashboard as needed |
| Extensions | Phase 1 | uuid-ossp, pgcrypto, pg_trgm, unaccent, btree_*, pg_stat_statements · pgvector/PostGIS/pg_net optional |
| Views | Phase 1 | user_dashboard, wallet_summary, ai_usage_summary · materialized = Phase 2 |

---

## Phase roadmap

### Phase 1 — Foundation (ship now) ✅ SQL ready
- Extensions + RLS own-data pattern  
- User extras, tools catalog, AI chat core, workspace scaffold  
- Plans/transactions, offline queue, security logs, support tickets  
- Extra buckets: voice, imports, backups, workspace, ai, tools, public, private  

### Phase 2 — Product depth
- Social graph, full AI agents/personas/voice/images tables  
- Materialized views: top_tools, trending, daily_stats, leaderboards  
- pgvector embeddings column + HNSW index  
- GIN/full-text search_index, partitioning for analytics  

### Phase 3 — Enterprise scale
- PostGIS, multi-region, read replicas  
- Affiliate/commission/tax, gift cards, withdrawals  
- Cron Edge Functions for cleanup/backup  
- Disaster recovery runbooks  

---

## Functions shipped in Phase 1

`create_wallet` · `update_last_seen` · `log_activity` · `create_notification` · `generate_slug` · `adjust_credits` (from schema.sql) · signup trigger `handle_new_user_v3`

---

## Storage path convention

```
{bucket}/{user_id}/{filename}
```

Public buckets: `avatars`, `images`, `public`  
Private: everything else (RLS folder = `auth.uid()`)

---

## Realtime channels (enable per table)

| Channel | Suggested tables |
|---|---|
| presence | `online_status` |
| chat | `ai_messages` |
| notifications | `notifications` |
| wallet | `wallet`, `credits` |
| workspace | `workspace_members` |

---

## Auth providers (app checklist)

| Provider | Status |
|---|---|
| Google | ✅ code + env |
| GitHub | ✅ code + env |
| Email / Magic Link | ✅ code |
| Phone OTP / Apple / Passkeys / MFA | ⬜ Phase 2 |

---

## Scalability target (design goal)

10M+ users · 100M+ files · 1B+ API · 1000+ tools · multi-region — achieved via partitioning, caching, replicas in Phase 3, not blank tables today.
