'use client';

/**
 * Restoration of broken Bengali text extracted from PDFs/OCR. PDF text layers
 * shatter complex Indic scripts: kar signs detach, conjuncts split, stray
 * spaces get injected. Two passes: a deterministic Unicode normalizer
 * (indic-normalize) fixes vowel order / conjuncts / the BA-nukta artifact with
 * no AI, then the AI engine joins word boundaries and reconstructs residue.
 */

import { normalizeIndicPage } from '@/lib/indic-normalize';

const RESTORE_SYSTEM_PROMPT = `You are an expert in Bengali (Bangla) computational linguistics. You repair Bengali text that a PDF/OCR parser has shattered, and you output ONLY the corrected text — no notes, no explanations, no code fences.

The input has these specific corruptions. Fix ALL of them:
1. Detached vowel signs (kar): spaces split a consonant from its matra, e.g. "ক িম শন" → "কমিশন", "তা ির খ" → "তারিখ", "না ম" → "নাম".
2. The artifact "ব়" (BA + nukta) is almost always the letter "র" (RA). e.g. "ভাব়েতব়" → "ভারতের", "ব়" → "র", "পব়গণা" → "পরগণা", "বসিব়হাট"/"ব িস ব় হাট" → "বসিরহাট", "উত্তব়" → "উত্তর", "নিব়্বাচন"/"িন বব়্া চন" → "নির্বাচন".
3. Broken conjuncts (যুক্তাক্ষর) split apart: "ম ন্ড ল" → "মন্ডল", "ন্দর্" → "ন্দ্র", "প তর্" → "পত্র", "িন শ্চ য়তা" → "নিশ্চয়তা", "ক েডর্" → "কার্ডে".
4. Reph/ya-phala misplacement: "গর্ ণ" → "গ্রহণ", "কর্ িম ক" → "ক্রমিক", "নিবর্াচন" → "নির্বাচন", "উ েদ্দ েশয্" → "উদ্দেশ্য", "বয্ তীত" → "ব্যতীত", "অ নয্" → "অন্য".
5. Random spaces inside words: join them into correct Bengali words using context.

Rules:
- Output valid, natural, grammatically correct standard Bengali (Unicode). Every word must be a real word.
- Bilingual government documents (voter ID, EPIC cards) repeat each field as "বাংলা লেবেল / English Label". Use the English side to confirm the Bengali reconstruction (e.g. next to "Polling Station Address" the Bengali is "ভোট গ্রহণ কেন্দ্রের ঠিকানা").
- Keep ALL English words, numbers, dates, URLs, IDs and punctuation EXACTLY as in the input.
- Preserve line breaks, "###" markers, and the overall layout/order. Do not summarize, drop, merge or add lines.
- Fix Hindi/Devanagari the same way if present.
- Respond with ONLY the corrected text.`;

export function hasBengaliText(text: string): boolean {
  return /[ঀ-৿]/.test(text);
}

/** Heuristic: does this Bengali text look shattered by a PDF text layer or OCR? */
export function looksBrokenBengali(text: string): boolean {
  if (!hasBengaliText(text)) return false;
  // Dependent vowel signs / hasanta appearing right after whitespace = detached kar signs.
  const detachedKar = (text.match(/\s[া-ৌ্ৗ]/g) || []).length;
  // Spaces injected between Bengali letters ("ক িম শন").
  const splitWords = (text.match(/[ক-হ]\s+[া-ৌ]/g) || []).length;
  // "ব়" (BA + nukta) is the classic mangled-RA artifact.
  const mangledRa = text.includes('ব়');
  // OCR garble: tokens mixing Bengali with Latin letters or stray symbols
  // inside the same word ("ম€180ৰ65", "তারিখ/20||10"). Digits alone are
  // excluded — "125-বসিরহাট" is legitimate.
  const mixedTokens = (text.match(/[ঀ-৿]\S*[A-Za-z€£|[\]{}]|[A-Za-z€£|[\]{}]\S*[ঀ-৿]/g) || []).length;
  return mangledRa || detachedKar + splitWords >= 3 || mixedTokens >= 2;
}

