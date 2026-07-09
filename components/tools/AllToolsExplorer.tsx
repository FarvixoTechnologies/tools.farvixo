'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Icon from '@/components/Icon';
import { categories, getCategory } from '@/data/categories';
import { collections } from '@/data/collections';
import { tools, type Tool } from '@/data/tools';
import { formatCount } from '@/lib/format-count';
import { getPinnedTools, getRecentTools, togglePinnedTool } from '@/lib/tool-usage';

/* ─── Derivations ─────────────────────────────────────────────────────────── */

type InputKind = 'PDF' | 'Image' | 'Video' | 'Audio' | 'Doc' | 'Text';

function inputKind(t: Tool): InputKind {
  const a = (t.accept ?? '').toLowerCase();
  if (!a) return 'Text';
  if (a.includes('pdf')) return 'PDF';
  if (a.includes('image')) return 'Image';
  if (a.includes('video')) return 'Video';
  if (a.includes('audio')) return 'Audio';
  return 'Doc';
}

function isAiTool(t: Tool): boolean {
  return t.runner.startsWith('ai') || t.runner === 'resume' || t.runner === 'presentation' || t.badge === 'ai';
}

const EXT_TO_KIND: Record<string, InputKind> = {
  pdf: 'PDF',
  jpg: 'Image', jpeg: 'Image', png: 'Image', webp: 'Image', gif: 'Image', bmp: 'Image', avif: 'Image', heic: 'Image', svg: 'Image',
  mp4: 'Video', mkv: 'Video', mov: 'Video', avi: 'Video', webm: 'Video',
  mp3: 'Audio', wav: 'Audio', m4a: 'Audio', ogg: 'Audio', flac: 'Audio',
  doc: 'Doc', docx: 'Doc', xls: 'Doc', xlsx: 'Doc', csv: 'Doc', txt: 'Doc', md: 'Doc', html: 'Doc', json: 'Doc', xml: 'Doc', zip: 'Doc',
};

function toolAcceptsExt(t: Tool, ext: string): boolean {
  const a = (t.accept ?? '').toLowerCase();
  if (!a) return false;
  if (a.includes(`.${ext}`)) return true;
  const kind = EXT_TO_KIND[ext];
  if (kind === 'Image' && a.includes('image')) return true;
  if (kind === 'Video' && a.includes('video')) return true;
  if (kind === 'Audio' && a.includes('audio')) return true;
  if (kind === 'PDF' && a.includes('pdf')) return true;
  return false;
}

/* Hinglish / Bengali synonyms → search terms */
const SYNONYMS: Array<[RegExp, string]> = [
  [/chota|choti|kam karo|size kam|ছোট/i, 'compress'],
  [/photo|tasvir|ছবি/i, 'image'],
  [/hatao|remove|মুছে/i, 'remove'],
  [/jodo|jod|milao|জোড়া/i, 'merge'],
  [/kato|kaat|কাটা/i, 'split trim cut'],
  [/badlo|convert|বদল/i, 'converter'],
  [/likho|lekh|লেখা/i, 'writer text'],
  [/awaz|awaaz|শব্দ/i, 'audio'],
  [/pan ?card/i, 'pan card photo resizer'],
  [/aadhaa?r|আধার/i, 'aadhaar'],
  [/voter|ভোটার/i, 'voter'],
  [/naukri|chakri|চাকরি/i, 'resume'],
];

function expandQuery(q: string): string {
  let out = q;
  for (const [re, add] of SYNONYMS) if (re.test(q)) out += ` ${add}`;
  return out;
}

function searchScore(t: Tool, q: string): number {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean);
  const hay = `${t.name} ${t.description} ${t.category} ${(t.keywords || []).join(' ')}`.toLowerCase();
  const name = t.name.toLowerCase();
  let score = 0;
  if (name === q) score += 100;
  if (name.startsWith(q)) score += 50;
  if (name.includes(q)) score += 30;
  for (const w of words) if (hay.includes(w)) score += 10;
  return score;
}

/* ─── Component ───────────────────────────────────────────────────────────── */

type Density = 'comfortable' | 'compact' | 'list';
type Filter = 'all' | 'PDF' | 'Image' | 'Video' | 'Audio' | 'Text' | 'ai' | 'local';

const bySlug = new Map(tools.map((t) => [t.slug, t]));

