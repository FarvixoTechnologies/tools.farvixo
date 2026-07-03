import { apiErr } from '@/lib/api-response';
import type { ChatMessage } from '@/lib/ai';
import { geminiStreamServer } from '@/lib/gemini/server';

const DEFAULT_SYSTEM =
  'You are ToolNest AI, a helpful assistant inside the ToolNest platform (toolnestfm.com) which offers 120+ online tools. Be concise and helpful.';

export async function POST(req: Request) {
  try {
    const body = (await req.json()) as {
      messages?: ChatMessage[];
      system?: string;
      model?: string;
    };

    if (!body.messages?.length) {
      return apiErr('messages array is required', 400);
    }

    if (!process.env.GEMINI_API_KEY) {
      return apiErr('Server AI is not configured', 503);
    }

    const system = body.system || DEFAULT_SYSTEM;
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        try {
          for await (const text of geminiStreamServer(body.messages!, system, body.model)) {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ text })}\n\n`));
          }
          controller.enqueue(encoder.encode('data: [DONE]\n\n'));
          controller.close();
        } catch (err) {
          const message = err instanceof Error ? err.message : 'AI generation failed';
          controller.enqueue(encoder.encode(`data: ${JSON.stringify({ error: message })}\n\n`));
          controller.close();
        }
      },
    });

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
      },
    });
  } catch {
    return apiErr('Invalid request body', 400);
  }
}
