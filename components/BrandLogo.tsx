'use client';

import { useEffect, useId, useState } from 'react';

type Variant = 'logo' | 'wordmark' | 'lockup';

interface BrandLogoProps {
  variant: Variant;
  alt: string;
  className?: string;
  width?: number;
  height?: number;
  priority?: boolean;
}

const RAINBOW: Array<[string, string]> = [
  ['0', '#7C3AED'],
  ['0.18', '#EC4899'],
  ['0.36', '#F97316'],
  ['0.52', '#F59E0B'],
  ['0.68', '#22C55E'],
  ['0.84', '#06B6D4'],
  ['1', '#3B82F6'],
];

// Rainbow ring: 12 arc segments around a circle (cx=cy=128, r=116), clockwise from top.
const RING: Array<[string, string, string]> = [
  ['128 12', '186 27.5', '#E24BAF'],
  ['186 27.5', '228.5 70', '#EF4444'],
  ['228.5 70', '244 128', '#F97316'],
  ['244 128', '228.5 186', '#F59E0B'],
  ['228.5 186', '186 228.5', '#84CC16'],
  ['186 228.5', '128 244', '#22C55E'],
  ['128 244', '70 228.5', '#10B981'],
  ['70 228.5', '27.5 186', '#06B6D4'],
  ['27.5 186', '12 128', '#22A7F0'],
  ['12 128', '27.5 70', '#3B82F6'],
  ['27.5 70', '70 27.5', '#6C4DFF'],
  ['70 27.5', '128 12', '#A855F7'],
];

function Ring() {
  return (
    <g fill="none" strokeWidth="6" strokeLinecap="round">
      {RING.map(([from, to, color]) => (
        <path key={from + color} d={`M${from} A116 116 0 0 1 ${to}`} stroke={color} />
      ))}
    </g>
  );
}

/** The gradient "F" ribbon mark, drawn inline (never 404s). */
function Mark({ gid }: { gid: string }) {
  return (
    <g transform="skewX(-8) translate(18 0)">
      <rect x="82" y="52" width="46" height="156" rx="18" fill={`url(#${gid}-stem)`} />
      <rect x="82" y="52" width="122" height="46" rx="18" fill={`url(#${gid}-wing)`} />
      <rect x="82" y="112" width="88" height="42" rx="18" fill={`url(#${gid}-wing2)`} />
      <rect x="96" y="60" width="94" height="12" rx="6" fill="#FFFFFF" opacity="0.22" />
      <path d="M92 150 L120 150 L104 176 Z" fill="#FFFFFF" opacity="0.9" />
    </g>
  );
}

function markGradients(gid: string) {
  return (
    <>
      {/* top arm — red */}
      <linearGradient id={`${gid}-wing`} x1="70" y1="52" x2="210" y2="100" gradientUnits="userSpaceOnUse">
        <stop offset="0" stopColor="#F43F5E" />
        <stop offset="1" stopColor="#EF4444" />
      </linearGradient>
      {/* middle arm — yellow */}
      <linearGradient id={`${gid}-wing2`} x1="82" y1="112" x2="180" y2="154" gradientUnits="userSpaceOnUse">
        <stop offset="0" stopColor="#FACC15" />
        <stop offset="1" stopColor="#F59E0B" />
      </linearGradient>
      {/* stem / tail — blue */}
      <linearGradient id={`${gid}-stem`} x1="100" y1="52" x2="120" y2="208" gradientUnits="userSpaceOnUse">
        <stop offset="0" stopColor="#3B82F6" />
        <stop offset="1" stopColor="#2563EB" />
      </linearGradient>
    </>
  );
}

function rainbowGradient(gid: string, x2: number) {
  return (
    <linearGradient id={`${gid}-rw`} x1="8" y1="0" x2={x2} y2="0" gradientUnits="userSpaceOnUse">
      {RAINBOW.map(([o, c]) => (
        <stop key={o} offset={o} stopColor={c} />
      ))}
    </linearGradient>
  );
}

function InlineLogo({ variant, alt, className, width, height }: Omit<BrandLogoProps, 'priority'>) {
  const gid = useId().replace(/[:]/g, '');
  const common = { className, role: 'img' as const, 'aria-label': alt, xmlns: 'http://www.w3.org/2000/svg' };

  if (variant === 'logo') {
    return (
      <svg {...common} width={width} height={height} viewBox="0 0 256 256" fill="none">
        <defs>{markGradients(gid)}</defs>
        <Ring />
        <g transform="translate(40 46) scale(0.62)">
          <Mark gid={gid} />
        </g>
      </svg>
    );
  }

  if (variant === 'wordmark') {
    return (
      <svg {...common} width={width} height={height} viewBox="0 0 222 58" fill="none" preserveAspectRatio="xMinYMid meet">
        <defs>{rainbowGradient(gid, 216)}</defs>
        <text x="2" y="45" textAnchor="start" fontFamily="'Sora','Segoe UI',Arial,sans-serif" fontWeight="800" fontSize="46" letterSpacing="2" fill={`url(#${gid}-rw)`}>FARVIXO</text>
      </svg>
    );
  }

  // lockup: mark + wordmark + tagline
  return (
    <svg {...common} width={width} height={height} viewBox="0 0 360 240" fill="none">
      <defs>
        {markGradients(gid)}
        {rainbowGradient(gid, 290)}
      </defs>
      <g transform="translate(118 6) scale(0.62)">
        <Mark gid={gid} />
      </g>
      <text x="180" y="192" textAnchor="middle" fontFamily="'Sora','Segoe UI',Arial,sans-serif" fontWeight="800" fontSize="46" letterSpacing="4" fill={`url(#${gid}-rw)`}>FARVIXO</text>
      <line x1="96" y1="214" x2="126" y2="214" stroke={`url(#${gid}-rw)`} strokeWidth="2" />
      <text x="180" y="219" textAnchor="middle" fontFamily="'Sora','Segoe UI',Arial,sans-serif" fontWeight="600" fontSize="13" letterSpacing="4" fill="#A0A0B8">BUILD BEYOND.</text>
      <line x1="234" y1="214" x2="264" y2="214" stroke={`url(#${gid}-rw)`} strokeWidth="2" />
    </svg>
  );
}

/**
 * Farvixo brand asset. Renders an inline SVG by default (so it can never
 * 404 or show a broken-image icon), and transparently upgrades to the real
 * raster art at `/farvixo-<variant>.png` if that file exists in /public.
 */
export default function BrandLogo({ variant, alt, className, width, height }: BrandLogoProps) {
  const [pngSrc, setPngSrc] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    const probe = new window.Image();
    probe.onload = () => { if (alive) setPngSrc(`/farvixo-${variant}.png`); };
    probe.src = `/farvixo-${variant}.png`;
    return () => { alive = false; };
  }, [variant]);

  if (pngSrc) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={pngSrc} alt={alt} className={className} width={width} height={height} />;
  }
  return <InlineLogo variant={variant} alt={alt} className={className} width={width} height={height} />;
}
