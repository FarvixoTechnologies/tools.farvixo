import { randomUUID } from 'crypto';

export type ApiErrorDetail = {
  code: string;
  message: string;
};

export type ApiMeta = {
  requestId: string;
  timestamp: string;
  page?: number;
  pageSize?: number;
  total?: number;
  [key: string]: unknown;
};

/**
 * Farvixo API envelope (Architecture v3 + backward-compatible `error` string).
 *
 * Success:
 *   { success: true, message, data, error: null, errorDetail: null, meta }
 * Error:
 *   { success: false, message, data: null, error: string, errorDetail: { code, message }, meta }
 */
export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T | null;
  /** Flat message for older clients (`adminFetch`, etc.). */
  error: string | null;
  /** Structured error (API Architecture v3). */
  errorDetail: ApiErrorDetail | null;
  meta: ApiMeta;
}

function baseMeta(extra?: Partial<ApiMeta>): ApiMeta {
  return {
    requestId: randomUUID(),
    timestamp: new Date().toISOString(),
    ...extra,
  };
}

export function apiOk<T>(
  data: T,
  status = 200,
  opts?: { message?: string; meta?: Partial<ApiMeta> },
): Response {
  const body: ApiResponse<T> = {
    success: true,
    message: opts?.message ?? '',
    data,
    error: null,
    errorDetail: null,
    meta: baseMeta(opts?.meta),
  };
  return Response.json(body, { status });
}

export function apiErr(
  message: string,
  status = 400,
  opts?: { code?: string; meta?: Partial<ApiMeta> },
): Response {
  const code = opts?.code ?? statusToCode(status);
  const body: ApiResponse<null> = {
    success: false,
    message,
    data: null,
    error: message,
    errorDetail: { code, message },
    meta: baseMeta({ ...opts?.meta, code }),
  };
  return Response.json(body, { status });
}

function statusToCode(status: number): string {
  switch (status) {
    case 400:
      return 'BAD_REQUEST';
    case 401:
      return 'UNAUTHORIZED';
    case 402:
      return 'PAYMENT_REQUIRED';
    case 403:
      return 'FORBIDDEN';
    case 404:
      return 'NOT_FOUND';
    case 409:
      return 'CONFLICT';
    case 422:
      return 'VALIDATION_ERROR';
    case 429:
      return 'RATE_LIMITED';
    case 501:
      return 'NOT_IMPLEMENTED';
    case 503:
      return 'SERVICE_UNAVAILABLE';
    default:
      return status >= 500 ? 'INTERNAL_ERROR' : 'ERROR';
  }
}