async function callRestoreApi(chunk: string, systemPrompt = RESTORE_SYSTEM_PROMPT, userLabel = 'Broken Input Bengali Text'): Promise<string> {
  const res = await fetch('/api/ai/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system: systemPrompt,
      messages: [{ role: 'user', content: `${userLabel}:\n"""\n${chunk}\n"""` }],
    }),
  });

  if (!res.ok) {
    let message = 'AI text repair failed';
    try {
      const json = (await res.json()) as { error?: string };
      if (json.error) message = json.error;
    } catch { /* non-JSON error */ }
    throw new Error(message);
  }

  if (!res.body) throw new Error('AI text repair failed — empty response');

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let out = '';

  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const events = buffer.split('\n\n');
    buffer = events.pop() ?? '';
    for (const evt of events) {
      const line = evt.trim();
      if (!line.startsWith('data:')) continue;
      const payload = line.slice(5).trim();
      if (payload === '[DONE]') continue;
      try {
        const parsed = JSON.parse(payload) as { text?: string; error?: string };
        if (parsed.error) throw new Error(parsed.error);
        // The server streams the ACCUMULATED text on every event, so replace
        // (not append) — appending duplicates every chunk into garbage.
        if (parsed.text) out = parsed.text;
      } catch (e) {
        if (e instanceof Error && e.message && !(e instanceof SyntaxError)) throw e;
      }
    }
  }

  // Strip a stray ```...``` fence if the model wrapped its answer despite instructions.
  let cleaned = out.trim();
  const fence = cleaned.match(/^```[a-z]*\n?([\s\S]*?)\n?```$/i);
  if (fence) cleaned = fence[1].trim();
  if (!cleaned) throw new Error('AI text repair returned no text');
  return cleaned;
}

/** Split text into chunks at paragraph boundaries, each ≤ maxChars.
 *  Smaller chunks = the model reconstructs more reliably. */
