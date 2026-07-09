'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from 'react';
import Icon from '../Icon';
import { useUI } from '../GlobalUI';
import { searchTools, type Tool } from '@/data/tools';
import { getCategory } from '@/data/categories';
import { formatCount } from '@/lib/format-count';

const chipMap: Record<string, string> = {
  'PDF to Word': '/tools/pdf/pdf-to-word',
  'Image Compressor': '/tools/image/image-compressor',
  'Background Remover': '/tools/image/background-remover',
  'AI Chat': '/tools/ai/ai-chat',
  'Video Converter': '/tools/video/video-converter',
};

const orbitChips = [
  { icon: 'image', color: 'var(--accent-image)', style: { top: '-6%', left: '18%', animationDelay: '0s' } },
  { icon: 'bot', color: 'var(--accent-ai)', style: { top: '-12%', right: '12%', animationDelay: '0.5s' } },
  { icon: 'file-text', color: 'var(--accent-pdf)', style: { top: '22%', left: '-16%', animationDelay: '1s' } },
  { icon: 'code', color: 'var(--brand-primary)', style: { top: '18%', right: '-16%', animationDelay: '1.5s' } },
  { icon: 'video', color: 'var(--accent-dev)', style: { bottom: '18%', right: '-10%', animationDelay: '2s' } },
  { icon: 'music', color: 'var(--accent-audio)', style: { bottom: '4%', left: '-8%', animationDelay: '2.5s' } },
  { icon: 'type', color: 'var(--accent-dev)', style: { top: '42%', left: '-24%', animationDelay: '3s' } },
];

