import { NextResponse } from 'next/server';

export const dynamic = 'force-static';

const BASE = process.env.NEXT_PUBLIC_APP_URL || 'https://tools.farvixo.com';

/**
 * GET /api/v1/docs — lightweight Swagger UI (CDN) over /api/v1/openapi.json
 */
export async function GET() {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>Farvixo API v1 — Docs</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui.css"/>
  <style>body{margin:0;background:#0a0a12} .topbar{display:none}</style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui-bundle.js"></script>
  <script>
    window.ui = SwaggerUIBundle({
      url: ${JSON.stringify(`${BASE}/api/v1/openapi.json`)},
      dom_id: '#swagger-ui',
      deepLinking: true,
      presets: [SwaggerUIBundle.presets.apis],
    });
  </script>
</body>
</html>`;

  return new NextResponse(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=300' },
  });
}
