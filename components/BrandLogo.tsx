'use client';

import { useId } from 'react';

type Variant = 'logo' | 'wordmark' | 'lockup';

interface BrandLogoProps {
  variant: Variant;
  alt: string;
  className?: string;
  width?: number;
  height?: number;
  priority?: boolean;
}

/** Path to the final Farvixo brand mark (regenerated from the official logo). */
const MARK_SRC = '/farvixo-logo.png';

const RAINBOW: Array<[string, string]> = [
  ['0', '#7C3AED'],
  ['0.18', '#EC4899'],
  ['0.36', '#F97316'],
  ['0.52', '#F59E0B'],
  ['0.68', '#22C55E'],
  ['0.84', '#06B6D4'],
  ['1', '#3B82F6'],
];

function rainbowGradient(gid: string, x2: number) {
  return (
    <linearGradient id={`${gid}-rw`} x1="8" y1="0" x2={x2} y2="0" gradientUnits="userSpaceOnUse">
      {RAINBOW.map(([o, c]) => (
        <stop key={o} offset={o} stopColor={c} />
      ))}
    </linearGradient>
  );
}

/**
 * Farvixo brand asset.
 *
 * - `logo` / `lockup` render the final raster brand mark (the official gold
 *   crowned "F"). Kept as a plain <img> so it inherits the caller's className
 *   for responsive sizing without any Next/Image domain config.
 * - `wordmark` is the "FARVIXO" text logotype, drawn inline (never 404s,
 *   crisp at any size) — used as the header/footer text label next to the mark.
 */
export default function BrandLogo({ variant, alt, className, width, height, priority }: BrandLogoProps) {
  const gid = useId().replace(/[:]/g, '');

  if (variant === 'wordmark') {
    return (
      <svg
        className={className}
        role="img"
        aria-label={alt}
        xmlns="http://www.w3.org/2000/svg"
        width={width}
        height={height}
        viewBox="0 0 222 58"
        fill="none"
        preserveAspectRatio="xMinYMid meet"
      >
        <defs>{rainbowGradient(gid, 216)}</defs>
        <text
          x="2"
          y="45"
          textAnchor="start"
          fontFamily="'Sora','Segoe UI',Arial,sans-serif"
          fontWeight="800"
          fontSize="46"
          letterSpacing="2"
          fill={`url(#${gid}-rw)`}
        >
          FARVIXO
        </text>
      </svg>
    );
  }

  if (variant === 'lockup') {
    // Stacked brand: final mark above the "Build Beyond." tagline.
    return (
      <span
        className={className}
        role="img"
        aria-label={alt}
        style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}
      >
        <img
          src={MARK_SRC}
          alt=""
          width={width ?? 96}
          height={width ?? 96}
          style={{ width: '60%', height: 'auto', maxWidth: 120, borderRadius: 20 }}
          {...(priority ? { fetchPriority: 'high' } : { loading: 'lazy' })}
        />
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width={width ?? 200}
          height={40}
          viewBox="0 0 222 58"
          fill="none"
          preserveAspectRatio="xMidYMid meet"
          aria-hidden="true"
        >
          <defs>{rainbowGradient(gid, 216)}</defs>
          <text
            x="111"
            y="45"
            textAnchor="middle"
            fontFamily="'Sora','Segoe UI',Arial,sans-serif"
            fontWeight="800"
            fontSize="46"
            letterSpacing="2"
            fill={`url(#${gid}-rw)`}
          >
            FARVIXO
          </text>
        </svg>
      </span>
    );
  }

  // variant === 'logo' — the pictorial mark.
  return (
    <img
      src={MARK_SRC}
      alt={alt}
      className={className}
      width={width}
      height={height}
      {...(priority ? { fetchPriority: 'high' } : { loading: 'lazy' })}
    />
  );
}
