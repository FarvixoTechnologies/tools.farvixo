# AI Provider System

## Supported providers

| Provider | Transport | Key source | Streaming usage |
|---|---|---|---|
| Gemini | `generativelanguage…:streamGenerateContent` (SSE) | Vault / `GEMINI_API_KEY` | `usageMetadata` |
| OpenRouter | OpenAI-compatible | Vault / `OPENROUTER_API_KEY` | `usage` |
| Groq | OpenAI-compatible | Vault / `GROQ_API_KEY` | `usage` |
| Anthropic | `/v1/messages` (SSE) | Vault / `ANTHROPIC_API_KEY` | `message_delta.usage` |
| OpenAI | OpenAI-compatible | Vault / `OPENAI_API_KEY` | `usage` |
| Ollama | OpenAI-compatible (`base_url/v1`) | keyless / `OLLAMA_API_KEY` | best-effort |

Order is **not** hardcoded — it is `ai_models.priority` within active providers.

## API keys

- Stored **encrypted at rest** in Supabase Vault (pgsodium). `ai_api_keys` holds
  only `vault_secret_id`, a masked preview (`key_masked`), and `status`.
- `ai_key_store(secret, name)` / `ai_key_read(id)` are `SECURITY DEFINER`,
  granted to `service_role` only. Plaintext never leaves the server or reaches
  the browser.
- **Validation**: on add/rotate the key is checked against the provider's list
  endpoint; `validation_ok` + `last_validated_at` recorded.
- **Rotation**: stores a new Vault secret, keeps the row, re-validates.
- **Revocation**: `status='revoked'` — excluded from routing immediately.

## Health

- On-demand: `GET /api/admin/ai/health` reports per-provider failure rate +
  latency; `POST` auto-disables providers over the threshold.
- Background: `ai_health_sweep()` (pure SQL) does the same and is schedulable via
  `pg_cron` or any external scheduler:

  ```sql
  select cron.schedule('ai-health-sweep', '*/10 * * * *', $$select public.ai_health_sweep()$$);
  ```

  Requires the `pg_cron` extension (enable in Supabase → Database → Extensions).
  Without a scheduler, run the admin health `POST` or call the function manually.

## Adding a provider

1. Insert into `ai_providers` (id, base_url).
2. Add models in `ai_models` (priority, pricing, category).
3. Add a key in Admin → AI → API Keys (encrypted to Vault).
4. If it isn't OpenAI-compatible, add a streamer branch in `lib/ai/router.ts`.