export default function AllToolsExplorer() {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [density, setDensity] = useState<Density>('comfortable');
  const [sort, setSort] = useState<'category' | 'popular' | 'az'>('category');
  const [pins, setPins] = useState<string[]>([]);
  const [recents, setRecents] = useState<string[]>([]);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [droppedExt, setDroppedExt] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const [listening, setListening] = useState(false);
  const searchRef = useRef<HTMLInputElement>(null);
  const gridRef = useRef<HTMLDivElement>(null);

  // Seed the search from a ?q= param (e.g. coming from the homepage hero search).
  useEffect(() => {
    const q = new URLSearchParams(window.location.search).get('q');
    if (q) setQuery(q);
  }, []);

  /* hydrate client state */
  useEffect(() => {
    setPins(getPinnedTools());
    setRecents(getRecentTools());
    try {
      const d = localStorage.getItem('tn-tools-density') as Density | null;
      if (d === 'comfortable' || d === 'compact' || d === 'list') setDensity(d);
    } catch { /* ignore */ }
    (async () => {
      try {
        const res = await fetch('/api/stats/tools');
        const json = (await res.json()) as { success: boolean; data?: { counts: Record<string, number> } };
        if (json.success && json.data) setCounts(json.data.counts);
      } catch { /* counts stay empty */ }
    })();
  }, []);

  const setDensityPersist = (d: Density) => {
    setDensity(d);
    try { localStorage.setItem('tn-tools-density', d); } catch { /* ignore */ }
  };

  /* keyboard: "/" focuses search, "p" pins the focused card */
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement).tagName;
      const typing = tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
      if (e.key === '/' && !typing) {
        e.preventDefault();
        searchRef.current?.focus();
      } else if (e.key.toLowerCase() === 'p' && !typing) {
        const active = document.activeElement as HTMLElement | null;
        const slug = active?.dataset?.toolSlug;
        if (slug) { e.preventDefault(); setPins(togglePinnedTool(slug)); }
      } else if ((e.key === 'ArrowRight' || e.key === 'ArrowLeft' || e.key === 'ArrowDown' || e.key === 'ArrowUp') && !typing) {
        const cards = Array.from(gridRef.current?.querySelectorAll<HTMLElement>('[data-tool-slug]') ?? []);
        if (cards.length === 0) return;
        const idx = cards.indexOf(document.activeElement as HTMLElement);
        if (idx === -1) return;
        e.preventDefault();
        const cols = Math.max(1, Math.round((gridRef.current?.clientWidth ?? 1000) / (cards[0].clientWidth + 16)));
        const next =
          e.key === 'ArrowRight' ? idx + 1 :
          e.key === 'ArrowLeft' ? idx - 1 :
          e.key === 'ArrowDown' ? idx + cols : idx - cols;
        cards[Math.max(0, Math.min(cards.length - 1, next))]?.focus();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  /* voice search (Chrome/Edge/Android) */
  const startVoice = useCallback(() => {
    const W = window as unknown as { webkitSpeechRecognition?: new () => {
      lang: string; onresult: (e: { results: { 0: { 0: { transcript: string } } } }) => void;
      onend: () => void; start: () => void;
    } };
    if (!W.webkitSpeechRecognition) return;
    const rec = new W.webkitSpeechRecognition();
    rec.lang = 'en-IN';
    rec.onresult = (e) => setQuery(e.results[0][0].transcript);
    rec.onend = () => setListening(false);
    setListening(true);
    rec.start();
  }, []);
  const voiceAvailable = typeof window !== 'undefined' && 'webkitSpeechRecognition' in window;

  /* file-drop tool finder */
  useEffect(() => {
    const over = (e: DragEvent) => {
      if (e.dataTransfer?.types.includes('Files')) { e.preventDefault(); setDragOver(true); }
    };
    const leave = (e: DragEvent) => { if (!e.relatedTarget) setDragOver(false); };
    const drop = (e: DragEvent) => {
      if (!e.dataTransfer?.files.length) return;
      e.preventDefault();
      setDragOver(false);
      const name = e.dataTransfer.files[0].name;
      const ext = name.split('.').pop()?.toLowerCase() ?? '';
      if (ext) { setDroppedExt(ext); setQuery(''); setFilter('all'); }
    };
    document.addEventListener('dragover', over);
    document.addEventListener('dragleave', leave);
    document.addEventListener('drop', drop);
    return () => {
      document.removeEventListener('dragover', over);
      document.removeEventListener('dragleave', leave);
      document.removeEventListener('drop', drop);
    };
  }, []);

  /* filtering pipeline */
  const filtered = useMemo(() => {
    let list = tools;
    if (droppedExt) list = list.filter((t) => toolAcceptsExt(t, droppedExt));
    if (filter === 'ai') list = list.filter(isAiTool);
    else if (filter === 'local') list = list.filter((t) => !isAiTool(t));
    else if (filter !== 'all') list = list.filter((t) => inputKind(t) === filter);

    const q = expandQuery(query.trim().toLowerCase());
    if (q) {
      list = list
        .map((t) => ({ t, s: searchScore(t, q) }))
        .filter((r) => r.s > 0)
        .sort((a, b) => b.s - a.s)
        .map((r) => r.t);
    } else if (sort === 'popular') {
      list = [...list].sort((a, b) => (counts[b.slug] ?? 0) - (counts[a.slug] ?? 0));
    } else if (sort === 'az') {
      list = [...list].sort((a, b) => a.name.localeCompare(b.name));
    }
    return list;
  }, [query, filter, sort, counts, droppedExt]);

  const isBrowsing = !query.trim() && !droppedExt && filter === 'all' && sort === 'category';
  const recentTools = recents.map((s) => bySlug.get(s)).filter((t): t is Tool => !!t);
  const pinnedTools = pins.map((s) => bySlug.get(s)).filter((t): t is Tool => !!t);

  const gridClass = `tool-grid ${density === 'list' ? 'list-view' : ''} ${density === 'compact' ? 'grid-compact' : ''}`;

  const card = (t: Tool) => (
    <ExplorerCard
      key={t.slug}
      tool={t}
      pinned={pins.includes(t.slug)}
      uses={counts[t.slug] ?? 0}
      onPin={() => setPins(togglePinnedTool(t.slug))}
    />
  );

  const filterChips: Array<{ id: Filter; label: string; icon?: string }> = [
    { id: 'all', label: 'All' },
    { id: 'PDF', label: 'PDF' },
    { id: 'Image', label: 'Image' },
    { id: 'Video', label: 'Video' },
    { id: 'Audio', label: 'Audio' },
    { id: 'Text', label: 'No file' },
    { id: 'ai', label: 'AI-powered', icon: 'sparkles' },
    { id: 'local', label: '100% offline', icon: 'lock' },
  ];

  return (
    <div className="atx" ref={gridRef}>
      {dragOver && (
        <div className="atx-drop-overlay" aria-hidden>
          <Icon name="upload" size={40} />
          <b>Drop your file — matching tools milenge</b>
        </div>
      )}

      {/* Task box */}
      <div className="atx-taskbox glass">
        <Icon name="search" size={18} />
        <input
          ref={searchRef}
          value={query}
          onChange={(e) => { setQuery(e.target.value); setDroppedExt(null); }}
          placeholder='Describe your task… e.g. "pan card photo 20kb" ya "pdf chota karo"'
          aria-label="Search 130 tools"
        />
        {voiceAvailable && (
          <button className={`atx-voice ${listening ? 'listening' : ''}`} onClick={startVoice} aria-label="Voice search" title="Voice search">
            <Icon name="mic" size={16} />
          </button>
        )}
        <span className="atx-kbd">/</span>
      </div>

      {/* Filter chips + view controls */}
      <div className="atx-controls">
        <div className="atx-chips" role="tablist" aria-label="Filter tools">
          {filterChips.map((c) => (
            <button
              key={c.id}
              role="tab"
              aria-selected={filter === c.id}
              className={`atx-chip ${filter === c.id ? 'active' : ''}`}
              onClick={() => setFilter(filter === c.id ? 'all' : c.id)}
            >
              {c.icon && <Icon name={c.icon} size={12} />} {c.label}
            </button>
          ))}
        </div>
        <div className="atx-view">
          <select value={sort} onChange={(e) => setSort(e.target.value as typeof sort)} aria-label="Sort tools">
            <option value="category">By category</option>
            <option value="popular">Most used</option>
            <option value="az">A–Z</option>
          </select>
          <div className="atx-density" role="group" aria-label="View density">
            {(['comfortable', 'compact', 'list'] as Density[]).map((d) => (
              <button
                key={d}
                className={density === d ? 'active' : ''}
                onClick={() => setDensityPersist(d)}
                aria-label={`${d} view`}
                title={d}
              >
                <Icon name={d === 'list' ? 'list' : d === 'compact' ? 'table' : 'grid'} size={14} />
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Dropped-file banner */}
      {droppedExt && (
        <div className="atx-dropped">
          <Icon name="file-text" size={14} />
          Showing {filtered.length} tools that accept <b>.{droppedExt}</b>
          <button onClick={() => setDroppedExt(null)} aria-label="Clear file filter"><Icon name="x" size={13} /></button>
        </div>
      )}

      {isBrowsing ? (
        <>
          {/* Pinned */}
          {pinnedTools.length > 0 && (
            <section className="atx-rail">
              <h2><Icon name="star" size={16} /> Pinned</h2>
              <div className={gridClass}>{pinnedTools.map(card)}</div>
            </section>
          )}

          {/* Recently used */}
          {recentTools.length > 0 && (
            <section className="atx-rail">
              <h2><Icon name="clock" size={16} /> Recently used</h2>
              <div className={gridClass}>{recentTools.slice(0, 5).map(card)}</div>
            </section>
          )}

          {/* Collections */}
          <section className="atx-rail">
            <h2><Icon name="grid" size={16} /> Kits — ek kaam, poora bundle</h2>
            <div className="atx-collections">
              {collections.map((c) => (
                <div key={c.slug} className="atx-collection glass">
                  <span className="atx-collection-icon" style={{ background: `var(--${c.accent})` }}>
                    <Icon name={c.icon} size={18} />
                  </span>
                  <b>{c.name}</b>
                  <p>{c.description}</p>
                  <div className="atx-collection-tools">
                    {c.tools.map((s) => {
                      const t = bySlug.get(s);
                      return t ? (
                        <Link key={s} href={`/tools/${t.category}/${t.slug}`}>{t.name}</Link>
                      ) : null;
                    })}
                  </div>
                </div>
              ))}
            </div>
          </section>

          {/* Categories */}
          {categories.map((cat) => {
            const catTools = tools.filter((t) => t.category === cat.slug);
            if (catTools.length === 0) return null;
            return (
              <section key={cat.slug} className="atx-rail" id={cat.slug}>
                <div className="atx-rail-head">
                  <h2>
                    <span className="tool-icon atx-cat-icon" style={{ background: `var(--${cat.accent})` }}>
                      <Icon name={cat.icon} size={15} />
                    </span>
                    {cat.name} <span className="atx-count">({catTools.length})</span>
                  </h2>
                  <Link href={`/tools/${cat.slug}`} className="btn btn-ghost btn-sm">
                    View category <Icon name="arrow-right" size={13} />
                  </Link>
                </div>
                <div className={gridClass}>{catTools.map(card)}</div>
              </section>
            );
          })}
        </>
      ) : (
        <section className="atx-rail">
          <h2>{filtered.length} tool{filtered.length === 1 ? '' : 's'} {query ? `for "${query}"` : ''}</h2>
          {filtered.length === 0 ? (
            <div className="atx-empty">
              <p>Kuch nahi mila. Try: &quot;compress&quot;, &quot;pan card&quot;, &quot;pdf to word&quot;…</p>
              <button className="btn btn-ghost btn-sm" onClick={() => { setQuery(''); setFilter('all'); setDroppedExt(null); setSort('category'); }}>
                Browse all {tools.length} tools
              </button>
            </div>
          ) : (
            <div className={gridClass}>{filtered.map(card)}</div>
          )}
        </section>
      )}
    </div>
  );
}

/* ─── Card ────────────────────────────────────────────────────────────────── */

function ExplorerCard({ tool, pinned, uses, onPin }: { tool: Tool; pinned: boolean; uses: number; onPin: () => void }) {
  const cat = getCategory(tool.category);
  const accent = `var(--${cat?.accent || 'brand-primary'})`;
  const kind = inputKind(tool);
  const ai = isAiTool(tool);

  return (
    <Link
      href={`/tools/${tool.category}/${tool.slug}`}
      className="tool-card atx-card"
      style={{ '--card-accent': accent } as React.CSSProperties}
      data-tool-slug={tool.slug}
    >
      <span className="tool-icon" style={{ background: accent }}>
        <Icon name={tool.icon} size={21} />
      </span>
      <button
        className={`atx-pin ${pinned ? 'pinned' : ''}`}
        aria-label={pinned ? 'Unpin tool' : 'Pin tool'}
        title={pinned ? 'Unpin (p)' : 'Pin (p)'}
        onClick={(e) => { e.preventDefault(); e.stopPropagation(); onPin(); }}
      >
        <Icon name="star" size={13} />
      </button>
      {(tool.badge === 'new' || tool.badge === 'ai') && (
        <span className="tool-badge">
          <span className={`pill ${tool.badge === 'new' ? 'pill-new' : 'pill-ai'}`}>{tool.badge.toUpperCase()}</span>
        </span>
      )}
      <span className="tool-name">{tool.name}</span>
      <span className="tool-desc">{tool.description}</span>
      <span className="atx-meta">
        <span className="atx-io">{kind === 'Text' ? 'No file' : kind}</span>
        <span className={`atx-privacy ${ai ? 'ai' : 'local'}`}>
          <Icon name={ai ? 'sparkles' : 'lock'} size={10} /> {ai ? 'AI' : 'Local'}
        </span>
        {uses > 0 && <span className="atx-uses">{formatCount(uses)} uses</span>}
      </span>
      <span className="tool-foot">
        <span className="tool-tag">{tool.badge === 'popular' ? 'Popular' : cat?.shortName}</span>
        <span className="tool-arrow"><Icon name="arrow-right" size={14} /></span>
      </span>
    </Link>
  );
}
