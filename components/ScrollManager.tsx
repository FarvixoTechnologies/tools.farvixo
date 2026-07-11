'use client';

import { useEffect, useRef } from 'react';
import { usePathname } from 'next/navigation';
import {
  installScrollRestorationGuard,
  measureHeaderOffset,
  resetInnerScroll,
  scrollPageToTop,
} from '@/lib/scroll-engine';

/**
 * Global scroll UX manager (mounted once in the root layout).
 *
 *  • Disables browser scroll restoration (Chrome scroll memory,
 *    Safari position cache) so back/forward/refresh start at top.
 *  • Resets the viewport to Y=0 on every route change.
 *  • Keeps the --header-offset CSS var in sync with the real sticky
 *    header height (safe-area aware, updates on resize/orientation).
 */
export default function ScrollManager() {
  const pathname = usePathname();
  const firstRender = useRef(true);

  // One-time setup
  useEffect(() => {
    installScrollRestorationGuard();
    measureHeaderOffset();

    const onResize = () => measureHeaderOffset();
    window.addEventListener('resize', onResize);
    window.addEventListener('orientationchange', onResize);

    // Header becomes stronger glass once the page scrolls (rAF throttled)
    let raf = 0;
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        document.documentElement.toggleAttribute('data-scrolled', window.scrollY > 8);
      });
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    // Browser back/forward → always top (mobile back included).
    // In-page anchor targets (#hash) keep native behavior.
    const onPop = () => {
      if (window.location.hash) return;
      scrollPageToTop(true);
      resetInnerScroll(document);
    };
    window.addEventListener('popstate', onPop);

    return () => {
      window.removeEventListener('resize', onResize);
      window.removeEventListener('orientationchange', onResize);
      window.removeEventListener('popstate', onPop);
      window.removeEventListener('scroll', onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);

  // Route change → new page always opens from the top
  useEffect(() => {
    if (firstRender.current) {
      firstRender.current = false;
      // Initial load: guard against restored positions after refresh,
      // but honor explicit #anchor deep links.
      if (!window.location.hash) scrollPageToTop(true);
      return;
    }
    if (!window.location.hash) {
      scrollPageToTop(true);
      resetInnerScroll(document);
    }
  }, [pathname]);

  return null;
}
