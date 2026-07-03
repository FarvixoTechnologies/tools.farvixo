'use client';

import { useEffect, useRef, useState } from 'react';
import Icon from '../Icon';

const stats = [
  { icon: 'users', value: 25, suffix: 'M+', label: 'Happy Users', color: 'var(--brand-primary)' },
  { icon: 'grid', value: 120, suffix: '+', label: 'Powerful Tools', color: 'var(--accent-ai)' },
  { icon: 'shield-check', value: 99.9, suffix: '%', label: 'Uptime', color: 'var(--success-green)', decimals: 1 },
  { icon: 'check-circle', value: 50, suffix: 'M+', label: 'Tasks Completed', color: 'var(--accent-dev)' },
  { icon: 'globe', value: 150, suffix: '+', label: 'Countries', color: 'var(--accent-calculator)' },
  { icon: 'lock', value: 100, suffix: '%', label: 'Secure & Private', color: 'var(--gold-premium)' },
];

function CountUp({ target, suffix, decimals = 0 }: { target: number; suffix: string; decimals?: number }) {
  const [val, setVal] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const started = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !started.current) {
          started.current = true;
          const t0 = performance.now();
          const dur = 1200;
          const tick = (t: number) => {
            const p = Math.min((t - t0) / dur, 1);
            const eased = 1 - Math.pow(1 - p, 3);
            setVal(target * eased);
            if (p < 1) requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
        }
      },
      { threshold: 0.4 },
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [target]);

  return <span ref={ref}>{val.toFixed(decimals)}{suffix}</span>;
}

export default function StatsBar() {
  return (
    <div className="container">
      <div className="stats-bar glass">
        {stats.map((s) => (
          <div key={s.label} className="stat">
            <span className="stat-icon" style={{ background: 'color-mix(in srgb, ' + s.color + ' 15%, transparent)', color: s.color }}>
              <Icon name={s.icon} size={20} />
            </span>
            <span className="stat-value"><CountUp target={s.value} suffix={s.suffix} decimals={s.decimals || 0} /></span>
            <span className="stat-label">{s.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
