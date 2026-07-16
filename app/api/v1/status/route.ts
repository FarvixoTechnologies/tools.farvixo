import { apiOk } from '@/lib/api-response';
import { clientIp, rateLimit, rateLimitResponse } from '@/lib/rate-limit';

export const dynamic = 'force-dynamic';

/** GET /api/v1/status — public API health (Architecture v3). */
export async function GET(req: Request) {
  const rl = rateLimit(`v1status:${clientIp(req)}`, 120, 60_000);
  if (!rl.allowed) return rateLimitResponse(rl.retryAfterSeconds);

  return apiOk({
    status: 'ok',
    version: 'v1',
    docs: '/api/v1/docs',
    openapi: '/api/v1/openapi.json',
    time: new Date().toISOString(),
  });
}
