import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const user = (req.nextUrl.searchParams.get('user') || '').replace(/[^a-zA-Z0-9._]/g, '');
  if (!user) return NextResponse.json({ success: false, error: 'Missing username' }, { status: 400 });

  try {
    const res = await fetch(`https://www.instagram.com/${user}/`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
        Accept: 'text/html',
      },
      signal: AbortSignal.timeout(10000),
    });
    const html = await res.text();
    const match =
      html.match(/"profile_pic_url_hd":"([^"]+)"/) ||
      html.match(/"profile_pic_url":"([^"]+)"/) ||
      html.match(/<meta property="og:image" content="([^"]+)"/);
    if (!match) {
      return NextResponse.json({ success: false, error: 'Could not find the profile photo — the profile may be private, or Instagram blocked the request. Try again in a minute.' }, { status: 404 });
    }
    const url = match[1].replace(/\\u0026/g, '&').replace(/\\\//g, '/');
    return NextResponse.json({ success: true, data: { url }, error: null });
  } catch {
    return NextResponse.json({ success: false, error: 'Instagram request failed — try again shortly.' }, { status: 502 });
  }
}
