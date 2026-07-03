import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="container" style={{ padding: '96px 24px', textAlign: 'center' }}>
      <h1 style={{ fontSize: 64, marginBottom: 8 }} className="gradient-text">404</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: 24 }}>This tool flew off into deep space. Let&apos;s get you back.</p>
      <Link href="/tools" className="btn btn-primary">Browse all 120+ tools</Link>
    </div>
  );
}
