'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent as ReactKeyboardEvent, type PointerEvent as ReactPointerEvent } from 'react';
import Icon from '../Icon';
import { useUI } from '../GlobalUI';
import { searchTools, tools, type Tool } from '@/data/tools';
import { getCategory } from '@/data/categories';
import { formatCount } from '@/lib/format-count';

/* ═══════════════ FARVIXO HERO v15.0 — AI OPERATING SYSTEM ═══════════════
   AI Core Engine · Tool Spawn System · Energy Network · Search Sync ·
   Live AI Assistant · Boot Sequence · Ambient Lighting · Scroll Story  */

/* ─────────── Popular tool chips ─────────── */

const chipMap: Record<string, string> = {
  'PDF Converter': '/tools/pdf/pdf-converter',
  'Image AI': '/tools/image/image-compressor',
  'AI Chat': '/tools/ai/ai-chat',
  'QR Generator': '/tools/utility/qr-code-generator',
};

/* ─────────── Rotating search placeholders ─────────── */

const PLACEHOLDERS = [
  'Search 150+ AI tools...',
  'Search PDF Tools...',
  'Search Image Tools...',
  'Search Video Tools...',
  'Search OCR Tools...',
  'Search Developer Tools...',
  'Search AI Tools...',
];

const TRENDING = ['PDF to Word', 'Background Remover', 'AI Chat', 'Image Compressor', 'QR Generator', 'Video Converter'];

const RECENT_KEY = 'farvixo:recent-searches';
const BOOT_KEY = 'farvixo:ai-boot-seen';

function loadRecent(): string[] {
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    const arr = raw ? (JSON.parse(raw) as string[]) : [];
    return Array.isArray(arr) ? arr.filter((s) => typeof s === 'string').slice(0, 5) : [];
  } catch { return []; }
}

function saveRecent(term: string): void {
  try {
    const next = [term, ...loadRecent().filter((s) => s.toLowerCase() !== term.toLowerCase())].slice(0, 5);
    localStorage.setItem(RECENT_KEY, JSON.stringify(next));
  } catch { /* storage unavailable */ }
}

/* ─────────── Typo correction (Levenshtein "did you mean") ─────────── */

function editDistance(a: string, b: string): number {
  const m = a.length, n = b.length;
  if (!m) return n;
  if (!n) return m;
  const row = Array.from({ length: n + 1 }, (_, i) => i);
  for (let i = 1; i <= m; i++) {
    let prev = row[0];
    row[0] = i;
    for (let j = 1; j <= n; j++) {
      const tmp = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] === b[j - 1] ? 0 : 1));
      prev = tmp;
    }
  }
  return row[n];
}

function didYouMean(query: string): Tool | null {
  const q = query.toLowerCase().trim();
  if (q.length < 3) return null;
  let best: Tool | null = null;
  let bestScore = Math.max(2, Math.floor(q.length / 3)) + 1;
  for (const t of tools) {
    const name = t.name.toLowerCase();
    const d = editDistance(q, name.slice(0, Math.max(q.length, name.length > q.length + 4 ? q.length : name.length)));
    if (d < bestScore) { bestScore = d; best = t; }
  }
  return best;
}

/* ═══════════════ AI CORE ENGINE — living tool factory ═══════════════
   The cube is the Farvixo Intelligence Engine. It continuously *generates*
   tools: every 3–5s a card is forged inside the core, opens the cube, exits
   on an energy beam, floats + glows, then is re-absorbed. Nothing is static.
   Beam coordinates live in a 320×320 viewBox with the core at (160, 160). */

interface SpawnTool {
  label: string;
  icon: string;
  accent: string;
  href: string;
  keys: string[];
}

const SPAWN_TOOLS: SpawnTool[] = [
  { label: 'PDF Converter', icon: 'file-text', accent: 'var(--accent-pdf)', href: '/tools/pdf/pdf-converter', keys: ['pdf', 'word', 'doc', 'convert'] },
  { label: 'Image AI', icon: 'image', accent: 'var(--accent-image)', href: '/tools/image/image-compressor', keys: ['image', 'photo', 'compress', 'jpg', 'png'] },
  { label: 'AI Chat', icon: 'bot', accent: 'var(--accent-ai)', href: '/tools/ai/ai-chat', keys: ['chat', 'ai', 'assistant', 'gpt'] },
  { label: 'OCR Scanner', icon: 'scan-text', accent: 'var(--accent-image)', href: '/tools/image/image-ocr', keys: ['ocr', 'text', 'scan', 'extract'] },
  { label: 'QR Generator', icon: 'qr', accent: 'var(--accent-dev)', href: '/tools/utility/qr-code-generator', keys: ['qr', 'code', 'barcode'] },
  { label: 'Video Converter', icon: 'video', accent: 'var(--accent-video)', href: '/tools/video/video-converter', keys: ['video', 'mp4', 'gif', 'trim'] },
  { label: 'Resume Builder', icon: 'file-pen', accent: 'var(--gold-premium)', href: '/tools/ai/ai-resume-builder', keys: ['resume', 'cv', 'job'] },
  { label: 'Background Remover', icon: 'eraser', accent: 'var(--brand-primary)', href: '/tools/image/background-remover', keys: ['background', 'remove', 'bg', 'transparent'] },
  { label: 'JSON Formatter', icon: 'code', accent: 'var(--accent-dev)', href: '/tools/developer/json-formatter', keys: ['json', 'format', 'developer', 'html', 'viewer'] },
  { label: 'AI Writer', icon: 'pen', accent: 'var(--accent-ai)', href: '/tools/ai/ai-writer', keys: ['write', 'writer', 'content', 'blog'] },
];

