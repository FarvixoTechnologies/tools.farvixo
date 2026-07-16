import type { ChatMessage } from '@/lib/ai';

const DEFAULT_MODEL = 'gemini-2.0-flash';

export async function geminiCompleteServer(
  messages: ChatMessage[],
  system: string,
  model = DEFAULT_MODEL,
): Promise<string> {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY is not configured on the server.');

  const body = {
    system_instruction: { parts: [{ text: system }] },
    contents: messages.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    })),
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API error (${res.status}): ${errText.slice(0, 300)}`);
  }

  const json = await res.json() as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  return json.candidates?.[0]?.content?.parts?.map((p) => p.text || '').join('') || '';
}

/**
 * Multimodal OCR with Gemini — reads text directly out of an image. Gemini is
 * excellent on Indic scripts (Hindi/Bengali/Tamil…), decorative poster fonts and
 * handwriting, so this is the primary "Vision OCR" path. Returns trimmed text
 * (empty string if the model found no readable text).
 */
export async function geminiVisionServer(
  imageDataUrl: string,
  prompt: string,
  model = DEFAULT_MODEL,
): Promise<string> {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY is not configured on the server.');

  const match = imageDataUrl.match(/^data:(image\/[a-z0-9.+-]+);base64,(.+)$/i);
  if (!match) throw new Error('Invalid image data URL');
  const [, mimeType, data] = match;

  const body = {
    contents: [{
      role: 'user',
      parts: [
        { text: prompt },
        { inline_data: { mime_type: mimeType, data } },
      ],
    }],
    generationConfig: { temperature: 0.1 },
  };

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini vision error (${res.status}): ${errText.slice(0, 300)}`);
  }

  const json = await res.json() as {
    candidates?: { content?: { parts?: { text?: string }[] } }[];
  };
  return (json.candidates?.[0]?.content?.parts?.map((p) => p.text || '').join('') || '').trim();
}

export async function* geminiStreamServer(
  messages: ChatMessage[],
  system: string,
  model = DEFAULT_MODEL,
  temperature?: number,
): AsyncGenerator<string> {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY is not configured on the server.');

  const body: Record<string, unknown> = {
    system_instruction: { parts: [{ text: system }] },
    contents: messages.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    })),
  };
  if (temperature !== undefined) {
    body.generationConfig = { temperature };
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse&key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API error (${res.status}): ${errText.slice(0, 300)}`);
  }

  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let full = '';

  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      const payload = line.slice(5).trim();
      if (!payload || payload === '[DONE]') continue;
      try {
        const json = JSON.parse(payload) as {
          candidates?: { content?: { parts?: { text?: string }[] } }[];
        };
        const chunk = json.candidates?.[0]?.content?.parts?.map((p) => p.text || '').join('') || '';
        if (chunk) {
          full += chunk;
          yield full;
        }
      } catch {
        /* partial SSE chunk */
      }
    }
  }
}
