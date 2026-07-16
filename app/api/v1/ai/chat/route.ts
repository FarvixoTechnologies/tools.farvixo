import { POST as chatPost } from '@/app/api/v1/chat/route';

export const dynamic = 'force-dynamic';

/** POST /api/v1/ai/chat — Architecture v3 alias of /api/v1/chat */
export const POST = chatPost;
