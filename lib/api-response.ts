import { randomUUID } from 'crypto';

export interface ApiResponse<T> {
  success: boolean;
  data: T | null;
  error: string | null;
  meta: { requestId: string; timestamp: string };
}

export function apiOk<T>(data: T, status = 200): Response {
  const body: ApiResponse<T> = {
    success: true,
    data,
    error: null,
    meta: { requestId: randomUUID(), timestamp: new Date().toISOString() },
  };
  return Response.json(body, { status });
}

export function apiErr(message: string, status = 400): Response {
  const body: ApiResponse<null> = {
    success: false,
    data: null,
    error: message,
    meta: { requestId: randomUUID(), timestamp: new Date().toISOString() },
  };
  return Response.json(body, { status });
}
