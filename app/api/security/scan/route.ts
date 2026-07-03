import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

const SUSPICIOUS_TLDS = ['zip', 'mov', 'tk', 'ml', 'ga', 'cf', 'gq', 'top', 'xyz'];
const PHISHY_WORDS = ['login', 'verify', 'secure', 'account', 'update', 'confirm', 'bank', 'wallet', 'signin', 'password'];

export async function GET(req: NextRequest) {
  const raw = req.nextUrl.searchParams.get('target') || '';
  let url: URL;
  try {
    url = new URL(raw.startsWith('http') ? raw : `https://${raw}`);
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid URL' }, { status: 400 });
  }

  const flags: string[] = [];
  const good: string[] = [];

  if (url.protocol !== 'https:') flags.push('Uses insecure HTTP (no encryption)');
  else good.push('Uses HTTPS');

  if (/^\d+\.\d+\.\d+\.\d+$/.test(url.hostname)) flags.push('Raw IP address instead of a domain — common in phishing');
  const tld = url.hostname.split('.').pop() || '';
  if (SUSPICIOUS_TLDS.includes(tld)) flags.push(`.${tld} TLD is frequently abused by spammers`);
  if (url.hostname.split('.').length > 4) flags.push('Deeply nested subdomains — often used to fake real brands');
  if (url.hostname.includes('xn--')) flags.push('Punycode domain — may be spoofing a real site with lookalike characters');
  if (url.href.length > 120) flags.push('Unusually long URL');
  if (url.username || url.password) flags.push('Credentials embedded in URL (user@host trick)');
  const phishyHits = PHISHY_WORDS.filter((w) => url.hostname.includes(w));
  if (phishyHits.length) flags.push(`Sensitive words in domain (${phishyHits.join(', ')}) — verify it's the official site`);
  if (/(bit\.ly|tinyurl|t\.co|goo\.gl|is\.gd|rb\.gy)/.test(url.hostname)) flags.push('URL shortener — final destination is hidden');

  // Reachability
  let reach = '';
  try {
    const res = await fetch(url.toString(), { method: 'HEAD', redirect: 'follow', signal: AbortSignal.timeout(8000) });
    reach = `Site responded: HTTP ${res.status}`;
    const finalHost = new URL(res.url).hostname;
    if (finalHost !== url.hostname) flags.push(`Redirects to a different domain: ${finalHost}`);
    else good.push('No cross-domain redirects');
  } catch {
    reach = 'Site did not respond to a quick check';
  }

  const verdict = flags.length === 0 ? '✅ No obvious red flags found' : flags.length <= 2 ? '⚠️ Some caution advised' : '🚨 Multiple red flags — treat as unsafe';
  const report = [
    `URL SAFETY SCAN — ${url.hostname}`,
    '',
    verdict,
    reach,
    '',
    ...good.map((g) => `✅ ${g}`),
    ...flags.map((f) => `⚠️ ${f}`),
    '',
    'Note: heuristic scan only — when in doubt, do not enter passwords or payment details.',
  ].join('\n');

  return NextResponse.json({ success: true, data: { report }, error: null });
}