type SpawnDir = 'top' | 'bottom' | 'left' | 'right' | 'front';

const DIRS: SpawnDir[] = ['top', 'bottom', 'left', 'right', 'front'];

/* Where a card floats to (px offset from the core centre, 320px stage) */
const DIR_OFFSET: Record<SpawnDir, { tx: number; ty: number }> = {
  top: { tx: 0, ty: -126 },
  bottom: { tx: 0, ty: 120 },
  left: { tx: -140, ty: -6 },
  right: { tx: 140, ty: -6 },
  front: { tx: 0, ty: -4 },
};

const CORE = { x: 170, y: 170 }; // centre of the 340×340 stage (1 unit = 1px)
const LIFE = 4200;       // autonomous card lifetime (ms)
const LIFE_SYNC = 5200;  // search-matched card lifetime (ms)

interface LiveSpawn {
  id: number;
  tool: SpawnTool;
  dir: SpawnDir;
  synced: boolean;
  life: number;
}

/* First tool whose name/keywords match the query (Search Sync) */
function matchSpawnTool(q: string): SpawnTool | null {
  const query = q.toLowerCase().trim();
  if (query.length < 2) return null;
  for (const t of SPAWN_TOOLS) {
    if (t.label.toLowerCase().includes(query) || t.keys.some((k) => query.includes(k) || k.includes(query))) return t;
  }
  return null;
}

/* ─────────── AI Core Engine (the living cube) ─────────── */

