import Link from 'next/link';

export interface Crumb {
  name: string;
  /** Omit on the current (last) page. */
  href?: string;
}

/**
 * Presentational, accessible breadcrumb trail.
 *
 * Structured data is emitted centrally via `breadcrumbJsonLd` in `lib/seo.ts`
 * (inside the page's single JSON-LD graph), so this component stays visual +
 * a11y only — no duplicate BreadcrumbList schema on the page.
 */
export default function Breadcrumb({ items }: { items: Crumb[] }) {
  return (
    <nav className="breadcrumb" aria-label="Breadcrumb">
      {items.map((c, i) => {
        const isLast = i === items.length - 1;
        return (
          <span key={c.name} className="breadcrumb-seg">
            {i > 0 && <span className="breadcrumb-sep" aria-hidden="true"> / </span>}
            {c.href && !isLast ? (
              <Link href={c.href}>{c.name}</Link>
            ) : (
              <span aria-current={isLast ? 'page' : undefined}>{c.name}</span>
            )}
          </span>
        );
      })}
    </nav>
  );
}
