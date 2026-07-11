'use client';

/**
 * ─────────────────────────────────────────────────────────────
 * Universal Scroll & Step-Transition Engine
 * ─────────────────────────────────────────────────────────────
 * Enterprise scroll UX shared by every tool module:
 *  • Scroll reset on every step transition (Upload → Processing →
 *    Preview → Download → Success → Start Again / Retry / Error)
 *  • Scroll reset on every route change (incl. back/forward)
 *  • Sticky-header safe-area offset (auto-measured, never hardcoded)
 *  • Internal scroll-container reset (PDF/image/text previews, logs…)
 *  • Auto-focus of first interactive element (a11y)
 *  • Respects prefers-reduced-motion; instant on touch devices
 *  • rAF-batched — no forced reflow, no scroll jank, no CLS
 */

import { useEffect, useRef } from 'react';

/* ─────────── Environment helpers ─────────── */

const isBrowser = () => typeof window !== 'undefined';

export function prefersReducedMotion(): boolean {
  return isBrowser() && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/** Touch / mobile → instant jump (per UX spec); desktop → smooth. */
function isTouchLike(): boolean {
  return (
    isBrowser() &&
    (window.matchMedia('(pointer: coarse)').matches || window.innerWidth < 768)
  );
}

export function scrollBehavior(): ScrollBehavior {
  return prefersReducedMotion() || isTouchLike() ? 'auto' : 'smooth';
}

/**
 * Scrolls the window to `top`. Because the stylesheet sets
 * `html { scroll-behavior: smooth }`, `behavior: 'auto'` would still
 * animate — so for instant jumps we temporarily override the CSS,
 * jump, and restore it on the next frame.
 */
function performWindowScroll(top: number, behavior: ScrollBehavior): void {
  if (behavior === 'smooth') {
    window.scrollTo({ top, left: 0, behavior: 'smooth' });
    return;
  }
  const root = document.documentElement;
  const previous = root.style.scrollBehavior;
  root.style.scrollBehavior = 'auto';
  window.scrollTo(0, top);
  requestAnimationFrame(() => {
    root.style.scrollBehavior = previous;
  });
}

/* ─────────── Sticky-header safe area ─────────── */

/**
 * Measures the real sticky header height (plus iOS safe-area inset and
 * breathing room) and publishes it as the --header-offset CSS variable
 * used by scroll-padding-top / scroll-margin-top.
 */
export function measureHeaderOffset(): number {
  if (!isBrowser()) return 84;
  const header = document.querySelector<HTMLElement>('.header');
  const h = header ? header.getBoundingClientRect().height : 72;
  const offset = Math.round(h) + 12; // 12px breathing room below the header
  document.documentElement.style.setProperty('--header-offset', `${offset}px`);
  return offset;
}

/* ─────────── Internal scroll containers ─────────── */

/**
 * Resets every internal scrollable region inside `root` back to its
 * origin — PDF/image/video previews, OCR output, editors, tables,
 * code panes, logs, chat panes, history lists.
 */
export function resetInnerScroll(root: ParentNode = document): void {
  if (!isBrowser()) return;
  const nodes = root.querySelectorAll<HTMLElement>('*');
  for (const el of nodes) {
    if (el.scrollTop !== 0 || el.scrollLeft !== 0) {
      if (el.scrollHeight > el.clientHeight || el.scrollWidth > el.clientWidth) {
        el.scrollTop = 0;
        el.scrollLeft = 0;
      }
    }
  }
}

/* ─────────── Auto-focus (accessibility) ─────────── */

const FOCUSABLE =
  'button:not([disabled]):not([aria-hidden="true"]), a[href], input:not([disabled]):not([type="hidden"]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** Focus the first interactive element without triggering extra scrolling. */
export function focusFirstInteractive(root: ParentNode = document): void {
  if (!isBrowser()) return;
  const el = root.querySelector<HTMLElement>(FOCUSABLE);
  if (!el) return;
  try {
    el.focus({ preventScroll: true });
  } catch {
    /* older browsers without preventScroll */
  }
}

/* ─────────── Core: scroll a step/page to top ─────────── */

export interface StepScrollOptions {
  /** Element (or selector) that anchors the new step; defaults to the tool workspace. */
  anchor?: HTMLElement | string | null;
  /** Also focus the first interactive element after settling. Default true. */
  focus?: boolean;
  /** Force instant jump regardless of platform. */
  instant?: boolean;
}

let pendingFrame = 0;

/**
 * Scrolls the viewport so the new step starts at the top (below the
 * sticky header — never hidden behind it), resets internal scroll
 * containers, and moves focus to the first interactive element.
 *
 * Double-rAF ensures the new step has painted before measuring, which
 * avoids forced layout recalculation and mid-render jumps.
 */
export function scrollStepToTop(opts: StepScrollOptions = {}): void {
  if (!isBrowser()) return;
  if (pendingFrame) cancelAnimationFrame(pendingFrame);

  pendingFrame = requestAnimationFrame(() => {
    pendingFrame = requestAnimationFrame(() => {
      pendingFrame = 0;
      const offset = measureHeaderOffset();

      let anchor: HTMLElement | null = null;
      if (typeof opts.anchor === 'string') {
        anchor = document.querySelector<HTMLElement>(opts.anchor);
      } else if (opts.anchor instanceof HTMLElement) {
        anchor = opts.anchor;
      }
      if (!anchor) {
        anchor =
          document.querySelector<HTMLElement>('.tool-workspace') ??
          document.querySelector<HTMLElement>('.workspace');
      }

      let top = 0;
      if (anchor) {
        top = Math.max(0, anchor.getBoundingClientRect().top + window.scrollY - offset);
      }

      const behavior: ScrollBehavior = opts.instant ? 'auto' : scrollBehavior();
      performWindowScroll(top, behavior);

      // Reset internal scrollbars inside the step (previews, editors, logs…)
      resetInnerScroll(anchor ?? document);

      // Premium entrance: re-trigger the fade/rise animation on the
      // workspace so EVERY runner's step screens feel like a new page —
      // even ones with fully custom markup. Reduced-motion users get no
      // animation (handled in CSS).
      if (anchor) {
        anchor.classList.remove('step-transition');
        void anchor.offsetWidth; // restart the CSS animation
        anchor.classList.add('step-transition');
      }

      if (opts.focus !== false) {
        // Focus after the (max 250ms) smooth scroll settles.
        const delay = behavior === 'smooth' ? 260 : 0;
        window.setTimeout(() => focusFirstInteractive(anchor ?? document), delay);
      }
    });
  });
}

/** Full page reset — used on route change / browser back / forward. */
export function scrollPageToTop(instant = false): void {
  if (!isBrowser()) return;
  requestAnimationFrame(() => {
    performWindowScroll(0, instant ? 'auto' : scrollBehavior());
  });
}

/* ─────────── Browser scroll-restoration guard ─────────── */

/**
 * Prevents Chrome/Safari/Android from restoring a stale scroll position
 * on refresh, back, and forward — every page open starts from the top.
 */
export function installScrollRestorationGuard(): void {
  if (!isBrowser() || !('scrollRestoration' in window.history)) return;
  try {
    window.history.scrollRestoration = 'manual';
  } catch {
    /* some embedded webviews throw */
  }
}

/* ─────────── React hook: step-transition scroll reset ─────────── */

/**
 * Watches a tool's phase/step value and performs the full premium
 * transition (scroll top → inner reset → focus) on every change.
 * Skips the initial mount so page load position is untouched.
 */
export function useStepScrollReset(step: string | number, options?: Omit<StepScrollOptions, 'anchor'>): void {
  const mounted = useRef(false);
  const prev = useRef(step);

  useEffect(() => {
    if (!mounted.current) {
      mounted.current = true;
      prev.current = step;
      return;
    }
    if (prev.current === step) return;
    prev.current = step;
    scrollStepToTop(options);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [step]);
}
