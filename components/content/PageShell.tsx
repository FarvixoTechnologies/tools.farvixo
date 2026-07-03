import Link from 'next/link';

interface PageShellProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
}

export default function PageShell({ title, subtitle, children }: PageShellProps) {
  return (
    <div className="container static-page">
      <nav className="breadcrumb" aria-label="Breadcrumb">
        <Link href="/">Home</Link> / <span>{title}</span>
      </nav>
      <header className="static-header">
        <h1>{title}</h1>
        {subtitle && <p className="static-sub">{subtitle}</p>}
      </header>
      <article className="static-body glass">{children}</article>
    </div>
  );
}
