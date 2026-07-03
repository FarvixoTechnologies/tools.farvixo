'use client';

import { AD_INVOKE_BASE } from '@/lib/ads/config';

interface HighPerformanceAdProps {
  adKey: string;
  width: number;
  height: number;
  className?: string;
}

// Adsterra's invoke.js relies on document.write and a global atOptions, so each
// unit must run in its own isolated document — a srcDoc iframe — otherwise
// multiple units on one page overwrite each other and render nothing.
export default function HighPerformanceAd({ adKey, width, height, className }: HighPerformanceAdProps) {
  const srcDoc = `<!doctype html><html><head><style>html,body{margin:0;padding:0;overflow:hidden;background:transparent}</style></head><body><script type="text/javascript">atOptions={'key':'${adKey}','format':'iframe','height':${height},'width':${width},'params':{}};</script><script type="text/javascript" src="${AD_INVOKE_BASE}/${adKey}/invoke.js"></script></body></html>`;

  return (
    <iframe
      title={`sponsored-${adKey}`}
      srcDoc={srcDoc}
      width={width}
      height={height}
      className={`ad-container ${className ?? ''}`}
      style={{ width, height, maxWidth: '100%', border: 0, overflow: 'hidden', display: 'block', margin: '0 auto' }}
      scrolling="no"
      sandbox="allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox"
      loading="lazy"
      data-ad-key={adKey}
    />
  );
}
