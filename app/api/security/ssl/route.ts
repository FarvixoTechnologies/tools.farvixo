import { NextRequest, NextResponse } from 'next/server';
import tls from 'node:tls';

export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

export async function GET(req: NextRequest) {
  const raw = req.nextUrl.searchParams.get('target') || '';
  const host = raw.replace(/^https?:\/\//, '').split('/')[0].split(':')[0];
  if (!host || !/^[a-z0-9.-]+$/i.test(host)) {
    return NextResponse.json({ success: false, error: 'Invalid domain' }, { status: 400 });
  }

  try {
    const report = await new Promise<string>((resolve, reject) => {
      const socket = tls.connect({ host, port: 443, servername: host, timeout: 10000, rejectUnauthorized: false }, () => {
        const cert = socket.getPeerCertificate();
        const authorized = socket.authorized;
        const protocol = socket.getProtocol();
        const cipher = socket.getCipher();
        socket.end();
        if (!cert || !cert.valid_to) { reject(new Error('No certificate presented')); return; }
        const expires = new Date(cert.valid_to);
        const daysLeft = Math.round((expires.getTime() - Date.now()) / 86400000);
        const san = (cert.subjectaltname || '').replace(/DNS:/g, '');
        resolve([
          `SSL CERTIFICATE — ${host}`,
          '',
          `${authorized ? '✅ Certificate is VALID and trusted' : '⚠️ Certificate NOT trusted (self-signed or chain issue)'}`,
          `${daysLeft > 14 ? '✅' : '⚠️'} Expires: ${expires.toUTCString()} (${daysLeft} days left)`,
          `✅ Protocol: ${protocol}`,
          `✅ Cipher: ${cipher?.name}`,
          '',
          `Subject: ${cert.subject?.CN || '(unknown)'}`,
          `Issuer:  ${cert.issuer?.O || cert.issuer?.CN || '(unknown)'}`,
          `Valid from: ${new Date(cert.valid_from).toUTCString()}`,
          san ? `SANs: ${san}` : '',
        ].filter(Boolean).join('\n'));
      });
      socket.on('error', reject);
      socket.on('timeout', () => { socket.destroy(); reject(new Error('Connection timed out')); });
    });
    return NextResponse.json({ success: true, data: { report }, error: null });
  } catch (e) {
    return NextResponse.json({ success: false, error: `SSL check failed: ${e instanceof Error ? e.message : 'unknown'}` }, { status: 502 });
  }
}
