import { NextResponse } from 'next/server';

export const dynamic = 'force-static';

const BASE = process.env.NEXT_PUBLIC_APP_URL || 'https://tools.farvixo.com';

const bearerSecurity = [{ bearerAuth: [] as string[] }];
const cookieNote =
  'Browser session (Supabase Auth cookie). Use after sign-in via web/Flutter OAuth — not an API key.';

const envelope = (dataSchema: Record<string, unknown>) => ({
  type: 'object',
  properties: {
    success: { type: 'boolean' },
    message: { type: 'string' },
    data: dataSchema,
    error: { type: 'string', nullable: true },
    errorDetail: {
      type: 'object',
      nullable: true,
      properties: { code: { type: 'string' }, message: { type: 'string' } },
    },
    meta: {
      type: 'object',
      properties: {
        requestId: { type: 'string' },
        timestamp: { type: 'string' },
        page: { type: 'integer' },
        pageSize: { type: 'integer' },
        total: { type: 'integer' },
      },
    },
  },
});

const credits = {
  type: 'object',
  properties: { spent: { type: 'integer' }, remaining: { type: 'integer' } },
};

const spec = {
  openapi: '3.0.3',
  info: {
    title: 'Farvixo API',
    version: '1.0.0',
    description:
      'Farvixo Tools public API (Architecture v3). ' +
      'Developer AI/utility endpoints use `Authorization: Bearer fx_live_...` (create keys at ' +
      `${BASE}/dashboard/api-keys). ` +
      'User routes use the signed-in session cookie. Interactive docs: ' +
      `${BASE}/api/v1/docs`,
  },
  servers: [{ url: `${BASE}/api/v1` }],
  components: {
    securitySchemes: {
      bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'fx_live_...' },
    },
  },
  paths: {
    '/status': {
      get: {
        summary: 'API health',
        responses: { '200': { description: 'OK', content: { 'application/json': { schema: envelope({ type: 'object' }) } } } },
      },
    },
    '/auth/me': {
      get: {
        summary: 'Current user (session)',
        description: cookieNote,
        responses: { '200': { description: 'Profile' }, '401': { description: 'Unauthorized' } },
      },
    },
    '/users/me': {
      get: {
        summary: 'Current user profile (session)',
        description: cookieNote,
        responses: { '200': { description: 'Profile' } },
      },
      patch: {
        summary: 'Update profile (full_name, avatar_url)',
        description: cookieNote,
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: { full_name: { type: 'string' }, avatar_url: { type: 'string', nullable: true } },
              },
            },
          },
        },
        responses: { '200': { description: 'Updated' } },
      },
    },
    '/tools': {
      get: {
        summary: 'Full tool catalog (public)',
        parameters: [{ name: 'category', in: 'query', schema: { type: 'string', example: 'pdf' } }],
        responses: { '200': { description: 'Tool list' } },
      },
    },
    '/tools/categories': {
      get: { summary: 'Tool categories (public)', responses: { '200': { description: 'Categories' } } },
    },
    '/tools/search': {
      get: {
        summary: 'Search tools',
        parameters: [
          { name: 'q', in: 'query', schema: { type: 'string' } },
          { name: 'page', in: 'query', schema: { type: 'integer', default: 1 } },
          { name: 'limit', in: 'query', schema: { type: 'integer', default: 20 } },
        ],
        responses: { '200': { description: 'Matches' } },
      },
    },
    '/tools/{id}': {
      get: {
        summary: 'Tool by slug',
        parameters: [{ name: 'id', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { '200': { description: 'Tool' }, '404': { description: 'Not found' } },
      },
    },
    '/tools/favorite': {
      get: { summary: 'List favorites (session)', description: cookieNote, responses: { '200': { description: 'Favorites' } } },
      post: {
        summary: 'Add/remove favorite (session)',
        description: cookieNote,
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['toolSlug'],
                properties: { toolSlug: { type: 'string' }, favorite: { type: 'boolean', default: true } },
              },
            },
          },
        },
        responses: { '200': { description: 'Saved' } },
      },
    },
    '/plans': {
      get: { summary: 'Subscription plans (public)', responses: { '200': { description: 'Plans' } } },
    },
    '/wallet': {
      get: { summary: 'Wallet balance (session)', description: cookieNote, responses: { '200': { description: 'Wallet' } } },
    },
    '/credits': {
      get: { summary: 'Credits + ledger (session)', description: cookieNote, responses: { '200': { description: 'Credits' } } },
    },
    '/notifications': {
      get: {
        summary: 'Notifications (session)',
        description: cookieNote,
        parameters: [
          { name: 'page', in: 'query', schema: { type: 'integer' } },
          { name: 'limit', in: 'query', schema: { type: 'integer' } },
        ],
        responses: { '200': { description: 'Inbox' } },
      },
      patch: {
        summary: 'Mark read',
        description: cookieNote,
        requestBody: {
          content: {
            'application/json': {
              schema: {
                type: 'object',
                properties: { ids: { type: 'array', items: { type: 'string' } }, all: { type: 'boolean' } },
              },
            },
          },
        },
        responses: { '200': { description: 'Updated' } },
      },
      delete: {
        summary: 'Delete notifications',
        description: cookieNote,
        responses: { '200': { description: 'Deleted' } },
      },
    },
    '/ai/chat': {
      post: {
        summary: 'AI chat (1 credit) — alias of /chat',
        security: bearerSecurity,
        responses: { '200': { description: 'Reply' } },
      },
    },
    '/chat': {
      post: {
        summary: 'AI chat completion (1 credit)',
        security: bearerSecurity,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['messages'],
                properties: {
                  messages: {
                    type: 'array',
                    maxItems: 50,
                    items: {
                      type: 'object',
                      required: ['role', 'content'],
                      properties: {
                        role: { type: 'string', enum: ['user', 'assistant'] },
                        content: { type: 'string' },
                      },
                    },
                  },
                  system: { type: 'string', maxLength: 4000 },
                  model: { type: 'string', example: 'gemini-2.0-flash' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Reply',
            content: {
              'application/json': {
                schema: envelope({
                  type: 'object',
                  properties: { reply: { type: 'string' }, credits },
                }),
              },
            },
          },
          '401': { description: 'Invalid or revoked API key' },
          '402': { description: 'Insufficient credits' },
          '429': { description: 'Rate limited — respect Retry-After header' },
        },
      },
    },
    '/summarize': {
      post: {
        summary: 'Summarize text (1 credit)',
        security: bearerSecurity,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['text'],
                properties: {
                  text: { type: 'string', maxLength: 100000 },
                  length: { type: 'string', enum: ['short', 'medium', 'long'], default: 'medium' },
                  language: { type: 'string', example: 'English' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Summary',
            content: {
              'application/json': {
                schema: envelope({ type: 'object', properties: { summary: { type: 'string' }, credits } }),
              },
            },
          },
        },
      },
    },
    '/translate': {
      post: {
        summary: 'Translate text (1 credit)',
        security: bearerSecurity,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['text', 'to'],
                properties: {
                  text: { type: 'string', maxLength: 100000 },
                  to: { type: 'string', example: 'Hindi' },
                  from: { type: 'string', example: 'English' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Translation',
            content: {
              'application/json': {
                schema: envelope({
                  type: 'object',
                  properties: { translation: { type: 'string' }, to: { type: 'string' }, credits },
                }),
              },
            },
          },
        },
      },
    },
    '/write': {
      post: {
        summary: 'Generate content from a brief (1 credit)',
        security: bearerSecurity,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['brief'],
                properties: {
                  brief: { type: 'string', maxLength: 20000 },
                  tone: { type: 'string', default: 'professional' },
                  format: { type: 'string', default: 'article', example: 'blog post' },
                  words: { type: 'integer', minimum: 50, maximum: 3000, default: 300 },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Content',
            content: {
              'application/json': {
                schema: envelope({ type: 'object', properties: { content: { type: 'string' }, credits } }),
              },
            },
          },
        },
      },
    },
    '/qr': {
      post: {
        summary: 'Generate a QR code (free)',
        security: bearerSecurity,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['text'],
                properties: {
                  text: { type: 'string' },
                  size: { type: 'integer', minimum: 64, maximum: 2048, default: 512 },
                  format: { type: 'string', enum: ['png', 'svg'], default: 'png' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'QR image',
            content: {
              'application/json': {
                schema: envelope({ type: 'object', properties: { dataUrl: { type: 'string' } } }),
              },
            },
          },
        },
      },
    },
    '/hash': {
      post: {
        summary: 'Hash text (free)',
        security: bearerSecurity,
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['text'],
                properties: {
                  text: { type: 'string', maxLength: 1000000 },
                  algorithm: { type: 'string', enum: ['md5', 'sha1', 'sha256', 'sha512'], default: 'sha256' },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Hash',
            content: {
              'application/json': {
                schema: envelope({
                  type: 'object',
                  properties: { algorithm: { type: 'string' }, hash: { type: 'string' } },
                }),
              },
            },
          },
        },
      },
    },
    '/uuid': {
      get: {
        summary: 'Generate UUID v4s (free)',
        security: bearerSecurity,
        parameters: [
          { name: 'count', in: 'query', schema: { type: 'integer', minimum: 1, maximum: 100, default: 1 } },
        ],
        responses: {
          '200': {
            description: 'UUIDs',
            content: {
              'application/json': {
                schema: envelope({
                  type: 'object',
                  properties: { uuids: { type: 'array', items: { type: 'string' } } },
                }),
              },
            },
          },
        },
      },
    },
    '/me': {
      get: {
        summary: 'API key info + credit balance (free)',
        security: bearerSecurity,
        responses: { '200': { description: 'Account info' } },
      },
    },
    '/usage': {
      get: {
        summary: 'Last 100 API calls (free)',
        security: bearerSecurity,
        responses: { '200': { description: 'Usage ledger' } },
      },
    },
  },
} as const;

/** GET /api/v1/openapi.json — OpenAPI 3.0 for Farvixo API Architecture v3. */
export async function GET() {
  return NextResponse.json(spec, {
    headers: { 'Cache-Control': 'public, max-age=3600' },
  });
}
