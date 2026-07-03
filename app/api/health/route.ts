import { apiOk } from '@/lib/api-response';

export async function GET() {
  return apiOk({
    status: 'ok',
    service: 'ToolNest API',
    version: '1.0.0',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
}