function AiCore({ query }: { query: string }) {
  const [spawns, setSpawns] = useState<LiveSpawn[]>([]);
  const [hover, setHover] = useState(false);
  const [burst, setBurst] = useState(false);

  const idRef = useRef(0);
  const lastTool = useRef(-1);
  const lastDir = useRef<SpawnDir | null>(null);
  const syncedLabel = useRef<string | null>(null);
  const reduced = useRef(false);
  const timers = useRef<number[]>([]);

  const push = useCallback((tool: SpawnTool, dir: SpawnDir, synced: boolean, life: number) => {
    const id = (idRef.current += 1);
    setSpawns((s) => [...s.filter((x) => !(synced && x.synced)), { id, tool, dir, synced, life }]);
    const t = window.setTimeout(() => setSpawns((s) => s.filter((x) => x.id !== id)), life + 140);
    timers.current.push(t);
  }, []);

  /* Autonomous forge loop — one tool every 3–5s, never same tool/dir twice */
  useEffect(() => {
    reduced.current = typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (reduced.current) {
      setSpawns([
        { id: (idRef.current += 1), tool: SPAWN_TOOLS[0], dir: 'left', synced: false, life: 0 },
        { id: (idRef.current += 1), tool: SPAWN_TOOLS[2], dir: 'top', synced: false, life: 0 },
        { id: (idRef.current += 1), tool: SPAWN_TOOLS[1], dir: 'right', synced: false, life: 0 },
      ]);
      return;
    }

    let alive = true;
    const tick = () => {
      if (!alive) return;
      let ti = Math.floor(Math.random() * SPAWN_TOOLS.length);
      if (ti === lastTool.current) ti = (ti + 1) % SPAWN_TOOLS.length;
      lastTool.current = ti;
      const pool = DIRS.filter((d) => d !== lastDir.current);
      const dir = pool[Math.floor(Math.random() * pool.length)];
      lastDir.current = dir;
      push(SPAWN_TOOLS[ti], dir, false, LIFE);
      const next = 3000 + Math.random() * 2000;
      const t = window.setTimeout(tick, next);
      timers.current.push(t);
    };
    const boot = window.setTimeout(tick, 2600); // let the cube build itself first
    timers.current.push(boot);

    return () => {
      alive = false;
      timers.current.forEach((t) => window.clearTimeout(t));
      timers.current = [];
    };
  }, [push]);

  /* Search Sync — typing instantly forges the matching tool from the front */
  useEffect(() => {
    if (reduced.current) return;
    const t = matchSpawnTool(query);
    const label = t ? t.label : null;
    if (label && label !== syncedLabel.current) {
      syncedLabel.current = label;
      push(t as SpawnTool, 'front', true, LIFE_SYNC);
    } else if (!label) {
      syncedLabel.current = null;
    }
  }, [query, push]);

  /* Click — energy explosion: forge four tools at once */
  const onClick = useCallback(() => {
    if (reduced.current) return;
    setBurst(true);
    const dirs: SpawnDir[] = ['top', 'right', 'bottom', 'left'];
    dirs.forEach((d, i) => {
      const tool = SPAWN_TOOLS[(idRef.current + i * 3) % SPAWN_TOOLS.length];
      const t = window.setTimeout(() => push(tool, d, false, 3800), i * 90);
      timers.current.push(t);
    });
    const clear = window.setTimeout(() => setBurst(false), 820);
    timers.current.push(clear);
  }, [push]);

  const searching = query.trim().length >= 2;
  const spawning = spawns.length > 0; // a tool is currently being forged

  return (
    <div
      className={`ai-core-engine${spawning ? ' is-spawning' : ''}${hover ? ' is-hover' : ''}${burst ? ' is-burst' : ''}${searching ? ' is-searching' : ''}`}
      onPointerEnter={() => setHover(true)}
      onPointerLeave={() => setHover(false)}
      onClick={onClick}
    >
      {/* Energy network — a beam fires along every spawned tool's path */}
      <svg className="ai-beams" viewBox="0 0 340 340" fill="none">
        {spawns.map((s) => {
          const o = DIR_OFFSET[s.dir];
          return (
            <line
              key={s.id}
              x1={CORE.x}
              y1={CORE.y}
              x2={CORE.x + o.tx}
              y2={CORE.y + o.ty}
              className={`ai-beam${s.synced ? ' synced' : ''}`}
              style={{ stroke: s.tool.accent, '--life': `${s.life}ms` } as React.CSSProperties}
            />
          );
        })}
      </svg>

      {/* Pulsing energy ring below the cube */}
      <div className="ai-energy-ring" aria-hidden="true"><i /><i /><i /></div>

      {/* The AI Core cube — builds itself, glows, breathes, emits sparks */}
      <div className="ai-cube">
        <div className="ai-cube-spin">
          <span className="ai-cube-face acf-1" />
          <span className="ai-cube-face acf-2" />
          <span className="ai-cube-face acf-3" />
          <span className="ai-cube-face acf-4" />
          <span className="ai-cube-face acf-5" />
          <span className="ai-cube-face acf-6" />
        </div>
        {/* Living AI Reactor inside the cube — never empty, always generating */}
        <span className="ai-reactor" aria-hidden="true">
          {/* Hexagonal energy grid (futuristic depth) */}
          <svg className="ai-hex-grid" viewBox="-60 -60 120 120" fill="none">
            <polygon points="0,-52 45,-26 45,26 0,52 -45,26 -45,-26" />
            <polygon points="0,-36 31,-18 31,18 0,36 -31,18 -31,-18" />
            <polygon points="0,-20 17,-10 17,10 0,20 -17,10 -17,-10" />
            <line x1="0" y1="-52" x2="0" y2="52" />
            <line x1="-45" y1="-26" x2="45" y2="26" />
            <line x1="-45" y1="26" x2="45" y2="-26" />
          </svg>
          {/* Purple plasma clouds — flow continuously */}
          <span className="ai-plasma" />
          <span className="ai-plasma ai-plasma-2" />
          {/* Volumetric glow — purple → blue → pink cycle */}
          <span className="ai-volglow" />
          {/* Circular energy swirl — clockwise, then reverses */}
          <span className="ai-swirl-ring" />
          <span className="ai-swirl-ring ai-swirl-ring-2" />
          {/* Floating energy sphere — Farvixo Intelligence */}
          <span className="ai-sphere">
            <span className="ai-sphere-ring" />
            <span className="ai-sphere-core" />
          </span>
          {/* Random electric arcs — sphere ↔ cube walls */}
          <svg className="ai-lightning" viewBox="0 0 120 120" fill="none">
            <path className="arc arc-1" d="M60 60 L74 44 L69 41 L84 24" />
            <path className="arc arc-2" d="M60 60 L46 74 L52 77 L37 94" />
            <path className="arc arc-3" d="M60 60 L78 66 L75 72 L95 78" />
            <path className="arc arc-4" d="M60 60 L44 53 L47 47 L28 40" />
          </svg>
        </span>
        {/* Holographic Farvixo logo — the AI Core: floats, spins 360°, pulses */}
        <span className="ai-logo-holo" aria-hidden="true">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/farvixo-logo.svg" alt="" width={38} height={38} className="ai-cube-logo logo-front" loading="lazy" />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/farvixo-logo.svg" alt="" width={38} height={38} className="ai-cube-logo logo-back" loading="lazy" />
        </span>
      </div>

      {/* Continuous particle / spark emission */}
      <span className="ai-emitters" aria-hidden="true">
        {Array.from({ length: 6 }).map((_, i) => (
          <i key={i} style={{ '--i': i } as React.CSSProperties} />
        ))}
      </span>

      <span className="ai-core-pulse" aria-hidden="true" />
      <span className="ai-burst-ring" aria-hidden="true" />
      <span className="ai-core-shadow" aria-hidden="true" />

      {/* Forged tool cards — each exits the cube, floats, then is re-absorbed */}
      {spawns.map((s) => {
        const o = DIR_OFFSET[s.dir];
        return (
          <Link
            key={s.id}
            href={s.tool.href}
            className={`ai-spawn dir-${s.dir}${s.synced ? ' synced' : ''}`}
            style={{
              '--tx': `${o.tx}px`,
              '--ty': `${o.ty}px`,
              '--accent': s.tool.accent,
              '--life': `${s.life}ms`,
            } as React.CSSProperties}
            tabIndex={-1}
            onClick={(e) => e.stopPropagation()}
          >
            <span className="ai-spawn-card">
              <span className="ai-spawn-icon" style={{ color: s.tool.accent, background: `color-mix(in srgb, ${s.tool.accent} 16%, transparent)` }}>
                <Icon name={s.tool.icon} size={15} />
              </span>
              <span className="ai-spawn-text">
                <b>{s.tool.label}</b>
                <i>{s.synced ? 'Open now' : 'Ready'}</i>
              </span>
            </span>
          </Link>
        );
      })}
    </div>
  );
}

