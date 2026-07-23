import Breadcrumb, { type Crumb } from '@/components/Breadcrumb';

interface PageShellProps {
  title: string;
  subtitle?: string;
  children: React.ReactNode;
  /** Override the default "Home / {title}" trail (e.g. blog posts). */
  breadcrumb?: Crumb[];
  /** Optional JSON-LD graph(s) injected once, centrally, for this page. */
  jsonLd?: object | object[];
}

export default function PageShell({ title, subtitle, children, breadcrumb, jsonLd }: PageShellProps) {
  const crumbs: Crumb[] = breadcrumb ?? [{ name: 'Home', href: '/' }, { name: title }];
  const graphs = jsonLd ? (Array.isArray(jsonLd) ? jsonLd : [jsonLd]) : [];
  return (
    <div className="container static-page">
      {graphs.map((g, i) => (
        <script key={i} type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(g) }} />
      ))}
      <Breadcrumb items={crumbs} />
      <header className="static-header">
        <h1>{title}</h1>
        {subtitle && <p className="static-sub">{subtitle}</p>}
      </header>
      <article className="static-body glass">{children}</article>
    </div>
  );
}
