import { apiErr, apiOk } from '@/lib/api-response';
import { logAdminAction, requirePermission } from '@/lib/admin-auth';

export const dynamic = 'force-dynamic';

function mask(key: string): string {
  if (key.length <= 8) return '••••';
  return `${key.slice(0, 3)}…${key.slice(-4)}`;
}

/** Best-effort live validation against the provider's list endpoint. */
async function validateKey(providerId: string, key: string): Promise<boolean | null> {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 8000);
  try {
    let url = '';
    const headers: Record<string, string> = {};
    switch (providerId) {
      case 'openai': url = 'https://api.openai.com/v1/models'; headers.Authorization = `Bearer ${key}`; break;
      case 'groq': url = 'https://api.groq.com/openai/v1/models'; headers.Authorization = `Bearer ${key}`; break;
      case 'openrouter': url = 'https://openrouter.ai/api/v1/models'; headers.Authorization = `Bearer ${key}`; break;
      case 'gemini': url = `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(key)}`; break;
      case 'anthropic': url = 'https://api.anthropic.com/v1/models'; headers['x-api-key'] = key; headers['anthropic-version'] = '2023-06-01'; break;
      default: return null; // ollama / unknown — cannot validate remotely
    }
    const res = await fetch(url, { headers, signal: ctrl.signal });
    return res.ok;
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

export async function GET() {
  const auth = await requirePermission('ai.read');
  if (!auth.ok) return auth.response;
  // Never return key_ciphertext.
  const { data, error } = await auth.ctx.admin
    .from('ai_api_keys')
    .select('id, provider_id, label, key_masked, status, last_validated_at, validation_ok, last_used_at, created_at')
    .order('created_at', { ascending: false });
  if (error) return apiErr(error.message, 500);
  return apiOk({ keys: data ?? [] });
}

export async function POST(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: { provider_id?: string; label?: string; key?: string; validate?: boolean };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }
  const key = (b.key ?? '').trim();
  if (!b.provider_id || !b.label || !key) return apiErr('provider_id, label, key required', 400);

  const { data: prov } = await admin.from('ai_providers').select('id').eq('id', b.provider_id).maybeSingle();
  if (!prov) return apiErr('provider does not exist', 400);

  const validation = b.validate ? await validateKey(b.provider_id, key) : null;

  // Encrypt at rest via Supabase Vault (pgsodium); store only the secret id.
  const { data: secretId, error: vaultErr } = await admin.rpc('ai_key_store', { p_secret: key, p_name: `ai-${b.provider_id}` });
  if (vaultErr) return apiErr(`Key encryption failed: ${vaultErr.message}`, 500);

  const { data: row, error } = await admin.from('ai_api_keys').insert({
    provider_id: b.provider_id,
    label: b.label.trim().slice(0, 80),
    key_masked: mask(key),
    vault_secret_id: secretId,
    status: 'active',
    validation_ok: validation,
    last_validated_at: b.validate ? new Date().toISOString() : null,
    created_by: userId,
  }).select('id, provider_id, label, key_masked, status, validation_ok').single();
  if (error) return apiErr(error.message, 500);

  await logAdminAction(admin, userId, 'ai.key.add', b.provider_id, { label: b.label });
  return apiOk({ key: row, validation });
}

export async function PATCH(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;

  let b: { id?: string; action?: 'revoke' | 'validate' | 'rotate'; key?: string };
  try { b = (await req.json()) as typeof b; } catch { return apiErr('Invalid body', 400); }
  if (!b.id || !b.action) return apiErr('id and action required', 400);

  const { data: existing } = await admin.from('ai_api_keys').select('id, provider_id, vault_secret_id').eq('id', b.id).maybeSingle();
  if (!existing) return apiErr('Key not found', 404);

  if (b.action === 'revoke') {
    await admin.from('ai_api_keys').update({ status: 'revoked' }).eq('id', b.id);
    await logAdminAction(admin, userId, 'ai.key.revoke', existing.provider_id);
    return apiOk({ revoked: true });
  }

  if (b.action === 'rotate') {
    const key = (b.key ?? '').trim();
    if (!key) return apiErr('New key required for rotation', 400);
    const ok = await validateKey(existing.provider_id, key);
    const { data: newSecret, error: vErr } = await admin.rpc('ai_key_store', { p_secret: key, p_name: `ai-${existing.provider_id}` });
    if (vErr) return apiErr(`Key encryption failed: ${vErr.message}`, 500);
    await admin.from('ai_api_keys').update({
      key_masked: mask(key),
      vault_secret_id: newSecret,
      status: 'active',
      validation_ok: ok,
      last_validated_at: new Date().toISOString(),
    }).eq('id', b.id);
    await logAdminAction(admin, userId, 'ai.key.rotate', existing.provider_id);
    return apiOk({ rotated: true, validation: ok });
  }

  // validate — decrypt from Vault
  let raw = '';
  if (existing.vault_secret_id) {
    const { data: dec } = await admin.rpc('ai_key_read', { p_id: existing.vault_secret_id });
    raw = (dec as string) ?? '';
  }
  const ok = raw ? await validateKey(existing.provider_id, raw) : null;
  await admin.from('ai_api_keys').update({ validation_ok: ok, last_validated_at: new Date().toISOString() }).eq('id', b.id);
  return apiOk({ validation: ok });
}

export async function DELETE(req: Request) {
  const auth = await requirePermission('ai.manage');
  if (!auth.ok) return auth.response;
  const { admin, userId } = auth.ctx;
  const id = new URL(req.url).searchParams.get('id') ?? '';
  if (!id) return apiErr('id required', 400);
  const { error } = await admin.from('ai_api_keys').delete().eq('id', id);
  if (error) return apiErr(error.message, 500);
  await logAdminAction(admin, userId, 'ai.key.delete', id);
  return apiOk({ deleted: true });
}
