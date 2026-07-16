import { GET as usersMeGet, PATCH as usersMePatch } from '@/app/api/v1/users/me/route';

export const dynamic = 'force-dynamic';

/** GET /api/v1/auth/me — alias of /api/v1/users/me (Architecture v3 auth surface). */
export const GET = usersMeGet;
export const PATCH = usersMePatch;