function chunkText(text: string, maxChars = 2500): string[] {
  if (text.length <= maxChars) return [text];
  const paragraphs = text.split('\n');
  const chunks: string[] = [];
  let current = '';
  for (const p of paragraphs) {
    const candidate = current ? `${current}\n${p}` : p;
    if (candidate.length > maxChars && current) {
      chunks.push(current);
      current = p;
    } else {
      current = candidate;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

/**
 * Restore broken Bengali/Indic text via the AI engine.
 * Fail-soft per chunk: if one chunk fails, the original chunk text is kept
 * (except quota errors, which abort the whole run so the user sees why).
 */
export async function restoreBengaliText(
  text: string,
  onProgress?: (done: number, total: number) => void,
): Promise<string> {
  // Deterministic Unicode repair first — fixes vowel order / conjuncts / the
  // BA-nukta artifact with no AI, and gives the model clean input. Also the
  // fallback if AI is unavailable is already much better than raw.
  const chunks = chunkText(normalizeIndicPage(text));
  const out: string[] = [];
  for (let i = 0; i < chunks.length; i++) {
    onProgress?.(i, chunks.length);
    if (!looksBrokenBengali(chunks[i]) && !hasBengaliText(chunks[i])) {
      out.push(chunks[i]);
      continue;
    }
    try {
      out.push(await callRestoreApi(chunks[i]));
    } catch (e) {
      const msg = e instanceof Error ? e.message : '';
      if (/limit|credit|sign in/i.test(msg)) throw e; // quota — surface to the user
      out.push(chunks[i]); // keep normalized text for transient failures
    }
  }
  onProgress?.(chunks.length, chunks.length);
  return out.join('\n');
}

const OCR_REPAIR_SYSTEM_PROMPT = `You are an expert multilingual OCR post-editor. An OCR engine has read an image and produced noisy, error-filled text. Your job is to reconstruct the correct, natural text the image most likely contained. Output ONLY the corrected text — no notes, no explanations, no code fences, no translation.

Fix ALL of these OCR errors:
1. Misrecognized characters and confusions (e.g. 0/O, 1/l/I, rn/m, cl/d, 5/S, 8/B), and script-specific glyph confusions.
2. Broken or split words: join fragments into correct real words using context ("in for mation" -> "information").
3. Wrongly split or merged spaces, stray punctuation, and junk symbols injected between letters.
4. For Indic scripts (Devanagari/Hindi, Bengali, Tamil, Telugu, Gujarati, Punjabi, Kannada, Malayalam, Odia): reattach detached vowel signs (matra), rejoin broken conjuncts (yuktakshar), fix reph/half-letter placement, and remove stray spaces inside words. Every output word must be a real, valid word.
5. For Arabic/Urdu: restore correct letter forms and joining, fix reversed or detached characters.
6. For CJK (Chinese/Japanese/Korean): fix confused/lookalike characters.

Rules:
- Output valid, natural, grammatically correct text in the SAME language(s) as the input. Do NOT translate.
- Keep genuine English words, numbers, dates, URLs, IDs and punctuation that clearly belong.
- Preserve line breaks and the overall layout/order. Do not summarize, drop, merge, add, or reorder lines.
- If a fragment is truly unreadable, make the best contextual guess rather than leaving garbage.
- Respond with ONLY the corrected text.`;

/** Non-Latin script ranges: if text has these, OCR repair is worth an AI pass. */
function hasNonLatinScript(text: string): boolean {
  return /[\u0900-\u097F\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F\u0600-\u06FF\u0750-\u077F\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF\u0400-\u04FF\u0E00-\u0E7F]/.test(text);
}

/** Heuristic: does OCR text look noisy enough to warrant an AI repair pass? */
export function looksNoisyOcr(text: string): boolean {
  if (!text.trim()) return false;
  if (hasNonLatinScript(text)) return true;
  // Many single/orphan characters or stray symbols = noisy Latin OCR.
  const tokens = text.split(/\s+/).filter(Boolean);
  if (tokens.length === 0) return false;
  const shortTokens = tokens.filter((t) => t.length <= 2).length;
  const junk = (text.match(/[|~^`¬°£€¥§©®™\\{}\[\]<>]/g) || []).length;
  return shortTokens / tokens.length > 0.4 || junk >= 3;
}

/**
 * General multilingual OCR text repair via the AI engine. Works for ANY
 * language/script (Hindi, Tamil, Arabic, Chinese, English, …). Bengali is
 * routed through the specialised {@link restoreBengaliText} for best results.
 * Fail-soft per chunk; quota errors abort so the user sees why.
 */
export async function restoreOcrText(
  text: string,
  languageHint?: string,
  onProgress?: (done: number, total: number) => void,
): Promise<string> {
  const normalized = normalizeIndicPage(text);
  // Bengali has a dedicated, higher-accuracy repair pipeline.
  if (hasBengaliText(normalized)) return restoreBengaliText(normalized, onProgress);

  const chunks = chunkText(normalized);
  const langLine = languageHint ? `The document language is: ${languageHint}. ` : '';
  const out: string[] = [];
  for (let i = 0; i < chunks.length; i++) {
    onProgress?.(i, chunks.length);
    if (!chunks[i].trim()) { out.push(chunks[i]); continue; }
    try {
      out.push(await callRestoreApi(`${langLine}${chunks[i]}`, OCR_REPAIR_SYSTEM_PROMPT, 'Noisy OCR text'));
    } catch (e) {
      const msg = e instanceof Error ? e.message : '';
      if (/limit|credit|sign in/i.test(msg)) throw e; // quota — surface to the user
      out.push(chunks[i]); // keep normalized text for transient failures
    }
  }
  onProgress?.(chunks.length, chunks.length);
  return out.join('\n');
}
