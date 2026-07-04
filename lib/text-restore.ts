'use client';

/**
 * AI-powered restoration of broken Bengali text extracted from PDFs/OCR.
 * PDF text layers often shatter complex Indic scripts: kar signs (ি ে া ...)
 * detach from their consonants, conjuncts split apart, and stray spaces get
 * injected between characters. A deterministic fix is impossible client-side,
 * so we route the text through the AI engine with a restoration prompt.
 */

const RESTORE_SYSTEM_PROMPT = `You are an expert system specializing in Bengali computational linguistics and text restoration.
Your task is to fix broken, garbled, or misaligned Bengali text that has been extracted from a PDF file through an OCR or PDF-to-text parser.

Common extraction errors in the input text include:
1. Missing or misplaced "Kar" signs (যেমন: ি, ো, ৌ, ে, া).
2. Broken ligatures/conjuncts (যুক্তাক্ষর ভেঙে যাওয়া, যেমন "ক্ষ", "জ্ঞ", "ক্ট" আলাদা হয়ে যাওয়া).
3. Incorrect character encoding, random spaces between characters, or raw ANSI strings mixed with Unicode.
4. OCR misreads where Bengali words are replaced by lookalike Latin letters, digits or symbols (e.g. "ম€180ৰ65 First Name" is actually "Relative's First Name" label, "[39 Name" is "Last Name", "TF" may be "নম্বর"). Bilingual documents (voter cards, government forms) usually repeat each label as "বাংলা লেবেল/English Label" — use the surviving language to reconstruct the damaged one.

Instructions:
- Carefully analyze the context and reconstruct the words to make them grammatically correct and contextually meaningful in standard Bengali (Unicode/UTF-8).
- Use standard fonts like SolaimanLipi or Kalpurush as the semantic baseline.
- Maintain the original sentence structure, paragraph breaks, and overall meaning. Do not summarize, skip, or add any new information.
- Keep English words, numbers, and punctuation marks exactly as they are in the original text.
- If the text contains Hindi or other Indic scripts with the same kinds of breakage, restore those the same way.
- Respond ONLY with the corrected text. Do not include any explanations, greetings, or markdown code blocks.`;

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

async function callRestoreApi(chunk: string): Promise<string> {
  const res = await fetch('/api/ai/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system: RESTORE_SYSTEM_PROMPT,
      messages: [{ role: 'user', content: `Broken Input Bengali Text:\n"""\n${chunk}\n"""` }],
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
        if (parsed.text) out += parsed.text;
      } catch (e) {
        if (e instanceof Error && e.message && !(e instanceof SyntaxError)) throw e;
      }
    }
  }

  const cleaned = out.trim();
  if (!cleaned) throw new Error('AI text repair returned no text');
  return cleaned;
}

/** Split text into chunks at paragraph boundaries, each ≤ maxChars. */
function chunkText(text: string, maxChars = 5000): string[] {
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
  const chunks = chunkText(text);
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
      out.push(chunks[i]); // keep original for transient failures
    }
  }
  onProgress?.(chunks.length, chunks.length);
  return out.join('\n');
}
