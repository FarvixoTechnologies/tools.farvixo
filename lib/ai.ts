'use client';

/**
 * Universal AI Engine
 * - Primary: user's Gemini API key (browser) or server GEMINI_API_KEY via /api/ai/chat
 * - Fallback: free Pollinations text API
 */

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
}

const KEY_STORAGE = 'toolnest_gemini_key';
const MODEL_STORAGE = 'toolnest_gemini_model';

export function getApiKey(): string {
  if (typeof window === 'undefined') return '';
  return localStorage.getItem(KEY_STORAGE) || '';
}

export function setApiKey(key: string): void {
  localStorage.setItem(KEY_STORAGE, key.trim());
}

export function getModel(): string {
  if (typeof window === 'undefined') return 'gemini-2.0-flash';
  return localStorage.getItem(MODEL_STORAGE) || 'gemini-2.0-flash';
}

export function setModel(model: string): void {
  localStorage.setItem(MODEL_STORAGE, model);
}

async function geminiComplete(
  messages: ChatMessage[],
  system: string,
  onChunk?: (text: string) => void,
): Promise<string> {
  const key = getApiKey();
  const model = getModel();
  const body = {
    system_instruction: { parts: [{ text: system }] },
    contents: messages.map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] })),
  };
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse&key=${encodeURIComponent(key)}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API error (${res.status}): ${errText.slice(0, 200)}`);
  }
  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let full = '';
  let buffer = '';
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
        const json = JSON.parse(payload);
        const text: string = json?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text || '').join('') || '';
        if (text) {
          full += text;
          onChunk?.(full);
        }
      } catch {
        /* partial chunk — ignored */
      }
    }
  }
  return full;
}

async function serverGeminiComplete(
  messages: ChatMessage[],
  system: string,
  onChunk?: (text: string) => void,
): Promise<string> {
  const res = await fetch('/api/ai/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ messages, system }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(err.error || `Server AI error (${res.status})`);
  }
  const reader = res.body?.getReader();
  if (!reader) throw new Error('No response stream from server AI');
  const decoder = new TextDecoder();
  let full = '';
  let buffer = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split('\n');
    buffer = lines.pop() || '';
    for (const line of lines) {
      if (!line.startsWith('data:')) continue;
      const payload = line.slice(5).trim();
      if (payload === '[DONE]') continue;
      try {
        const json = JSON.parse(payload) as { text?: string; error?: string };
        if (json.error) throw new Error(json.error);
        if (json.text) {
          full = json.text;
          onChunk?.(full);
        }
      } catch (e) {
        if (e instanceof Error && e.message !== 'Unexpected end of JSON input') throw e;
      }
    }
  }
  return full;
}

async function pollinationsComplete(
  messages: ChatMessage[],
  system: string,
  onChunk?: (text: string) => void,
): Promise<string> {
  const res = await fetch('https://text.pollinations.ai/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      messages: [{ role: 'system', content: system }, ...messages.map((m) => ({ role: m.role, content: m.content }))],
      model: 'openai',
    }),
  });
  if (!res.ok) throw new Error(`AI service error (${res.status}). Try adding your own Gemini API key in AI Settings.`);
  const text = await res.text();
  onChunk?.(text);
  return text;
}

/** Run an AI completion. Streams via onChunk (receives the FULL text so far). */
export async function aiComplete(
  messages: ChatMessage[],
  system = 'You are ToolNest AI, a helpful assistant inside the ToolNest platform (toolnestfm.com) which offers 120+ online tools. Be concise and helpful.',
  onChunk?: (text: string) => void,
): Promise<string> {
  if (getApiKey()) {
    return geminiComplete(messages, system, onChunk);
  }
  try {
    return await serverGeminiComplete(messages, system, onChunk);
  } catch {
    return pollinationsComplete(messages, system, onChunk);
  }
}

/** Generate an image; returns an object URL of the image blob. */
export async function aiImage(prompt: string, width = 1024, height = 1024): Promise<string> {
  const seed = Math.floor(Math.random() * 1e9);
  const url = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}?width=${width}&height=${height}&seed=${seed}&nologo=true`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Image generation failed (${res.status}). Please try again.`);
  const blob = await res.blob();
  return URL.createObjectURL(blob);
}
