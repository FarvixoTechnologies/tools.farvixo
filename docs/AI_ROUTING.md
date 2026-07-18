# AI Routing

## Chain resolution (`resolveChain`)

1. Compute unhealthy providers from `ai_usage` (last 6h; ≥5 samples and ≥50%
   error rate → unhealthy).
2. Query `ai_models` where `is_active` and `category = <requested>`, joined to
   `ai_providers` (`is_active`), **ordered by `ai_models.priority` ascending**
   (lower = preferred).
3. Walk models in priority order, one entry per provider (first/best model wins).
4. Skip a provider when: provider inactive, provider unhealthy, or **no usable key**.
5. Resolve key: **Vault** (`ai_api_keys.status='active'` → `ai_key_read`) →
   **env fallback** → skip (Ollama may run keyless).

The resulting `ChainEntry[]` order comes entirely from the database.

## Fallback (`streamChat`)

Try each `ChainEntry` in order. On error (or empty response), call `onRetry`
(logged to `ai_logs` as a `warn`) and advance to the next entry. The full ordered
list of providers attempted is recorded in `ai_logs.meta.fallback_path` with
`retry_count`. If every entry fails, throw a combined error.

### Skips
- Disabled provider → excluded at chain build.
- Unhealthy provider → excluded at chain build.
- Expired / revoked key → `status != 'active'` excluded; a live-invalid key fails
  the request and falls through to the next provider (logged).

## Safety net

If the DB chain is empty (no active model/provider with a key), the chat route
falls back to the keyless free provider (Pollinations) so the product keeps
working. This is logged and is the only non-DB path.

## Categories

`chat` (text), `image`, `embedding`, `audio` — the `category` column scopes the
chain so image/vision requests resolve their own models.
