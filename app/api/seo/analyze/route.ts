import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

function ok(data: unknown) {
  return NextResponse.json({ success: true, data, error: null, meta: { requestId: crypto.randomUUID(), timestamp: new Date().toISOString() } });
}
function err(message: string, status = 400) {
  return NextResponse.json({ success: false, data: null, error: message }, { status });
}

export async function GET(req: NextRequest) {
  const url = req.nextUrl.searchParams.get('url');
  if (!url) return err('Missing url parameter');
  let target: URL;
  try {
    target = new URL(url.startsWith('http') ? url : `https://${url}`);
  } catch {
    return err('Invalid URL');
  }
  if (!['http:', 'https:'].includes(target.protocol)) return err('Only http/https URLs are supported');

  try {
    const t0 = Date.now();
    const res = await fetch(target.toString(), {
      redirect: 'follow',
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; FarvixoBot/1.0; +https://tools.farvixo.com)' },
      signal: AbortSignal.timeout(15000),
    });
    const ms = Date.now() - t0;
    const html = (await res.text()).slice(0, 500_000);

    const pick = (re: RegExp) => (html.match(re)?.[1] || '').replace(/\s+/g, ' ').trim();
    const title = pick(/<title[^>]*>([\s\S]*?)<\/title>/i);
    const desc = pick(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']*)["']/i) || pick(/<meta[^>]+content=["']([^"']*)["'][^>]+name=["']description["']/i);
    const canonical = pick(/<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']*)["']/i);
    const ogTitle = pick(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']*)["']/i);
    const ogImage = pick(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']*)["']/i);
    const viewport = pick(/<meta[^>]+name=["']viewport["'][^>]+content=["']([^"']*)["']/i);
    const h1s = html.match(/<h1[^>]*>/gi)?.length || 0;
    const imgs = html.match(/<img[^>]*>/gi) || [];
    const imgsNoAlt = imgs.filter((i) => !/alt=["'][^"']+["']/i.test(i)).length;
    const hasSchema = /application\/ld\+json/i.test(html);
    const wordCount = html.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>|<[^>]+>/g, ' ').split(/\s+/).filter(Boolean).length;

    const checks: string[] = [];
    const c = (pass: boolean, good: string, bad: string) => checks.push(`${pass ? '✅' : '❌'} ${pass ? good : bad}`);
    c(res.ok, `HTTP ${res.status} OK`, `HTTP ${res.status} — page returned an error`);
    c(target.protocol === 'https:', 'HTTPS enabled', 'Not using HTTPS');
    c(!!title, `Title present (${title.length} chars)${title.length > 60 ? ' — a bit long (>60)' : ''}`, 'Missing <title>');
    c(!!desc, `Meta description present (${desc.length} chars)${desc.length > 160 ? ' — too long (>160)' : ''}`, 'Missing meta description');
    c(h1s === 1, 'Exactly one H1 heading', h1s === 0 ? 'No H1 heading found' : `${h1s} H1 headings (should be 1)`);
    c(!!canonical, 'Canonical URL set', 'No canonical URL');
    c(!!viewport, 'Mobile viewport meta set', 'Missing viewport meta (mobile-unfriendly)');
    c(!!ogTitle, 'Open Graph tags present', 'Missing Open Graph tags');
    c(hasSchema, 'Structured data (JSON-LD) found', 'No structured data (JSON-LD)');
    c(imgsNoAlt === 0, `All ${imgs.length} images have alt text`, `${imgsNoAlt} of ${imgs.length} images missing alt text`);
    c(ms < 1500, `Server response in ${ms}ms`, `Slow server response: ${ms}ms`);
    c(wordCount > 300, `Content length: ~${wordCount} words`, `Thin content: only ~${wordCount} words`);

    const score = Math.round((checks.filter((x) => x.startsWith('✅')).length / checks.length) * 100);
    const report = [
      `SEO AUDIT — ${target.hostname}`,
      `Score: ${score}/100`,
      '',
      `Title: ${title || '(none)'}`,
      `Description: ${desc || '(none)'}`,
      ogImage ? `OG Image: ${ogImage}` : '',
      '',
      ...checks,
    ].filter((l) => l !== undefined).join('\n');

    return ok({ report, score });
  } catch (e) {
    return err(`Could not fetch that URL: ${e instanceof Error ? e.message : 'unknown error'}`, 502);
  }
}
