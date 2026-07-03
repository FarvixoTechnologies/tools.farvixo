import { apiErr, apiOk } from '@/lib/api-response';

const subscribers = new Set<string>();

export async function POST(req: Request) {
  try {
    const body = (await req.json()) as { email?: string; source?: string };
    const email = body.email?.trim().toLowerCase();
    if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return apiErr('Valid email address is required', 400);
    }
    subscribers.add(email);
    return apiOk({ subscribed: true, email, source: body.source || 'homepage' });
  } catch {
    return apiErr('Invalid request body', 400);
  }
}
