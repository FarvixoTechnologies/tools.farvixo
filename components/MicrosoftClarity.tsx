'use client';

import { useEffect } from 'react';

const CLARITY_PROJECT_ID = 'xnx60w8j6x';

/** Module-level guard — survives React Strict Mode remounts. */
let clarityInitialized = false;

/**
 * Microsoft Clarity — client-only, once per app lifetime, production only.
 */
export default function MicrosoftClarity() {
  useEffect(() => {
    if (clarityInitialized) return;
    if (process.env.NODE_ENV !== 'production') return;
    if (typeof window === 'undefined') return;

    clarityInitialized = true;

    void import('@microsoft/clarity')
      .then((mod) => {
        const clarity = mod.default ?? mod;
        clarity.init(CLARITY_PROJECT_ID);
      })
      .catch((err) => {
        console.warn('[clarity] init failed:', err);
        clarityInitialized = false;
      });
  }, []);

  return null;
}
