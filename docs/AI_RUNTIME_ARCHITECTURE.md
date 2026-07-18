# AI Runtime Architecture

Farvixo's AI runtime is **database-driven**: every AI request resolves its provider
chain, model, and API key from the Admin AI configuration (Supabase), not from
hardcoded order or environment-only routing.

## Request flow

```
User request  →  /api/ai/{chat,image-generate,vision-ocr}
  1. Quota check        checkQuota(admin, userId, plan)         → JSON 429 if exceeded
  2. Resolve chain      resolveChain(admin, category)           → ordered ChainEntry[]
         ai_models (is_active, category) ORDER BY priority
         ⨝ ai_providers (is_active)
         − unhealthy providers (getUnhealthyProviders)
         → resolve key: Vault (ai_key_read) → env fallback → skip
  3. Stream             streamChat(chain, …)                    → try each entry, retry on failure
  4. Record (finally)   recordUsage(ai_usage) + logAi(ai_logs)  → tokens, cost, latency, fallback path
```

## Components

| Module | Responsibility |
|---|---|
| `lib/ai/router.ts` | `resolveChain`, `streamChat`, per-provider streamers, `getUnhealthyProviders`, Vault key resolution |
| `lib/ai/engine.ts` | `checkQuota`, `recordUsage`, `computeCost`, `logAi`, `estimateTokens` |
| `ai_usage_stats()` RPC | Dashboard KPI aggregation |
| `ai_health_sweep()` RPC | Background auto-disable of unhealthy providers |
| `ai_key_store` / `ai_key_read` | Supabase Vault (pgsodium) encrypt/decrypt, service-role only |

## Data sources (single source of truth)

- `ai_providers` — provider registry + `is_active` + `base_url`
- `ai_models` — model registry + `priority` + `category` + pricing + `is_active`
- `ai_api_keys` — `vault_secret_id` (encrypted key) + `status`
- `ai_quotas` — daily/monthly limits per plan or user
- `ai_usage` / `ai_logs` — observability, feed the live dashboard + health

## Token accounting

Providers that return usage in the stream (OpenAI-compatible `stream_options.include_usage`,
Gemini `usageMetadata`, Anthropic `message_delta.usage`) are recorded **exactly**.
Otherwise tokens are estimated (~4 chars/token). `ai_logs.meta.token_source` records which.

## Cost

`computeCost` multiplies token counts by `ai_models.input_cost_per_1k` /
`output_cost_per_1k`. Stored per request in `ai_usage.cost`.
