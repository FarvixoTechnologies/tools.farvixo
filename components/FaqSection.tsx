import type { Faq } from '@/lib/seo';

/**
 * Presentational FAQ accordion using semantic <details>/<summary> (crawlable,
 * keyboard-accessible, no JS required).
 *
 * The FAQPage structured data is emitted centrally via `toolJsonLd` in
 * `lib/seo.ts`, so this component carries no duplicate JSON-LD — it renders the
 * on-page, human-readable version that mirrors the schema.
 */
export default function FaqSection({
  items,
  heading = 'Frequently Asked Questions',
}: {
  items: Faq[];
  heading?: string;
}) {
  if (items.length === 0) return null;
  return (
    <section className="faq" aria-label={heading}>
      <h2>{heading}</h2>
      {items.map((f) => (
        <details key={f.q} className="faq-item">
          <summary>{f.q}</summary>
          <p>{f.a}</p>
        </details>
      ))}
    </section>
  );
}
