import { apiOk, apiErr } from '@/lib/api-response';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';
import { geminiVisionServer } from '@/lib/gemini/server';

const BURST_LIMIT = 20; // vision OCR requests per minute per IP

/** Strict transcription prompt — no translation, ignore decorative graphics. */
function buildPrompt(languageHint?: string): string {
  const langLine = languageHint ? ` The text is primarily in ${languageHint}.` : '';
  return (
    'You are a precise OCR engine. Transcribe ALL text visible in this image EXACTLY as written, ' +
    `including titles, headings and body text.${langLine} Preserve the original language and script — do NOT translate. ` +
    'Preserve line breaks and reading order. Ignore purely decorative graphics, splatter, textures, borders or logos ' +
    'that do not contain letters. Do NOT invent or guess text that is not clearly there. ' +
    'Output ONLY the transcribed text with no commentary, labels or quotes. If there is no readable text, output nothing.'
  );
}

function cleanContent(raw: string): string {
  let content = raw.trim();
  const fence = content.match(/^```[a-z]*\n?([\s\S]*?)\n?```$/i);
  if (fence) content = fence[1].trim();
  return content;
}

function hasText(s: string): boolean {
  return s.replace(/\s/g, '').length >= 2;
}

/** Groq vision — uses the app's known-good Groq key with a fast multimodal
 *  model. Primary path because this key is confirmed working (it powers the
 *  text AI too), unlike the Gemini key. Model is overridable via env. */
// Known Groq multimodal models, newest first. If one is deprecated/unavailable
// the loop tries the next, so a single renamed model can't break the path.
const GROQ_VISION_MODELS = [
  'meta-llama/llama-4-scout-17b-16e-instruct',
  'meta-llama/llama-4-maverick-17b-128e-instruct',
  'llama-3.2-90b-vision-preview',
  'llama-3.2-11b-vision-preview',
];

async function groqVisionWithModel(dataUrl: string, prompt: string, model: string, key: string): Promise<string> {
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model,
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      }],
      temperature: 0.1,
      stream: false,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Groq vision failed (${res.status}) [${model}]: ${err.slice(0, 160)}`);
  }
  const json = (await res.json()) as { choices?: { message?: { content?: string } }[] };
  return cleanContent(json.choices?.[0]?.message?.content ?? '');
}

async function groqVision(dataUrl: string, prompt: string): Promise<string> {
  const key = process.env.GROQ_API_KEY;
  if (!key) throw new Error('GROQ_API_KEY not configured');
  const models = process.env.GROQ_VISION_MODEL
    ? [process.env.GROQ_VISION_MODEL]
    : GROQ_VISION_MODELS;
  let lastErr = 'no groq model succeeded';
  for (const model of models) {
    try {
      const text = await groqVisionWithModel(dataUrl, prompt, model, key);
      if (hasText(text)) return text;
      lastErr = `empty from ${model}`;
    } catch (e) {
      lastErr = e instanceof Error ? e.message : `failed on ${model}`;
      // Only keep trying other models if this one is unknown/decommissioned.
      if (!/decommission|not found|does not exist|400|404|model/i.test(lastErr)) throw e;
    }
  }
  throw new Error(lastErr);
}

/** Server-side Pollinations vision call — no browser CORS to fight. */
async function pollinationsVision(dataUrl: string, prompt: string): Promise<string> {
  const res = await fetch('https://gen.pollinations.ai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'openai',
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      }],
      stream: false,
      temperature: 0.1,
    }),
  });
  if (!res.ok) throw new Error(`Pollinations vision failed (${res.status})`);
  const raw = await res.text();
  try {
    const json = JSON.parse(raw) as { choices?: { message?: { content?: string } }[] };
    return cleanContent(json.choices?.[0]?.message?.content ?? '');
  } catch {
    return cleanContent(raw);
  }
}

export async function POST(req: Request) {
  const ip = clientIp(req);
  const burst = rateLimit(`vision-ocr:${ip}`, BURST_LIMIT, 60_000);
  if (!burst.allowed) return rateLimitResponse(burst.retryAfterSeconds);

  let body: { image?: string; languageHint?: string };
  try {
    body = (await req.json()) as { image?: string; languageHint?: string };
  } catch {
    return apiErr('Invalid request body', 400);
  }

  const image = body.image;
  if (!image || !image.startsWith('data:image/')) {
    return apiErr('An image data URL is required.', 400);
  }
  if (image.length > 12_000_000) {
    return apiErr('Image is too large for vision OCR — downscale first.', 413);
  }

  const prompt = buildPrompt(body.languageHint);
  const errors: string[] = [];

  // 1) Groq vision — the app's known-good key (confirmed working). Fast & free.
  if (process.env.GROQ_API_KEY) {
    try {
      const text = await groqVision(image, prompt);
      if (hasText(text)) return apiOk({ text, provider: 'groq' });
      errors.push('groq returned empty');
    } catch (e) {
      errors.push(e instanceof Error ? e.message : 'groq failed');
    }
  }

  // 2) Gemini vision — strongest on Indic scripts, but only if the key is valid.
  if (process.env.GEMINI_API_KEY) {
    try {
      const text = cleanContent(await geminiVisionServer(image, prompt));
      if (hasText(text)) return apiOk({ text, provider: 'gemini' });
      errors.push('gemini returned empty');
    } catch (e) {
      errors.push(e instanceof Error ? e.message : 'gemini failed');
    }
  }

  // 3) Pollinations vision — free, server-side (bypasses browser CORS).
  try {
    const text = await pollinationsVision(image, prompt);
    if (hasText(text)) return apiOk({ text, provider: 'pollinations' });
    errors.push('pollinations returned empty');
  } catch (e) {
    errors.push(e instanceof Error ? e.message : 'pollinations failed');
  }

  return apiErr(`Vision OCR unavailable: ${errors.join(' · ')}`, 502);
}
