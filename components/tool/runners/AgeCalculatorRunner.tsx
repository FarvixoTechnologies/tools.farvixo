'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Icon from '@/components/Icon';
import { downloadBlob } from '@/lib/download';
import {
  type AgeResult,
  calculateAge,
  parseDateInput,
  toDateInput,
  toTimeInput,
  formatNumber,
  formatDate,
  formatDateTime,
  buildReportText,
  buildShareUrl,
  generateAiSummary,
  POPULAR_DOB,
  STAT_THEMES,
  TAB_META,
  getMilestoneIcon,
} from '@/lib/engines/age-calculator-engine';

type Tab = 'results' | 'birthday' | 'astrology' | 'milestones' | 'stats' | 'ai';

function AnimatedNum({ value }: { value: number }) {
  const [display, setDisplay] = useState(value);
  const prev = useRef(value);
  useEffect(() => {
    const from = prev.current;
    const to = value;
    if (from === to) return;
    const start = performance.now();
    let raf = 0;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / 500);
      const eased = 1 - (1 - t) ** 3;
      setDisplay(Math.round(from + (to - from) * eased));
      if (t < 1) raf = requestAnimationFrame(tick);
      else prev.current = to;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value]);
  return <>{formatNumber(display)}</>;
}

function RingProgress({ pct, color, size = 88, label }: { pct: number; color: string; size?: number; label: string }) {
  const r = (size - 10) / 2;
  const circ = 2 * Math.PI * r;
  const offset = circ - (Math.min(100, pct) / 100) * circ;
  return (
    <div className="age-ring" style={{ width: size, height: size }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="6" />
        <circle
          cx={size / 2} cy={size / 2} r={r} fill="none"
          stroke={color} strokeWidth="6" strokeLinecap="round"
          strokeDasharray={circ} strokeDashoffset={offset}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          className="age-ring-arc"
        />
      </svg>
      <div className="age-ring-label">
        <strong style={{ color }}>{pct.toFixed(0)}%</strong>
        <span>{label}</span>
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, index = 0 }: { label: string; value: React.ReactNode; sub?: string; index?: number }) {
  const t = STAT_THEMES[index % STAT_THEMES.length];
  return (
    <div className="age-stat-card" style={{ '--stat-accent': t.accent, '--stat-bg': t.bg } as React.CSSProperties}>
      <span className="age-stat-icon" aria-hidden>{t.icon}</span>
      <span className="age-stat-label">{label}</span>
      <span className="age-stat-value">{value}</span>
      {sub && <span className="age-stat-sub">{sub}</span>}
    </div>
  );
}

function AgePill({ value, unit, color }: { value: number; unit: string; color: string }) {
  return (
    <div className="age-pill" style={{ '--pill-color': color } as React.CSSProperties}>
      <span className="age-pill-num">{value}</span>
      <span className="age-pill-unit">{unit}</span>
    </div>
  );
}

export default function AgeCalculatorRunner() {
  const searchParams = useSearchParams();
  const [dobDate, setDobDate] = useState('');
  const [dobTime, setDobTime] = useState('00:00');
  const [toDate, setToDate] = useState('');
  const [toTime, setToTime] = useState('00:00');
  const [useLive, setUseLive] = useState(true);
  const [includeTime, setIncludeTime] = useState(false);
  const [tab, setTab] = useState<Tab>('results');
  const [error, setError] = useState('');
  const [tick, setTick] = useState(0);
  const [aiText, setAiText] = useState('');
  const [aiType, setAiType] = useState<'summary' | 'health' | 'wishes' | 'facts' | 'motivation'>('summary');
  const [aiLoading, setAiLoading] = useState(false);
  const [qrUrl, setQrUrl] = useState('');
  const [copied, setCopied] = useState(false);
  const reportRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const now = new Date();
    setToDate(toDateInput(now));
    setToTime(toTimeInput(now));
    const qDob = searchParams.get('dob');
    const qTo = searchParams.get('to');
    if (qDob) setDobDate(qDob);
    if (qTo) { setToDate(qTo); setUseLive(false); }
    if (searchParams.get('dobTime')) setDobTime(searchParams.get('dobTime')!);
    if (searchParams.get('toTime')) setToTime(searchParams.get('toTime')!);
    if (searchParams.get('dobTime') || searchParams.get('toTime')) setIncludeTime(true);
  }, [searchParams]);

  useEffect(() => {
    if (!useLive) return;
    const id = setInterval(() => {
      const now = new Date();
      setToDate(toDateInput(now));
      setToTime(toTimeInput(now));
      setTick((t) => t + 1);
    }, 1000);
    return () => clearInterval(id);
  }, [useLive]);

  const result: AgeResult | null = useMemo(() => {
    void tick;
    if (!dobDate) return null;
    const dob = parseDateInput(dobDate, includeTime ? dobTime : '00:00');
    const to = useLive ? new Date() : parseDateInput(toDate, includeTime ? toTime : '23:59');
    if (!dob || !to) return null;
    if (to < dob && !useLive) return calculateAge(dob, to);
    if (to < dob) return null;
    return calculateAge(dob, to);
  }, [dobDate, dobTime, toDate, toTime, useLive, includeTime, tick]);

  useEffect(() => {
    if (!dobDate) return;
    const dob = parseDateInput(dobDate, includeTime ? dobTime : '00:00');
    const to = useLive ? new Date() : parseDateInput(toDate, includeTime ? toTime : '23:59');
    if (dob && to && to < dob && !useLive) setError('To date must be after date of birth.');
    else setError('');
  }, [dobDate, dobTime, toDate, toTime, useLive, includeTime]);

  const setToday = () => { const n = new Date(); setToDate(toDateInput(n)); setToTime(toTimeInput(n)); setUseLive(true); };
  const swapDates = () => {
    if (!dobDate || !toDate) return;
    setDobDate(toDate); setDobTime(toTime); setToDate(dobDate); setToTime(dobTime); setUseLive(false);
  };
  const reset = () => {
    setDobDate(''); setDobTime('00:00');
    const n = new Date(); setToDate(toDateInput(n)); setToTime(toTimeInput(n));
    setUseLive(true); setIncludeTime(false); setAiText(''); setError('');
  };

  const copyResult = async () => {
    if (!result) return;
    await navigator.clipboard.writeText(buildReportText(result));
    setCopied(true); setTimeout(() => setCopied(false), 2000);
  };

  const downloadPdf = async () => {
    if (!result) return;
    const { jsPDF } = await import('jspdf');
    const doc = new jsPDF();
    doc.setFillColor(124, 58, 237);
    doc.rect(0, 0, 210, 28, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(18);
    doc.text('Age Calculator Pro', 14, 18);
    doc.setTextColor(40, 40, 60);
    doc.setFontSize(10);
    doc.text(doc.splitTextToSize(buildReportText(result), 180), 14, 38);
    doc.save('age-report.pdf');
  };

  const downloadPng = async () => {
    if (!result) return;
    const canvas = document.createElement('canvas');
    canvas.width = 800; canvas.height = 900;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const grd = ctx.createLinearGradient(0, 0, 800, 900);
    grd.addColorStop(0, '#1a0a2e'); grd.addColorStop(0.5, '#2d1b69'); grd.addColorStop(1, '#7c3aed');
    ctx.fillStyle = grd; ctx.fillRect(0, 0, 800, 900);
    ctx.fillStyle = '#fff'; ctx.font = 'bold 32px sans-serif';
    ctx.fillText('🎂 Age Calculator Pro', 40, 60);
    ctx.font = 'bold 48px sans-serif';
    ctx.fillStyle = '#f5b93d';
    ctx.fillText(result.breakdown.label, 40, 130);
    ctx.font = '16px sans-serif'; ctx.fillStyle = 'rgba(255,255,255,0.8)';
    buildReportText(result).split('\n').slice(3).forEach((line, i) => ctx.fillText(line.slice(0, 80), 40, 180 + i * 24));
    canvas.toBlob((b) => { if (b) downloadBlob(b, 'age-report.png'); }, 'image/png');
  };

  const shareLink = () => {
    if (!dobDate) return;
    void navigator.clipboard.writeText(buildShareUrl(dobDate, useLive ? toDateInput(new Date()) : toDate, includeTime ? dobTime : undefined, includeTime ? toTime : undefined));
    setCopied(true); setTimeout(() => setCopied(false), 2000);
  };

  const showQr = async () => {
    if (!dobDate) return;
    const QRCode = (await import('qrcode')).default;
    setQrUrl(await QRCode.toDataURL(buildShareUrl(dobDate, useLive ? toDateInput(new Date()) : toDate), { width: 220, margin: 2, color: { dark: '#7c3aed', light: '#ffffff' } }));
  };

  const loadAi = useCallback(async () => {
    if (!result) return;
    setAiLoading(true);
    try { setAiText(await generateAiSummary(result, aiType)); }
    finally { setAiLoading(false); }
  }, [result, aiType]);

  useEffect(() => {
    if (tab === 'ai' && result && !aiText && !aiLoading) void loadAi();
  }, [tab, result, aiText, aiLoading, loadAi]);

  const tabs: Tab[] = ['results', 'birthday', 'astrology', 'milestones', 'stats', 'ai'];
  const zodiacGrad = result?.astrology.zodiacGradient ?? 'linear-gradient(135deg,#7c3aed,#ec4899)';

  return (
    <div className="age-tool" ref={reportRef}>
      {/* Animated background orbs */}
      <div className="age-bg" aria-hidden>
        <span className="age-orb age-orb-1" />
        <span className="age-orb age-orb-2" />
        <span className="age-orb age-orb-3" />
        <span className="age-orb age-orb-4" />
      </div>

      <div className="age-inner">
        <header className="age-hero">
          <div className="age-hero-badge">✨ Pro Edition</div>
          <div className="age-hero-row">
            <span className="age-hero-icon" aria-hidden>🎂</span>
            <div>
              <h2 className="age-hero-title">Age Calculator <span className="age-gradient-text">Pro</span></h2>
              <p className="age-hero-sub">Exact age · Live ticking · Zodiac · Milestones · AI insights</p>
            </div>
          </div>
        </header>

        <div className="age-layout">
          <aside className="age-card age-input-card">
            <div className="age-input-header">
              <span className="age-input-icon">📅</span>
              <h3>Date of Birth</h3>
            </div>
            <div className="age-field">
              <label htmlFor="age-dob">Birth date</label>
              <input id="age-dob" type="date" value={dobDate} max={toDateInput(new Date())} onChange={(e) => setDobDate(e.target.value)} />
            </div>
            {includeTime && (
              <div className="age-field">
                <label htmlFor="age-dob-time">Birth time</label>
                <input id="age-dob-time" type="time" value={dobTime} onChange={(e) => setDobTime(e.target.value)} />
              </div>
            )}

            <div className="age-input-header">
              <span className="age-input-icon">🎯</span>
              <h3>Calculate To</h3>
            </div>
            <div className="age-toggle-row">
              <button type="button" className={`age-toggle${useLive ? ' on' : ''}`} onClick={() => setUseLive(true)}>
                <span className="age-toggle-dot" /> Live Now
              </button>
              <button type="button" className={`age-toggle${includeTime ? ' on' : ''}`} onClick={() => setIncludeTime((v) => !v)}>
                <span className="age-toggle-dot" /> + Time
              </button>
            </div>
            {!useLive && (
              <>
                <div className="age-field">
                  <label htmlFor="age-to">To date</label>
                  <input id="age-to" type="date" value={toDate} onChange={(e) => { setToDate(e.target.value); setUseLive(false); }} />
                </div>
                {includeTime && (
                  <div className="age-field">
                    <label htmlFor="age-to-time">To time</label>
                    <input id="age-to-time" type="time" value={toTime} onChange={(e) => setToTime(e.target.value)} />
                  </div>
                )}
              </>
            )}

            <div className="age-actions">
              <button type="button" className="age-btn age-btn-violet" onClick={setToday}>Today</button>
              <button type="button" className="age-btn age-btn-pink" onClick={swapDates} disabled={!dobDate || !toDate}>⇄ Swap</button>
              <button type="button" className="age-btn age-btn-ghost" onClick={reset}>Reset</button>
            </div>

            <p className="age-popular-label">Quick pick</p>
            <div className="age-chips">
              {POPULAR_DOB.map((p) => (
                <button key={p.dob} type="button" className="age-chip" style={{ '--chip-color': p.color } as React.CSSProperties} onClick={() => setDobDate(p.dob)}>
                  {p.label}
                </button>
              ))}
            </div>
          </aside>

          <main className="age-results-col">
            {error && <div className="error-box">{error}</div>}

            {!dobDate && (
              <div className="age-empty">
                <div className="age-empty-orbit" aria-hidden>
                  <span>🎂</span><span>✨</span><span>🎈</span>
                </div>
                <p>Pick your birth date to unlock your age story</p>
              </div>
            )}

            {result && (
              <>
                {/* Hero result */}
                <div className="age-card age-hero-result" style={{ '--zodiac-grad': zodiacGrad } as React.CSSProperties}>
                  <div className="age-hero-result-glow" aria-hidden />
                  <div className="age-hero-result-top">
                    <div className="age-zodiac-badge" style={{ background: zodiacGrad }}>
                      {result.astrology.westernSymbol} {result.astrology.westernZodiac}
                    </div>
                    <div className="age-gen-badges">
                      <span className="age-gen-badge">{result.stats.generation}</span>
                      <span className="age-gen-badge age-gen-decade">{result.stats.decade}</span>
                    </div>
                  </div>

                  <p className="age-exact-label">Your exact age</p>
                  <div className="age-pills-row" aria-live="polite">
                    <AgePill value={result.breakdown.years} unit="Years" color="#7c3aed" />
                    <AgePill value={result.breakdown.months} unit="Months" color="#ec4899" />
                    <AgePill value={result.breakdown.days} unit="Days" color="#06b6d4" />
                  </div>

                  {useLive && (
                    <div className="age-live-clock" aria-live="polite">
                      <span className="age-live-seg"><AnimatedNum value={result.totals.hours} /><small>h</small></span>
                      <span className="age-live-sep">:</span>
                      <span className="age-live-seg"><AnimatedNum value={result.totals.minutes} /><small>m</small></span>
                      <span className="age-live-sep">:</span>
                      <span className="age-live-seg age-live-sec"><AnimatedNum value={result.totals.seconds} /><small>s</small></span>
                    </div>
                  )}

                  <div className="age-rings-row">
                    <RingProgress pct={result.stats.lifePct} color="#7c3aed" label="Life" />
                    <RingProgress pct={result.birthday.progressPct} color="#f5b93d" label="Birthday yr" />
                    {result.nextMilestone && (
                      <div className="age-next-ms">
                        <span className="age-next-ms-icon">{getMilestoneIcon(result.nextMilestone.label)}</span>
                        <strong>Next</strong>
                        <span>{result.nextMilestone.label}</span>
                        <em>{formatNumber(result.nextMilestone.daysUntil ?? 0)} days</em>
                      </div>
                    )}
                  </div>
                </div>

                {/* Quick ribbon */}
                <div className="age-ribbon">
                  <div className="age-ribbon-item" style={{ '--c': '#7c3aed' } as React.CSSProperties}>
                    <span>{formatNumber(result.totals.days)}</span><small>days lived</small>
                  </div>
                  <div className="age-ribbon-item" style={{ '--c': '#ec4899' } as React.CSSProperties}>
                    <span>{result.birthday.daysRemaining}</span><small>days to bday</small>
                  </div>
                  <div className="age-ribbon-item" style={{ '--c': '#22c55e' } as React.CSSProperties}>
                    <span>{result.stats.leapYearsLived}</span><small>leap years</small>
                  </div>
                  <div className="age-ribbon-item" style={{ '--c': '#f97316' } as React.CSSProperties}>
                    <span>{result.astrology.luckyNumber}</span><small>lucky #</small>
                  </div>
                </div>

                {/* Tabs */}
                <div className="age-tabs" role="tablist">
                  {tabs.map((id) => {
                    const m = TAB_META[id];
                    return (
                      <button key={id} type="button" role="tab" aria-selected={tab === id}
                        className={tab === id ? 'active' : ''}
                        style={tab === id ? { '--tab-color': m.color } as React.CSSProperties : undefined}
                        onClick={() => setTab(id)}>
                        <span aria-hidden>{m.icon}</span> {id.charAt(0).toUpperCase() + id.slice(1)}
                      </button>
                    );
                  })}
                </div>

                <div className="age-card age-panel">
                  {tab === 'results' && (
                    <div className="age-stat-grid">
                      {[
                        ['Years', result.breakdown.years],
                        ['Months', result.totals.months],
                        ['Weeks', <AnimatedNum key="w" value={result.totals.weeks} />],
                        ['Days', <AnimatedNum key="d" value={result.totals.days} />],
                        ['Hours', <AnimatedNum key="h" value={result.totals.hours} />],
                        ['Minutes', <AnimatedNum key="m" value={result.totals.minutes} />],
                        ['Seconds', <AnimatedNum key="s" value={result.totals.seconds} />],
                        ['Milliseconds', <AnimatedNum key="ms" value={result.totals.milliseconds} />],
                        ['Leap Years', result.stats.leapYearsLived],
                      ].map(([label, value], i) => (
                        <StatCard key={String(label)} label={String(label)} value={value} index={i} />
                      ))}
                    </div>
                  )}

                  {tab === 'birthday' && (
                    <div className="age-birthday">
                      {result.birthday.isToday ? (
                        <div className="age-bday-celebrate">
                          <span className="age-confetti" aria-hidden>🎉🎈🎊✨🎁</span>
                          <p>Happy Birthday!</p>
                        </div>
                      ) : (
                        <div className="age-bday-countdown-wrap">
                          <div className="age-bday-ring-wrap">
                            <RingProgress pct={100 - (result.birthday.daysRemaining / 365) * 100} color="#f97316" size={140} label="Countdown" />
                          </div>
                          <div className="age-bday-nums">
                            <div className="age-bday-block"><strong>{result.birthday.daysRemaining}</strong><span>Days</span></div>
                            <div className="age-bday-block"><strong>{result.birthday.hoursRemaining}</strong><span>Hours</span></div>
                            <div className="age-bday-block"><strong>{result.birthday.minutesRemaining}</strong><span>Mins</span></div>
                            {useLive && <div className="age-bday-block"><strong>{result.birthday.secondsRemaining}</strong><span>Secs</span></div>}
                          </div>
                        </div>
                      )}
                      <div className="age-bday-cards">
                        <div className="age-bday-card" style={{ '--c': '#7c3aed' } as React.CSSProperties}>
                          <span>📅 Next</span><strong>{formatDate(result.birthday.nextDate)}</strong>
                        </div>
                        <div className="age-bday-card" style={{ '--c': '#ec4899' } as React.CSSProperties}>
                          <span>📆 Weekday</span><strong>{result.birthday.weekday}</strong>
                        </div>
                        <div className="age-bday-card" style={{ '--c': '#f5b93d' } as React.CSSProperties}>
                          <span>🎂 Turning</span><strong>{result.birthday.ageTurning} years</strong>
                        </div>
                      </div>
                    </div>
                  )}

                  {tab === 'astrology' && (
                    <div className="age-astro-showcase" style={{ background: zodiacGrad }}>
                      <span className="age-astro-big">{result.astrology.westernSymbol}</span>
                      <h3>{result.astrology.westernZodiac}</h3>
                      <p>{result.astrology.chineseEmoji} {result.astrology.chineseZodiac} · Born {result.dob.getFullYear()}</p>
                    </div>
                  )}
                  {tab === 'astrology' && (
                    <div className="age-astro-grid">
                      {[
                        { icon: '♈', label: 'Western', value: result.astrology.westernZodiac, color: result.astrology.zodiacColor },
                        { icon: result.astrology.chineseEmoji, label: 'Chinese', value: result.astrology.chineseZodiac, color: '#ef4444' },
                        { icon: '💎', label: 'Birthstone', value: result.astrology.birthstone, color: '#06b6d4' },
                        { icon: '🌸', label: 'Birth Flower', value: result.astrology.birthFlower, color: '#ec4899' },
                        { icon: '🔢', label: 'Lucky Number', value: String(result.astrology.luckyNumber), color: '#eab308' },
                        { icon: '🎨', label: 'Lucky Color', value: result.astrology.luckyColor, color: '#22c55e' },
                      ].map((a) => (
                        <div key={a.label} className="age-astro-item" style={{ '--astro-c': a.color } as React.CSSProperties}>
                          <span className="age-astro-ic">{a.icon}</span>
                          <div><span>{a.label}</span><strong>{a.value}</strong></div>
                        </div>
                      ))}
                    </div>
                  )}

                  {tab === 'milestones' && (
                    <div className="age-timeline">
                      {result.milestones.map((m, i) => (
                        <div key={m.label} className={`age-tl-item${m.reached ? ' done' : ''}`}>
                          <div className="age-tl-dot" style={{ '--tl-c': m.reached ? '#22c55e' : '#7c3aed' } as React.CSSProperties}>
                            {getMilestoneIcon(m.label)}
                          </div>
                          <div className="age-tl-body">
                            <strong>{m.label}</strong>
                            <span>{m.reached ? `✓ ${formatDateTime(m.date)}` : `⏳ ${formatNumber(m.daysUntil ?? 0)} days away`}</span>
                          </div>
                          {i < result.milestones.length - 1 && <div className="age-tl-line" />}
                        </div>
                      ))}
                    </div>
                  )}

                  {tab === 'stats' && (
                    <>
                      <div className="age-stats-hero">
                        <div className="age-stats-bar-wrap">
                          <div className="age-stats-bar" style={{ width: `${result.stats.lifePct}%` }} />
                        </div>
                        <p>{result.stats.lifePct.toFixed(1)}% life journey · ~{result.stats.remainingYears.toFixed(1)} years remaining (est.)</p>
                      </div>
                      <div className="age-stat-grid">
                        <StatCard label="Heartbeats" value={<AnimatedNum value={result.stats.heartbeats} />} sub="~72 bpm" index={0} />
                        <StatCard label="Breaths" value={<AnimatedNum value={result.stats.breaths} />} sub="~16/min" index={1} />
                        <StatCard label="Sleep" value={`${formatNumber(result.stats.sleepHours)}h`} sub="~33% of life" index={2} />
                        <StatCard label="Walking" value={`${formatNumber(result.stats.walkingKm)} km`} sub="~5 km/day" index={3} />
                        <StatCard label="Days Lived" value={<AnimatedNum value={result.totals.days} />} index={4} />
                        <StatCard label="Weeks Lived" value={<AnimatedNum value={result.totals.weeks} />} index={5} />
                        <StatCard label="Generation" value={result.stats.generation} index={6} />
                        <StatCard label="Era" value={result.stats.decade} index={7} />
                      </div>
                    </>
                  )}

                  {tab === 'ai' && (
                    <div className="age-ai">
                      <div className="age-ai-types">
                        {(['summary', 'health', 'wishes', 'facts', 'motivation'] as const).map((t) => (
                          <button key={t} type="button" className={`age-ai-chip${aiType === t ? ' active' : ''}`} onClick={() => { setAiType(t); setAiText(''); }}>
                            {t === 'summary' && '✨'} {t === 'health' && '💚'} {t === 'wishes' && '🎂'} {t === 'facts' && '🎯'} {t === 'motivation' && '🔥'} {t}
                          </button>
                        ))}
                      </div>
                      {aiLoading && <div className="age-ai-loading"><span className="age-ai-pulse" /> Generating AI insight…</div>}
                      {aiText && <div className="age-ai-card"><div className="age-ai-glow" aria-hidden /><p>{aiText}</p></div>}
                      <button type="button" className="age-btn age-btn-violet" onClick={() => { setAiText(''); void loadAi(); }}>Regenerate ✨</button>
                    </div>
                  )}
                </div>

                <div className="age-export">
                  {[
                    { label: copied ? 'Copied!' : 'Copy', icon: 'copy' as const, fn: copyResult, cls: 'age-btn-cyan' },
                    { label: 'PDF', icon: 'download' as const, fn: () => void downloadPdf(), cls: 'age-btn-violet' },
                    { label: 'PNG', icon: 'image' as const, fn: () => void downloadPng(), cls: 'age-btn-pink' },
                    { label: 'Print', icon: 'printer' as const, fn: () => window.print(), cls: 'age-btn-gold' },
                    { label: 'Share', icon: 'link' as const, fn: shareLink, cls: 'age-btn-green' },
                    { label: 'QR', icon: 'qr' as const, fn: () => void showQr(), cls: 'age-btn-orange' },
                  ].map((b) => (
                    <button key={b.label} type="button" className={`age-btn ${b.cls}`} onClick={b.fn}>
                      <Icon name={b.icon} size={14} /> {b.label}
                    </button>
                  ))}
                </div>

                {qrUrl && (
                  <div className="age-qr-modal" role="dialog" aria-label="QR code">
                    <div className="age-qr-glow" aria-hidden />
                    <img src={qrUrl} alt="Share QR code" width={220} height={220} />
                    <button type="button" className="age-btn age-btn-ghost" onClick={() => setQrUrl('')}>Close</button>
                  </div>
                )}
              </>
            )}
          </main>
        </div>

        <p className="age-footer">🔒 100% private · All math runs in your browser · Zero data stored</p>
      </div>
    </div>
  );
}