export default function Hero() {
  const { openAI, toast } = useUI();
  const router = useRouter();
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const wrapRef = useRef<HTMLDivElement>(null);
  const [stats, setStats] = useState<{ users: number; jobs: number } | null>(null);

  const matches = useMemo(() => (q.trim() ? searchTools(q.trim()) : []), [q]);
  const results = matches.slice(0, 6);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch('/api/stats/public');
        const json = (await res.json()) as { success: boolean; data?: { users: number | null; jobs: number | null } };
        if (!cancelled && json.success && typeof json.data?.users === 'number') {
          setStats({ users: json.data.users, jobs: json.data.jobs ?? 0 });
        }
      } catch { /* keep fallback text */ }
    })();
    return () => { cancelled = true; };
  }, []);

  const goTo = (t: Tool) => { setOpen(false); router.push(`/tools/${t.category}/${t.slug}`); };

  const viewAll = () => {
    const query = q.trim();
    if (!query) return;
    setOpen(false);
    router.push(`/tools?q=${encodeURIComponent(query)}`);
  };

  const search = () => {
    if (open && results[active]) return goTo(results[active]);
    if (matches.length > 0) return viewAll();
    if (q.trim()) toast(`No tools found for "${q.trim()}"`, 'error');
  };

  const onKeyDown = (e: ReactKeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setOpen(true); setActive((a) => Math.min(a + 1, results.length - 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)); }
    else if (e.key === 'Enter') { e.preventDefault(); search(); }
    else if (e.key === 'Escape') { setOpen(false); }
  };

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [open]);

  return (
    <section className="hero">
      <div className="container hero-grid">
        {/* Left */}
        <div className="hero-left">
          <span className="eyebrow"><Icon name="sparkles" size={14} /> Smart Tools Ecosystem</span>
          <h1 className="hero-h1">
            139+ Free<br />
            AI &amp; Productivity Tools<br />
            <span className="gradient-text">Build Beyond.</span>
          </h1>
          <p className="hero-sub">Everything you need. Fast. Private. Powered by Farvixo.</p>

          <div className="hero-search-wrap" ref={wrapRef}>
            <div className={`hero-search${open && q.trim() ? ' is-open' : ''}`} role="search">
              <Icon name="search" size={18} className="hero-search-lead" />
              <input
                value={q}
                placeholder="Search 139+ AI & Productivity Tools..."
                onChange={(e) => { setQ(e.target.value); setActive(0); setOpen(true); }}
                onFocus={() => { if (q.trim()) setOpen(true); }}
                onKeyDown={onKeyDown}
                aria-label="Search any tool"
                aria-expanded={open}
                aria-autocomplete="list"
                autoComplete="off"
              />
              {q && (
                <button className="hero-search-clear" onClick={() => { setQ(''); setOpen(false); }} aria-label="Clear search">
                  <Icon name="x" size={16} />
                </button>
              )}
              <button className="hero-search-btn" onClick={search} aria-label="Search"><Icon name="search" size={18} /></button>
            </div>

            {open && q.trim() && (
              <div className="hero-suggest" role="listbox">
                {results.length > 0 ? (
                  <>
                    {results.map((t, i) => {
                      const cat = getCategory(t.category);
                      const accent = `var(--${cat?.accent ?? 'brand-primary'})`;
                      return (
                        <button
                          key={t.slug}
                          type="button"
                          role="option"
                          aria-selected={i === active}
                          className={`hero-suggest-item${i === active ? ' active' : ''}`}
                          onMouseEnter={() => setActive(i)}
                          onClick={() => goTo(t)}
                        >
                          <span className="hero-suggest-icon" style={{ color: accent, background: `color-mix(in srgb, ${accent} 15%, transparent)` }}>
                            <Icon name={t.icon} size={17} />
                          </span>
                          <span className="hero-suggest-text">
                            <span className="hero-suggest-name">
                              {t.name}
                              {t.badge === 'new' && <span className="hs-badge hs-new">NEW</span>}
                              {t.badge === 'ai' && <span className="hs-badge hs-ai">AI</span>}
                              {t.badge === 'popular' && <span className="hs-badge hs-pop">Popular</span>}
                            </span>
                            <span className="hero-suggest-desc">{cat?.shortName ?? 'Tool'} · {t.description}</span>
                          </span>
                          <Icon name="arrow-right" size={15} className="hero-suggest-arrow" />
                        </button>
                      );
                    })}
                    <button type="button" className="hero-suggest-foot" onClick={viewAll}>
                      <Icon name="search" size={14} />
                      View all {matches.length} result{matches.length > 1 ? 's' : ''} for “{q.trim()}”
                    </button>
                  </>
                ) : (
                  <div className="hero-suggest-empty">
                    <Icon name="search" size={22} />
                    <p>No tools found for “{q.trim()}”</p>
                    <Link href="/tools" className="link-btn" onClick={() => setOpen(false)}>Browse all 139+ tools →</Link>
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="chips">
            {Object.entries(chipMap).map(([label, href]) => (
              <Link key={label} href={href} className="chip">{label}</Link>
            ))}
          </div>

          <div className="cta-row">
            <Link href="/tools" className="btn btn-primary">Explore All Tools <Icon name="arrow-right" size={16} /></Link>
            <button className="btn btn-outline" onClick={openAI}><Icon name="sparkles" size={15} /> Try AI Assistant</button>
          </div>

          <div className="social-proof">
            <div className="avatars">
              {['#6c4dff', '#a855f7', '#3b82f6', '#22c55e', '#f97316'].map((c, i) => (
                <span key={i} className="avatar-c" style={{ background: c }}>{'TNAFR'[i]}</span>
              ))}
            </div>
            <div>
              <div className="stars">★★★★★</div>
              <div className="proof-text">
                {stats
                  ? `Trusted by ${formatCount(stats.users)} users · ${formatCount(stats.jobs)} tool runs`
                  : 'Loved by our growing community'}
              </div>
            </div>
          </div>
        </div>

        {/* Center — cube */}
        <div className="hero-visual" aria-hidden="true">
          <div className="cube-glow" />
          <div className="cube-scene">
            <div className="cube-wrap">
              <div className="cube-face" style={{ transform: 'rotateY(0deg) translateZ(110px)' }} />
              <div className="cube-face" style={{ transform: 'rotateY(90deg) translateZ(110px)' }} />
              <div className="cube-face" style={{ transform: 'rotateY(180deg) translateZ(110px)' }} />
              <div className="cube-face" style={{ transform: 'rotateY(270deg) translateZ(110px)' }} />
              <div className="cube-face" style={{ transform: 'rotateX(90deg) translateZ(110px)' }} />
              <div className="cube-face" style={{ transform: 'rotateX(-90deg) translateZ(110px)' }} />
            </div>
            <div className="cube-core" />
            {orbitChips.map((c, i) => (
              <span key={i} className="orbit-chip" style={{ background: c.color, ...c.style }}>
                <Icon name={c.icon} size={22} />
              </span>
            ))}
          </div>
        </div>

        {/* Right — Why Farvixo */}
        <aside className="why-card glass">
          <span className="why-crown"><Icon name="crown" size={26} fill="var(--gold-premium)" strokeWidth={1.5} /></span>
          <h3>Why Farvixo?</h3>
          <ul className="why-list">
            {['139+ Powerful Tools', 'AI-Powered Features', 'Blazing Fast Processing', 'Secure & Private', 'Cloud Storage (100GB)', 'No Ads, Ever'].map((f) => (
              <li key={f}><span className="why-check"><Icon name="check" size={16} strokeWidth={3} /></span> {f}</li>
            ))}
          </ul>
          <button className="btn btn-gold w-full" onClick={() => toast('Pro upgrade coming soon — you already have PRO! 👑', 'success')}>
            <Icon name="crown" size={16} /> Upgrade to Pro
          </button>
          <p className="why-note">No credit card required</p>
        </aside>
      </div>
    </section>
  );
}
