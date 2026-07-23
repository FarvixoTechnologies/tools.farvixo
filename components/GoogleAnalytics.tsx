import Script from 'next/script';

const GA_ID = process.env.NEXT_PUBLIC_GA_ID;

/**
 * Google Analytics 4 hook — activates only when NEXT_PUBLIC_GA_ID is set and in
 * production. Loads gtag.js after hydration (no impact on LCP/INP) with IP
 * anonymisation. Complements the existing Firebase + Clarity analytics.
 */
export default function GoogleAnalytics() {
  if (!GA_ID || process.env.NODE_ENV !== 'production') return null;
  return (
    <>
      <Script src={`https://www.googletagmanager.com/gtag/js?id=${GA_ID}`} strategy="afterInteractive" />
      <Script id="ga4-init" strategy="afterInteractive">
        {`window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${GA_ID}',{anonymize_ip:true});`}
      </Script>
    </>
  );
}