/* ─────────── Deterministic ambient particles ─────────── */

const PARTICLES = [
  { left: '6%', top: '18%', size: 4, delay: '0s', dur: '9s' },
  { left: '14%', top: '72%', size: 3, delay: '1.2s', dur: '11s' },
  { left: '24%', top: '38%', size: 5, delay: '2.4s', dur: '10s' },
  { left: '36%', top: '84%', size: 3, delay: '0.6s', dur: '12s' },
  { left: '48%', top: '12%', size: 4, delay: '3s', dur: '9.5s' },
  { left: '58%', top: '64%', size: 3, delay: '1.8s', dur: '10.5s' },
  { left: '68%', top: '28%', size: 5, delay: '0.9s', dur: '11.5s' },
  { left: '78%', top: '80%', size: 3, delay: '2.1s', dur: '9s' },
  { left: '86%', top: '42%', size: 4, delay: '1.5s', dur: '12.5s' },
  { left: '93%', top: '16%', size: 3, delay: '2.7s', dur: '10s' },
  { left: '40%', top: '52%', size: 2, delay: '3.3s', dur: '13s' },
  { left: '90%', top: '68%', size: 2, delay: '0.3s', dur: '11s' },
] as const;

/* ─────────── Ripple micro-interaction ─────────── */

function spawnRipple(e: ReactPointerEvent<HTMLElement>): void {
  const host = e.currentTarget;
  const rect = host.getBoundingClientRect();
  const span = document.createElement('span');
  span.className = 'ui-ripple';
  const size = Math.max(rect.width, rect.height) * 1.6;
  span.style.width = span.style.height = `${size}px`;
  span.style.left = `${e.clientX - rect.left - size / 2}px`;
  span.style.top = `${e.clientY - rect.top - size / 2}px`;
  host.appendChild(span);
  window.setTimeout(() => span.remove(), 650);
}

/* ─────────── Speech Recognition (voice search) ─────────── */

