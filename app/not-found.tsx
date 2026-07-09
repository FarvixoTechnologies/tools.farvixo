import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="container" style={{ padding: '96px 24px', textAlign: 'center' }}>
      <h1 style={{ fontSize: 64, marginBottom: 8 }} className="gradient-text">404</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: 24 }}>Oops! The page you&apos;re looking for doesn&apos;t exist.</p>
      <Link href="/tools" className="btn btn-primary">Return to Farvixo Tools</Link>
    </div>
  );
}