interface SpeechRecognitionLike {
  lang: string;
  interimResults: boolean;
  maxAlternatives: number;
  onresult: ((ev: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null;
  onend: (() => void) | null;
  onerror: (() => void) | null;
  start: () => void;
  stop: () => void;
}

function getSpeechRecognition(): (new () => SpeechRecognitionLike) | null {
  if (typeof window === 'undefined') return null;
  const w = window as unknown as Record<string, unknown>;
  return (w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null) as (new () => SpeechRecognitionLike) | null;
}

/* ─────────── Time-aware AI greeting ─────────── */

function timeGreeting(): string {
  const h = new Date().getHours();
  if (h >= 5 && h < 12) return 'Good morning ☀️';
  if (h >= 12 && h < 17) return 'Good afternoon 👋';
  if (h >= 17 && h < 22) return 'Good evening 🌙';
  return 'Working late? 🌙';
}

/* ─────────── AI Boot Sequence (first visit only) ─────────── */

const BOOT_LINES = ['Farvixo', 'AI Initializing...', 'Loading Models...', 'Preparing Tools...', 'AI Ready ✓'];

function AiBoot({ onDone }: { onDone: () => void }) {
  const [line, setLine] = useState(0);
  const [fading, setFading] = useState(false);

  useEffect(() => {
    if (line < BOOT_LINES.length - 1) {
      const id = window.setTimeout(() => setLine((l) => l + 1), 420);
      return () => window.clearTimeout(id);
    }
    const id = window.setTimeout(() => setFading(true), 500);
    const id2 = window.setTimeout(onDone, 900);
    return () => { window.clearTimeout(id); window.clearTimeout(id2); };
  }, [line, onDone]);

  return (
    <div className={`ai-boot${fading ? ' fading' : ''}`} role="status" aria-live="polite" onClick={onDone}>
      <div className="ai-boot-orb" aria-hidden="true" />
      <div className="ai-boot-brand">{BOOT_LINES[0]}</div>
      {line > 0 && <div className="ai-boot-line" key={line}>{BOOT_LINES[line]}</div>}
      <div className="ai-boot-track" aria-hidden="true"><i style={{ width: `${(line / (BOOT_LINES.length - 1)) * 100}%` }} /></div>
      <span className="ai-boot-skip">Click to skip</span>
    </div>
  );
}

/* ═══════════════════════════ HERO ═══════════════════════════ */

export default function Hero() {
  const { openAI, toast } = useUI();
  const router = useRouter();
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const [phIdx, setPhIdx] = useState(0);
  const [recent, setRecent] = useState<string[]>([]);
  const [voiceReady, setVoiceReady] = useState(false);
  const [listening, setListening] = useState(false);
  const [navigating, setNavigating] = useState(false);
  const [ctaLoading, setCtaLoading] = useState(false);
  const [booting, setBooting] = useState(false);
  const [greeting, setGreeting] = useState('Hello 👋');
  const [typed, setTyped] = useState('');
  const [stats, setStats] = useState<{ users: number; jobs: number } | null>(null);

  const wrapRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const visualRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const sectionRef = useRef<HTMLElement>(null);
  const recogRef = useRef<SpeechRecognitionLike | null>(null);
  const reducedMotion = useRef(false);
  const programmaticFocus = useRef(false);

  const matches = useMemo(() => (q.trim() ? searchTools(q.trim()) : []), [q]);
  const results = matches.slice(0, 6);
  const suggestion = useMemo(() => (q.trim() && matches.length === 0 ? didYouMean(q) : null), [q, matches.length]);

  /* Search Sync — typed query drives the assistant + AI Core spawn */
  const syncTool = q.trim() && results.length > 0 ? results[0] : null;

  /* Real public stats (never fake numbers) */
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

  /* Environment: reduced motion, voice, recents, boot, greeting */
  useEffect(() => {
    reducedMotion.current = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    setVoiceReady(getSpeechRecognition() !== null);
    setRecent(loadRecent());
    setGreeting(timeGreeting());
    try {
      if (!reducedMotion.current && !localStorage.getItem(BOOT_KEY)) {
        localStorage.setItem(BOOT_KEY, '1');
        setBooting(true);
      }
    } catch { /* storage unavailable */ }
  }, []);

  /* Live-typing AI assistant message */
  const assistantMsg = syncTool
    ? `Looking for ${syncTool.name}? I can open it for you.`
    : "I'm your AI assistant. How can I help you today?";
  useEffect(() => {
    if (reducedMotion.current) { setTyped(assistantMsg); return; }
    setTyped('');
    let i = 0;
    const id = window.setInterval(() => {
      i += 1;
      setTyped(assistantMsg.slice(0, i));
      if (i >= assistantMsg.length) window.clearInterval(id);
    }, 24);
    return () => window.clearInterval(id);
  }, [assistantMsg]);

  /* Auto focus (desktop keyboards only) */
  useEffect(() => {
    if (!window.matchMedia('(pointer: fine)').matches || window.innerWidth < 1024) return;
    programmaticFocus.current = true;
    try { inputRef.current?.focus({ preventScroll: true }); } catch { /* older browsers */ }
    window.setTimeout(() => { programmaticFocus.current = false; }, 0);
  }, []);

  /* Rotating placeholder */
  useEffect(() => {
    if (q || reducedMotion.current) return;
    const id = window.setInterval(() => setPhIdx((i) => (i + 1) % PLACEHOLDERS.length), 2800);
    return () => window.clearInterval(id);
  }, [q]);

  /* "/" keyboard shortcut → focus hero search (⌘K palette is global) */
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
      const el = document.activeElement;
      if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement || (el instanceof HTMLElement && el.isContentEditable)) return;
      e.preventDefault();
      inputRef.current?.focus();
      setOpen(true);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  /* Scroll story: core shrinks, cards return, glow fades — rAF throttled */
  useEffect(() => {
    if (reducedMotion.current) return;
    let raf = 0;
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        const p = Math.min(window.scrollY / 700, 1);
        sectionRef.current?.style.setProperty('--hero-scroll', p.toFixed(3));
      });
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => { window.removeEventListener('scroll', onScroll); if (raf) cancelAnimationFrame(raf); };
  }, []);

  /* AI Ambient Lighting — light follows the mouse across the hero */
  const onHeroMove = useCallback((e: ReactPointerEvent<HTMLElement>) => {
    if (reducedMotion.current || e.pointerType === 'touch') return;
    const host = sectionRef.current;
    if (!host) return;
    const r = host.getBoundingClientRect();
    host.style.setProperty('--mx', `${(((e.clientX - r.left) / r.width) * 100).toFixed(1)}%`);
    host.style.setProperty('--my', `${(((e.clientY - r.top) / r.height) * 100).toFixed(1)}%`);
  }, []);

  /* Smart mouse: AI Core stage tilt */
  const onVisualMove = useCallback((e: ReactPointerEvent<HTMLDivElement>) => {
    if (reducedMotion.current || e.pointerType === 'touch') return;
    const host = visualRef.current, stage = stageRef.current;
    if (!host || !stage) return;
    const r = host.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width - 0.5;
    const y = (e.clientY - r.top) / r.height - 0.5;
    stage.style.transform = `rotateX(${(-y * 10).toFixed(2)}deg) rotateY(${(x * 10).toFixed(2)}deg)`;
  }, []);
  const onVisualLeave = useCallback(() => {
    if (stageRef.current) stageRef.current.style.transform = 'rotateX(0deg) rotateY(0deg)';
  }, []);

  /* Magnetic hover for CTAs */
  const onMagnetMove = useCallback((e: ReactPointerEvent<HTMLElement>) => {
    if (reducedMotion.current || e.pointerType === 'touch') return;
    const el = e.currentTarget;
    const r = el.getBoundingClientRect();
    const x = ((e.clientX - r.left) / r.width - 0.5) * 8;
    const y = ((e.clientY - r.top) / r.height - 0.5) * 6;
    el.style.transform = `translate(${x.toFixed(1)}px, ${y.toFixed(1)}px)`;
  }, []);
  const onMagnetLeave = useCallback((e: ReactPointerEvent<HTMLElement>) => {
    e.currentTarget.style.transform = '';
  }, []);

  /* Navigation helpers */
  const goTo = (t: Tool) => {
    saveRecent(t.name);
    setRecent(loadRecent());
    setOpen(false);
    setNavigating(true);
    router.push(`/tools/${t.category}/${t.slug}`);
  };

  const viewAll = () => {
    const query = q.trim();
    if (!query) return;
    saveRecent(query);
    setRecent(loadRecent());
    setOpen(false);
    setNavigating(true);
    router.push(`/tools?q=${encodeURIComponent(query)}`);
  };

  const search = () => {
    if (open && results[active]) return goTo(results[active]);
    if (matches.length > 0) return viewAll();
    if (suggestion) return goTo(suggestion);
    if (q.trim()) toast(`No tools found for "${q.trim()}"`, 'error');
  };

  const onKeyDown = (e: ReactKeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setOpen(true); setActive((a) => Math.min(a + 1, results.length - 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)); }
    else if (e.key === 'Enter') { e.preventDefault(); search(); }
    else if (e.key === 'Escape') { setOpen(false); inputRef.current?.blur(); }
  };

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [open]);

  /* Voice search */
  const toggleVoice = () => {
    if (listening) { recogRef.current?.stop(); return; }
    const Ctor = getSpeechRecognition();
    if (!Ctor) return;
    const recog = new Ctor();
    recog.lang = 'en-IN';
    recog.interimResults = false;
    recog.maxAlternatives = 1;
    recog.onresult = (ev) => {
      const text = ev.results[0]?.[0]?.transcript ?? '';
      if (text) { setQ(text); setActive(0); setOpen(true); }
    };
    recog.onend = () => setListening(false);
    recog.onerror = () => { setListening(false); toast('Voice search unavailable — check mic permission', 'error'); };
    recogRef.current = recog;
    setListening(true);
    try { recog.start(); } catch { setListening(false); }
  };

  const showPanel = open && (q.trim() !== '' || recent.length > 0 || TRENDING.length > 0);

  return (
    <section className="hero hero-os" ref={sectionRef} onPointerMove={onHeroMove}>
      {booting && <AiBoot onDone={() => setBooting(false)} />}

      {/* Premium ambient background: aurora + rays + noise + particles + mouse light */}
      <div className="hero-aurora" aria-hidden="true" />
      <div className="hero-rays" aria-hidden="true" />
      <div className="hero-ambient" aria-hidden="true" />
      <div className="hero-particles" aria-hidden="true">
        {PARTICLES.map((p, i) => (
          <span key={i} className="hero-particle" style={{ left: p.left, top: p.top, width: p.size, height: p.size, animationDelay: p.delay, animationDuration: p.dur }} />
        ))}
      </div>

      <div className="container hero-grid">
        {/* ───────── Left ───────── */}
        <div className="hero-left">
          <span className="eyebrow"><Icon name="sparkles" size={14} /> AI-Powered Productivity Ecosystem</span>
          <h1 className="hero-h1">
            Build Beyond.<br />
            Create Faster.<br />
            <span className="gradient-text">Powered by AI.</span>
          </h1>
          <p className="hero-sub">150+ powerful tools, AI assistant, and smart workflows — all in one place to supercharge your productivity.</p>

          <div className="hero-search-wrap" ref={wrapRef}>
            <div className={`hero-search${showPanel ? ' is-open' : ''}${listening ? ' is-listening' : ''}${q.trim() ? ' is-syncing' : ''}`} role="search">
              <Icon name="search" size={18} className="hero-search-lead" />
              <input
                ref={inputRef}
                value={q}
                placeholder={PLACEHOLDERS[phIdx]}
                onChange={(e) => { setQ(e.target.value); setActive(0); setOpen(true); }}
                onFocus={() => { if (!programmaticFocus.current) setOpen(true); }}
                onKeyDown={onKeyDown}
                aria-label="Search any tool"
                aria-expanded={showPanel}
                aria-autocomplete="list"
                autoComplete="off"
                enterKeyHint="search"
              />
              {!q && <kbd className="hero-kbd" aria-hidden="true">/</kbd>}
              {q && (
                <button className="hero-search-clear" onClick={() => { setQ(''); setActive(0); inputRef.current?.focus(); }} aria-label="Clear search">
                  <Icon name="x" size={16} />
                </button>
              )}
              {voiceReady && (
                <button
                  className={`hero-voice${listening ? ' listening' : ''}`}
                  onClick={toggleVoice}
                  aria-label={listening ? 'Stop voice search' : 'Search by voice'}
                  aria-pressed={listening}
                >
                  {listening ? (
                    <span className="voice-wave" aria-hidden="true"><i /><i /><i /><i /></span>
                  ) : (
                    <Icon name="mic" size={16} />
                  )}
                </button>
              )}
              <button className="hero-search-btn" onClick={search} aria-label="Search" aria-busy={navigating}>
                {navigating ? <span className="btn-spinner" aria-hidden="true" /> : <Icon name="search" size={18} />}
              </button>
            </div>
            {listening && <span className="sr-only" role="status">Listening for voice search</span>}

            {showPanel && (
              <div className="hero-suggest" role="listbox">
                {q.trim() ? (
                  results.length > 0 ? (
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
                      {suggestion && (
                        <button type="button" className="hero-didyoumean" onClick={() => goTo(suggestion)}>
                          Did you mean <b>{suggestion.name}</b>?
                        </button>
                      )}
                      <Link href="/tools" className="link-btn" onClick={() => setOpen(false)}>Browse all 150+ tools →</Link>
                    </div>
                  )
                ) : (
                  <div className="hero-suggest-zero">
                    {recent.length > 0 && (
                      <>
                        <div className="hs-group-label"><Icon name="refresh" size={13} /> Recent</div>
                        {recent.map((r) => (
                          <button key={r} type="button" className="hs-quick" onClick={() => { setQ(r); setActive(0); inputRef.current?.focus(); }}>
                            {r}
                          </button>
                        ))}
                      </>
                    )}
                    <div className="hs-group-label"><Icon name="sparkles" size={13} /> Trending</div>
                    {TRENDING.map((t) => (
                      <button key={t} type="button" className="hs-quick" onClick={() => { setQ(t); setActive(0); inputRef.current?.focus(); }}>
                        {t}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="trending-block">
            <span className="trending-label"><i className="trending-dot" aria-hidden="true" /> 🔥 Trending Tools</span>
            <div className="chips">
              {Object.entries(chipMap).map(([label, href]) => (
                <Link key={label} href={href} className="chip" onPointerDown={spawnRipple}>{label}</Link>
              ))}
              <Link href="/tools" className="chip chip-more" onPointerDown={spawnRipple}>More <Icon name="chevron-right" size={13} /></Link>
            </div>
          </div>

          <div className="cta-row">
            <Link
              href="/tools"
              className="btn btn-primary btn-magnetic"
              aria-busy={ctaLoading}
              onPointerDown={spawnRipple}
              onPointerMove={onMagnetMove}
              onPointerLeave={onMagnetLeave}
              onClick={() => setCtaLoading(true)}
            >
              {ctaLoading ? <span className="btn-spinner" aria-hidden="true" /> : null}
              Explore All Tools {!ctaLoading && <Icon name="arrow-right" size={16} />}
            </Link>
            <button
              className="btn btn-outline btn-glass btn-magnetic"
              onClick={openAI}
              onPointerMove={onMagnetMove}
              onPointerLeave={onMagnetLeave}
            >
              <Icon name="sparkles" size={15} /> Try AI Assistant
            </button>
          </div>

          <div className="social-proof">
            <div className="avatars">
              {['#6c4dff', '#a855f7', '#3b82f6', '#22c55e', '#f97316'].map((c, i) => (
                <span key={i} className="avatar-c" style={{ background: c }}>{'FARVI'[i]}</span>
              ))}
              {stats && <span className="avatar-c avatar-count">{formatCount(stats.users)}+</span>}
            </div>
            <div>
              <div className="stars" aria-label="Five star rated">★★★★★</div>
              <div className="proof-text">
                {stats
                  ? `Trusted by ${formatCount(stats.users)}+ users worldwide`
                  : 'Trusted by developers, creators, students and businesses worldwide.'}
              </div>
            </div>
          </div>
        </div>

        {/* ───────── Center — AI CORE ENGINE ───────── */}
        <div
          className="hero-visual ai-visual"
          aria-hidden="true"
          ref={visualRef}
          onPointerMove={onVisualMove}
          onPointerLeave={onVisualLeave}
        >
          <div className="ai-globe" />
          <div className="ai-stage" ref={stageRef}>
            {/* Farvixo Intelligence Engine — a living, self-generating AI Core */}
            <AiCore query={q} />
          </div>
          <div className="cube-reflect" />
        </div>

        {/* ───────── Right — FARVIXO AI ASSISTANT ───────── */}
        <aside className="ai-panel-card glass" aria-label="Farvixo AI assistant">
          <div className="ai-panel-head">
            <span className="ai-avatar"><Icon name="bot" size={18} /></span>
            <b>Farvixo AI Assistant</b>
            <span className="ai-online"><i /> Online</span>
          </div>

          <div className="ai-bubble">
            <p className="ai-greet">{greeting}</p>
            <p className="ai-typing" aria-live="polite">
              {typed}
              <span className="ai-caret" aria-hidden="true" />
            </p>
          </div>

          {syncTool ? (
            <>
              <p className="ai-try-label">Found it for you</p>
              <button type="button" className="ai-ask-row ai-sync-suggest" onClick={() => goTo(syncTool)}>
                <span className="ai-ask-icon"><Icon name={syncTool.icon} size={14} /></span>
                Open {syncTool.name}
                <Icon name="chevron-right" size={14} className="ai-ask-chev" />
              </button>
            </>
          ) : (
            <>
              <p className="ai-try-label">You can try asking me</p>
              <ul className="ai-ask-list">
                {[
                  { label: 'Convert PDF to Word', href: '/tools/pdf/pdf-to-word', icon: 'file-text' },
                  { label: 'Remove Background', href: '/tools/image/background-remover', icon: 'eraser' },
                  { label: 'Summarize any text', href: '/tools/ai/ai-summarizer', icon: 'scan-text' },
                  { label: 'Generate QR Code', href: '/tools/utility/qr-code-generator', icon: 'qr' },
                  { label: 'Write with AI', href: '/tools/ai/ai-writer', icon: 'pen' },
                ].map((a) => (
                  <li key={a.label}>
                    <Link href={a.href} className="ai-ask-row">
                      <span className="ai-ask-icon"><Icon name={a.icon} size={14} /></span>
                      {a.label}
                      <Icon name="chevron-right" size={14} className="ai-ask-chev" />
                    </Link>
                  </li>
                ))}
              </ul>
            </>
          )}

          <button type="button" className="ai-ask-input" onClick={openAI} aria-label="Ask the AI assistant anything">
            <span>Ask anything...</span>
            <span className="ai-ask-send"><Icon name="send" size={14} /></span>
          </button>
          <p className="why-note"><Icon name="sparkles" size={11} /> Powered by Advanced AI Models</p>
        </aside>
      </div>

    </section>
  );
}
