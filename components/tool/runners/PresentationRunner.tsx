'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { ErrorBox, useToolPhase } from '../shared';
import { aiComplete } from '@/lib/ai';
import Icon from '../../Icon';

/* ─────────────────────────────  Model  ───────────────────────────── */

type Layout = 'title' | 'section' | 'bullets' | 'twoColumn' | 'quote';

interface Slide {
  id: string;
  layout: Layout;
  title: string;
  subtitle?: string;
  bullets: string[];
  bullets2?: string[];
  notes?: string;
}

interface Deck {
  title: string;
  subtitle: string;
  slides: Slide[];
}

interface Theme {
  id: string;
  name: string;
  bg: string;
  surface: string;
  text: string;
  muted: string;
  accent: string;
  accent2: string;
  font: string;
}

const THEMES: Theme[] = [
  { id: 'nebula', name: 'Nebula', bg: '0A0A12', surface: '12121C', text: 'F5F5FA', muted: 'A0A0B8', accent: '6C4DFF', accent2: 'C026D3', font: 'Arial' },
  { id: 'aurora', name: 'Aurora', bg: '05161A', surface: '0B2027', text: 'ECFEFF', muted: '8CC6CE', accent: '22C55E', accent2: '06B6D4', font: 'Arial' },
  { id: 'ember', name: 'Ember', bg: '1A0B06', surface: '241109', text: 'FFF7ED', muted: 'D6B8A6', accent: 'F97316', accent2: 'EF4444', font: 'Arial' },
  { id: 'ivory', name: 'Ivory', bg: 'F7F7FB', surface: 'FFFFFF', text: '14141F', muted: '5B5B72', accent: '7C3AED', accent2: 'C026D3', font: 'Georgia' },
  { id: 'slate', name: 'Slate', bg: '0F172A', surface: '1E293B', text: 'F1F5F9', muted: '94A3B8', accent: '3B82F6', accent2: '6366F1', font: 'Arial' },
];

const LAYOUTS: { id: Layout; label: string }[] = [
  { id: 'title', label: 'Title' },
  { id: 'section', label: 'Section' },
  { id: 'bullets', label: 'Bullets' },
  { id: 'twoColumn', label: 'Two column' },
  { id: 'quote', label: 'Quote' },
];

/* ─────────────────────────────  Helpers  ───────────────────────────── */

const uid = () => Math.random().toString(36).slice(2, 10);
const hex = (c: string) => `#${c}`;

// Models sometimes emit raw newlines/tabs INSIDE JSON string values, which is
// invalid JSON ("Bad control character in string literal"). Escape control
// chars that fall inside a string literal so JSON.parse succeeds.
function sanitizeJson(s: string): string {
  let inStr = false;
  let escaped = false;
  let out = '';
  for (const ch of s) {
    const code = ch.charCodeAt(0);
    if (inStr && !escaped && code < 0x20) {
      out += ch === '\n' ? '\\n' : ch === '\r' ? '\\r' : ch === '\t' ? '\\t' : ' ';
      continue;
    }
    if (escaped) escaped = false;
    else if (ch === '\\') escaped = true;
    else if (ch === '"') inStr = !inStr;
    out += ch;
  }
  return out;
}

function extractJson(raw: string): string {
  const cleaned = raw.replace(/```json|```/g, '').trim();
  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  return sanitizeJson(start >= 0 && end > start ? cleaned.slice(start, end + 1) : cleaned);
}

function parseDeck(raw: string, topic: string): Deck {
  const parsed = JSON.parse(extractJson(raw)) as { title?: string; subtitle?: string; slides?: Partial<Slide>[] };
  const slides: Slide[] = (parsed.slides || []).map((s, i) => ({
    id: uid(),
    layout: (s.layout && LAYOUTS.some((l) => l.id === s.layout) ? s.layout : (i === 0 ? 'title' : 'bullets')) as Layout,
    title: s.title || `Slide ${i + 1}`,
    subtitle: s.subtitle,
    bullets: Array.isArray(s.bullets) ? s.bullets.filter(Boolean) : [],
    bullets2: Array.isArray(s.bullets2) ? s.bullets2.filter(Boolean) : undefined,
    notes: s.notes,
  }));
  if (!slides.length) throw new Error('AI returned no slides');
  return { title: parsed.title || topic, subtitle: parsed.subtitle || '', slides };
}

/* ─────────────────────────────  Component  ───────────────────────────── */

export default function PresentationRunner() {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [topic, setTopic] = useState('');
  const [slideCount, setSlideCount] = useState(8);
  const [audience, setAudience] = useState('general');
  const [status, setStatus] = useState('');
  const [streamPreview, setStreamPreview] = useState('');

  const [deck, setDeck] = useState<Deck | null>(null);
  const [themeId, setThemeId] = useState('nebula');
  const [active, setActive] = useState(0);
  const [present, setPresent] = useState(false);
  const [busySlide, setBusySlide] = useState<string | null>(null);
  const [exportOpen, setExportOpen] = useState(false);

  const theme = THEMES.find((t) => t.id === themeId) ?? THEMES[0];
  const slides = deck?.slides ?? [];
  const current = slides[active];

  /* ---- Generate deck ---- */
  const generate = async () => {
    if (!topic.trim()) return;
    setPhase('working');
    setStreamPreview('');
    setStatus('Farvixo AI is designing your deck…');
    try {
      const raw = await aiComplete(
        [{ role: 'user', content: `Topic: ${topic}\nAudience: ${audience}\nCreate exactly ${slideCount} slides.` }],
        `You are a world-class presentation designer. Return ONLY valid JSON, no markdown fences.
Schema: {"title":string,"subtitle":string,"slides":[{"layout":"title"|"section"|"bullets"|"twoColumn"|"quote","title":string,"subtitle":string,"bullets":string[],"bullets2":string[],"notes":string}]}
Rules: first slide layout "title". Use "section" dividers for major parts, "quote" for a memorable insight, "twoColumn" to compare (fill bullets and bullets2), otherwise "bullets" with 3-5 concise, punchy points. Every slide has 1-2 sentence speaker "notes". Total exactly ${slideCount} slides.`,
        (full) => setStreamPreview(full.slice(-400)),
        { temperature: 0.8 },
      );
      const d = parseDeck(raw, topic);
      setDeck(d);
      setActive(0);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  /* ---- Slide editing ---- */
  const patchSlide = useCallback((id: string, patch: Partial<Slide>) => {
    setDeck((d) => d && { ...d, slides: d.slides.map((s) => (s.id === id ? { ...s, ...patch } : s)) });
  }, []);

  const addSlide = () => {
    setDeck((d) => {
      if (!d) return d;
      const s: Slide = { id: uid(), layout: 'bullets', title: 'New slide', bullets: ['Point one', 'Point two'] };
      const slidesN = [...d.slides];
      slidesN.splice(active + 1, 0, s);
      return { ...d, slides: slidesN };
    });
    setActive((a) => a + 1);
  };

  const deleteSlide = (id: string) => {
    setDeck((d) => d && d.slides.length > 1 ? { ...d, slides: d.slides.filter((s) => s.id !== id) } : d);
    setActive((a) => Math.max(0, a - 1));
  };

  const move = (id: string, dir: -1 | 1) => {
    setDeck((d) => {
      if (!d) return d;
      const i = d.slides.findIndex((s) => s.id === id);
      const j = i + dir;
      if (j < 0 || j >= d.slides.length) return d;
      const slidesN = [...d.slides];
      [slidesN[i], slidesN[j]] = [slidesN[j], slidesN[i]];
      return { ...d, slides: slidesN };
    });
    setActive((a) => Math.min(Math.max(0, a + dir), slides.length - 1));
  };

  /* ---- AI: rewrite / expand a single slide ---- */
  const enhanceSlide = async (slide: Slide, mode: 'expand' | 'concise') => {
    setBusySlide(slide.id);
    try {
      const raw = await aiComplete(
        [{ role: 'user', content: `Slide title: ${slide.title}\nCurrent bullets: ${slide.bullets.join(' | ')}\nDeck topic: ${deck?.title}` }],
        `Rewrite this slide's bullet points to be ${mode === 'expand' ? 'more detailed and persuasive (4-5 bullets)' : 'tighter and punchier (3 bullets max)'}. Return ONLY JSON: {"title":string,"bullets":string[],"notes":string}`,
        undefined,
        { temperature: 0.7 },
      );
      const p = JSON.parse(extractJson(raw)) as Partial<Slide>;
      patchSlide(slide.id, {
        title: p.title || slide.title,
        bullets: Array.isArray(p.bullets) ? p.bullets.filter(Boolean) : slide.bullets,
        notes: p.notes || slide.notes,
      });
    } catch (e) {
      fail(e);
    } finally {
      setBusySlide(null);
    }
  };

  /* ---- Export PPTX ---- */
  const exportPptx = async () => {
    if (!deck) return;
    setStatus('Building PowerPoint…');
    const PptxGenJS = (await import('pptxgenjs')).default;
    const pptx = new PptxGenJS();
    pptx.defineLayout({ name: 'WIDE', width: 13.33, height: 7.5 });
    pptx.layout = 'WIDE';
    pptx.author = 'Farvixo AI';
    pptx.title = deck.title;

    for (const s of deck.slides) {
      const slide = pptx.addSlide();
      slide.background = { color: s.layout === 'title' || s.layout === 'section' ? theme.bg : theme.surface };
      if (s.notes) slide.addNotes(s.notes);

      if (s.layout === 'title' || s.layout === 'section') {
        slide.addShape('rect', { x: 0.8, y: 4.0, w: 2.6, h: 0.08, fill: { color: theme.accent } });
        slide.addText(s.title, { x: 0.8, y: 2.5, w: 11.7, h: 1.6, fontSize: s.layout === 'title' ? 44 : 36, bold: true, color: theme.text, fontFace: theme.font });
        if (s.subtitle) slide.addText(s.subtitle, { x: 0.8, y: 4.2, w: 11, h: 0.9, fontSize: 18, color: theme.muted, fontFace: theme.font });
        continue;
      }

      slide.addShape('rect', { x: 0, y: 0, w: 0.25, h: 7.5, fill: { color: theme.accent } });
      slide.addText(s.title, { x: 0.8, y: 0.5, w: 11.7, h: 1, fontSize: 30, bold: true, color: theme.text, fontFace: theme.font });

      if (s.layout === 'quote') {
        slide.addText(`“${s.bullets[0] || s.subtitle || s.title}”`, { x: 1.2, y: 2.4, w: 10.9, h: 2.6, fontSize: 28, italic: true, color: theme.text, fontFace: theme.font });
        if (s.subtitle) slide.addText(`— ${s.subtitle}`, { x: 1.2, y: 5.0, w: 10, h: 0.6, fontSize: 16, color: theme.muted });
        continue;
      }

      const bulletOpts = (b: string) => ({ text: b, options: { bullet: { code: '2022', indent: 18 }, color: theme.muted, fontSize: 17, breakLine: true, paraSpaceAfter: 12, fontFace: theme.font } });
      if (s.layout === 'twoColumn') {
        slide.addText(s.bullets.map(bulletOpts), { x: 0.9, y: 1.8, w: 5.6, h: 5.0, valign: 'top' });
        slide.addText((s.bullets2 || []).map(bulletOpts), { x: 6.9, y: 1.8, w: 5.6, h: 5.0, valign: 'top' });
      } else {
        slide.addText(s.bullets.map(bulletOpts), { x: 0.9, y: 1.8, w: 11.4, h: 5.2, valign: 'top' });
      }
    }

    const name = (deck.title || topic).slice(0, 40).replace(/[^a-z0-9]+/gi, '-') || 'presentation';
    await pptx.writeFile({ fileName: `${name}.pptx` });
    setStatus('');
  };

  /* ---- Export PDF (vector, via jsPDF) ---- */
  const exportPdf = async () => {
    if (!deck) return;
    setStatus('Rendering PDF…');
    const { jsPDF } = await import('jspdf');
    const doc = new jsPDF({ orientation: 'landscape', unit: 'pt', format: [1280, 720] });
    const rgb = (h: string): [number, number, number] => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
    const set = (fn: 'setFillColor' | 'setTextColor', h: string) => { const [r, g, b] = rgb(h); doc[fn](r, g, b); };

    deck.slides.forEach((s, idx) => {
      if (idx > 0) doc.addPage([1280, 720], 'landscape');
      const cover = s.layout === 'title' || s.layout === 'section';
      set('setFillColor', cover ? theme.bg : theme.surface);
      doc.rect(0, 0, 1280, 720, 'F');
      set('setFillColor', theme.accent);

      if (cover) {
        doc.rect(72, 300, 220, 8, 'F');
        set('setTextColor', theme.text);
        doc.setFont('helvetica', 'bold').setFontSize(s.layout === 'title' ? 60 : 46);
        doc.text(doc.splitTextToSize(s.title, 1100), 72, 250);
        if (s.subtitle) { set('setTextColor', theme.muted); doc.setFont('helvetica', 'normal').setFontSize(24); doc.text(s.subtitle, 72, 360); }
        return;
      }

      doc.rect(0, 0, 10, 720, 'F');
      set('setTextColor', theme.text);
      doc.setFont('helvetica', 'bold').setFontSize(40);
      doc.text(doc.splitTextToSize(s.title, 1120), 72, 110);

      if (s.layout === 'quote') {
        set('setTextColor', theme.text);
        doc.setFont('helvetica', 'italic').setFontSize(34);
        doc.text(doc.splitTextToSize(`“${s.bullets[0] || s.title}”`, 1080), 100, 320);
        return;
      }

      const drawBullets = (arr: string[], x: number, w: number) => {
        let y = 200;
        doc.setFont('helvetica', 'normal').setFontSize(22);
        for (const b of arr) {
          const lines = doc.splitTextToSize(b, w - 30) as string[];
          set('setFillColor', theme.accent); doc.circle(x + 6, y - 7, 5, 'F');
          set('setTextColor', theme.muted); doc.text(lines, x + 26, y);
          y += lines.length * 30 + 16;
        }
      };
      if (s.layout === 'twoColumn') { drawBullets(s.bullets, 72, 540); drawBullets(s.bullets2 || [], 660, 540); }
      else drawBullets(s.bullets, 72, 1120);
    });

    const name = (deck.title || topic).slice(0, 40).replace(/[^a-z0-9]+/gi, '-') || 'presentation';
    doc.save(`${name}.pdf`);
    setStatus('');
  };

  /* ---- Google Slides / Canva: both import .pptx ---- */
  const exportToService = async (service: 'slides' | 'canva') => {
    await exportPptx();
    const url = service === 'slides' ? 'https://slides.google.com/' : 'https://www.canva.com/import';
    window.open(url, '_blank', 'noopener');
    setStatus(`PPTX downloaded — in the ${service === 'slides' ? 'Google Slides' : 'Canva'} tab, choose Import / Upload and select the file.`);
  };

  const exportJson = () => {
    if (!deck) return;
    const blob = new Blob([JSON.stringify({ ...deck, theme: theme.id }, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `${(deck.title || 'deck').replace(/[^a-z0-9]+/gi, '-')}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  /* ---- Present mode keyboard nav ---- */
  useEffect(() => {
    if (!present) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown') setActive((a) => Math.min(a + 1, slides.length - 1));
      else if (e.key === 'ArrowLeft' || e.key === 'PageUp') setActive((a) => Math.max(a - 1, 0));
      else if (e.key === 'Escape') setPresent(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [present, slides.length]);

  /* ─────────────────────────────  Render  ───────────────────────────── */

  // Working / generating
  if (phase === 'working') {
    return (
      <div className="output-area" style={{ minHeight: 320, display: 'grid', placeItems: 'center', textAlign: 'center', gap: 14 }}>
        <div className="spinner" />
        <div>
          <p style={{ fontWeight: 600 }}>{status}</p>
          {streamPreview && <pre style={{ marginTop: 10, maxWidth: 560, fontSize: 11, color: 'var(--text-muted)', whiteSpace: 'pre-wrap', textAlign: 'left', maxHeight: 140, overflow: 'hidden' }}>{streamPreview}</pre>}
        </div>
      </div>
    );
  }

  // Setup screen (no deck yet)
  if (!deck) {
    return (
      <div className="workspace-grid">
        <div className="options-panel">
          <div className="field">
            <label>Presentation topic / outline</label>
            <textarea value={topic} placeholder="e.g. Digital Marketing Strategy 2026 for a SaaS startup" onChange={(e) => setTopic(e.target.value)} rows={4} />
          </div>
          <div className="field">
            <label>Audience</label>
            <select value={audience} onChange={(e) => setAudience(e.target.value)}>
              {['general', 'executives / investors', 'students', 'engineers', 'sales prospects', 'marketing team'].map((a) => <option key={a} value={a}>{a}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Number of slides</label>
            <select value={slideCount} onChange={(e) => setSlideCount(+e.target.value)}>
              {[5, 8, 10, 12, 15, 20].map((n) => <option key={n} value={n}>{n} slides</option>)}
            </select>
          </div>
          {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
          <button className="btn btn-primary" disabled={!topic.trim()} onClick={() => void generate()}>
            <Icon name="sparkles" size={15} /> Generate deck
          </button>
        </div>
        <div className="output-area" style={{ minHeight: 260, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', textAlign: 'center', padding: 24 }}>
          Describe a topic → Farvixo AI writes a fully-structured deck with title, section dividers, bullets, quotes & speaker notes. Then edit every slide, switch themes, present live, and export to PowerPoint.
        </div>
      </div>
    );
  }

  /* ---- Editor ---- */
  return (
    <div className="aip-root" style={{ position: 'relative', display: 'flex', flexDirection: 'column', gap: 14 }}>
      <PlatformFX />
      <Aurora />
      <div className="aip-content" style={{ position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', gap: 14 }}>
      {/* Toolbar */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center' }}>
        <strong style={{ marginRight: 'auto', maxWidth: 340, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{deck.title}</strong>
        <div className="field" style={{ margin: 0 }}>
          <select value={themeId} onChange={(e) => setThemeId(e.target.value)} aria-label="Theme">
            {THEMES.map((t) => <option key={t.id} value={t.id}>{t.name} theme</option>)}
          </select>
        </div>
        <button className="btn" onClick={() => setPresent(true)}><Icon name="play" size={14} /> Present</button>
        <div style={{ position: 'relative' }}>
          <button className="btn btn-primary aip-glow" onClick={() => setExportOpen((o) => !o)}><Icon name="download" size={14} /> Export ▾</button>
          {exportOpen && (
            <>
              <div style={{ position: 'fixed', inset: 0, zIndex: 40 }} onClick={() => setExportOpen(false)} />
              <div className="aip-menu">
                <div className="aip-menu-title">Export as</div>
                {([
                  ['📊', 'PowerPoint', '.pptx', () => void exportPptx()],
                  ['📄', 'PDF', '.pdf', () => void exportPdf()],
                  ['🟡', 'Google Slides', 'import', () => void exportToService('slides')],
                  ['🎨', 'Canva', 'import', () => void exportToService('canva')],
                  ['{ }', 'JSON', 'data', exportJson],
                ] as [string, string, string, () => void][]).map(([icon, label, ext, fn]) => (
                  <button key={label} className="aip-menu-item" onClick={() => { setExportOpen(false); fn(); }}>
                    <span className="aip-menu-ico" aria-hidden>{icon}</span>
                    <span className="aip-menu-label">{label}</span>
                    <span className="aip-menu-ext">{ext}</span>
                  </button>
                ))}
              </div>
            </>
          )}
        </div>
        <button className="btn" onClick={() => { setDeck(null); reset(); }}>New</button>
      </div>

      {status && <p className="muted" style={{ fontSize: 13 }}>{status}</p>}
      {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}

      <div style={{ display: 'grid', gridTemplateColumns: '190px 1fr', gap: 14 }}>
        {/* Slide rail */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 560, overflowY: 'auto', paddingRight: 4 }}>
          {slides.map((s, i) => (
            <button
              key={s.id}
              onClick={() => setActive(i)}
              style={{
                textAlign: 'left', padding: 8, borderRadius: 10, cursor: 'pointer',
                border: `1px solid ${i === active ? hex(theme.accent) : 'var(--border-subtle)'}`,
                background: i === active ? 'var(--bg-surface-2)' : 'var(--bg-surface)',
              }}
            >
              <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{i + 1} · {s.layout}</div>
              <div style={{ fontSize: 12, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.title}</div>
            </button>
          ))}
          <button className="btn" onClick={addSlide} style={{ fontSize: 12 }}>+ Add slide</button>
        </div>

        {/* Preview + edit */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {current && <div className="aip-frame"><SlideCanvas slide={current} theme={theme} /></div>}

          {current && (
            <div className="options-panel" style={{ gap: 10 }}>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <div className="field" style={{ margin: 0, flex: 1, minWidth: 140 }}>
                  <label>Layout</label>
                  <select value={current.layout} onChange={(e) => patchSlide(current.id, { layout: e.target.value as Layout })}>
                    {LAYOUTS.map((l) => <option key={l.id} value={l.id}>{l.label}</option>)}
                  </select>
                </div>
                <div style={{ display: 'flex', gap: 6, alignItems: 'flex-end' }}>
                  <button className="btn" onClick={() => move(current.id, -1)} aria-label="Move up">↑</button>
                  <button className="btn" onClick={() => move(current.id, 1)} aria-label="Move down">↓</button>
                  <button className="btn" onClick={() => deleteSlide(current.id)} disabled={slides.length <= 1} aria-label="Delete">✕</button>
                </div>
              </div>

              <div className="field" style={{ margin: 0 }}>
                <label>Title</label>
                <input value={current.title} onChange={(e) => patchSlide(current.id, { title: e.target.value })} />
              </div>

              {(current.layout === 'title' || current.layout === 'section' || current.layout === 'quote') && (
                <div className="field" style={{ margin: 0 }}>
                  <label>Subtitle / attribution</label>
                  <input value={current.subtitle || ''} onChange={(e) => patchSlide(current.id, { subtitle: e.target.value })} />
                </div>
              )}

              {current.layout !== 'title' && current.layout !== 'section' && (
                <div className="field" style={{ margin: 0 }}>
                  <label>Bullets (one per line)</label>
                  <textarea rows={4} value={current.bullets.join('\n')} onChange={(e) => patchSlide(current.id, { bullets: e.target.value.split('\n') })} />
                </div>
              )}

              {current.layout === 'twoColumn' && (
                <div className="field" style={{ margin: 0 }}>
                  <label>Right column bullets (one per line)</label>
                  <textarea rows={4} value={(current.bullets2 || []).join('\n')} onChange={(e) => patchSlide(current.id, { bullets2: e.target.value.split('\n') })} />
                </div>
              )}

              <div className="field" style={{ margin: 0 }}>
                <label>Speaker notes</label>
                <textarea rows={2} value={current.notes || ''} onChange={(e) => patchSlide(current.id, { notes: e.target.value })} />
              </div>

              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <button className="btn" disabled={busySlide === current.id} onClick={() => void enhanceSlide(current, 'expand')}>
                  <Icon name="sparkles" size={13} /> {busySlide === current.id ? 'Working…' : 'AI expand'}
                </button>
                <button className="btn" disabled={busySlide === current.id} onClick={() => void enhanceSlide(current, 'concise')}>
                  <Icon name="sparkles" size={13} /> AI make concise
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Present overlay */}
      {present && current && (
        <div
          onClick={() => setActive((a) => Math.min(a + 1, slides.length - 1))}
          style={{ position: 'fixed', inset: 0, zIndex: 9999, background: hex(theme.bg), display: 'grid', placeItems: 'center', cursor: 'pointer' }}
        >
          <div style={{ width: 'min(94vw, 1280px)', aspectRatio: '16 / 9' }}>
            <SlideCanvas slide={current} theme={theme} full />
          </div>
          <div style={{ position: 'absolute', bottom: 16, left: 0, right: 0, display: 'flex', justifyContent: 'center', gap: 16, color: hex(theme.muted), fontSize: 13 }}>
            <span>{active + 1} / {slides.length}</span>
            <span>← → navigate · Esc to exit</span>
          </div>
          <button
            className="btn"
            onClick={(e) => { e.stopPropagation(); setPresent(false); }}
            style={{ position: 'absolute', top: 16, right: 16 }}
          >Exit</button>
        </div>
      )}
      </div>
    </div>
  );
}

/* ─────────────────────────────  Slide preview canvas  ───────────────────────────── */

function SlideCanvas({ slide, theme, full }: { slide: Slide; theme: Theme; full?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  // Scale a fixed 1280x720 design box to fit the container width.
  useEffect(() => {
    const el = ref.current?.parentElement;
    if (!el) return;
    const fit = () => setScale(el.clientWidth / 1280);
    fit();
    const ro = new ResizeObserver(fit);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const isCover = slide.layout === 'title' || slide.layout === 'section';
  const bg = isCover ? hex(theme.bg) : hex(theme.surface);

  return (
    <div ref={ref} style={{ width: '100%', aspectRatio: '16 / 9', borderRadius: full ? 0 : 14, overflow: 'hidden', border: full ? 'none' : '1px solid var(--border-subtle)', position: 'relative' }}>
      <div
        style={{
          position: 'absolute', top: 0, left: 0, width: 1280, height: 720,
          transform: `scale(${scale})`, transformOrigin: 'top left',
          background: bg, color: hex(theme.text), fontFamily: theme.font,
          padding: 72, boxSizing: 'border-box', display: 'flex', flexDirection: 'column',
        }}
      >
        {isCover ? (
          <div style={{ margin: 'auto 0' }}>
            <div style={{ width: 220, height: 7, background: hex(theme.accent), borderRadius: 4, marginBottom: 34 }} />
            <h1 style={{ fontSize: slide.layout === 'title' ? 68 : 54, fontWeight: 800, lineHeight: 1.05, margin: 0 }}>{slide.title}</h1>
            {slide.subtitle && <p style={{ fontSize: 26, color: hex(theme.muted), marginTop: 26 }}>{slide.subtitle}</p>}
          </div>
        ) : slide.layout === 'quote' ? (
          <>
            <div style={{ width: 8, height: '100%', background: hex(theme.accent), position: 'absolute', left: 0, top: 0 }} />
            <div style={{ margin: 'auto 0' }}>
              <p style={{ fontSize: 44, fontStyle: 'italic', lineHeight: 1.25, margin: 0 }}>“{slide.bullets[0] || slide.title}”</p>
              {slide.subtitle && <p style={{ fontSize: 24, color: hex(theme.muted), marginTop: 28 }}>— {slide.subtitle}</p>}
            </div>
          </>
        ) : (
          <>
            <div style={{ width: 8, height: '100%', background: hex(theme.accent), position: 'absolute', left: 0, top: 0 }} />
            <h2 style={{ fontSize: 46, fontWeight: 700, margin: '0 0 34px' }}>{slide.title}</h2>
            <div style={{ display: slide.layout === 'twoColumn' ? 'grid' : 'block', gridTemplateColumns: '1fr 1fr', gap: 48, flex: 1 }}>
              <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 20 }}>
                {slide.bullets.map((b, i) => (
                  <li key={i} style={{ fontSize: 27, color: hex(theme.muted), display: 'flex', gap: 16, lineHeight: 1.3 }}>
                    <span style={{ color: hex(theme.accent), fontWeight: 800 }}>•</span>{b}
                  </li>
                ))}
              </ul>
              {slide.layout === 'twoColumn' && (
                <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 20 }}>
                  {(slide.bullets2 || []).map((b, i) => (
                    <li key={i} style={{ fontSize: 27, color: hex(theme.muted), display: 'flex', gap: 16, lineHeight: 1.3 }}>
                      <span style={{ color: hex(theme.accent2), fontWeight: 800 }}>•</span>{b}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

/* ─────────────────────────────  Premium design layer  ───────────────────────────── */

function Aurora() {
  return <div className="aip-aurora" aria-hidden><span /><span /><span /></div>;
}

function PlatformFX() {
  return (
    <style>{`
.aip-root { isolation: isolate; }
.aip-aurora { position: absolute; inset: -25%; z-index: 0; pointer-events: none; overflow: hidden; filter: blur(70px); opacity: .45; }
.aip-aurora span { position: absolute; width: 42vw; height: 42vw; border-radius: 50%; mix-blend-mode: screen; will-change: transform; transform: translateZ(0); animation: aip-float 20s ease-in-out infinite; }
.aip-aurora span:nth-child(1) { background: radial-gradient(circle, #6C4DFF, transparent 60%); top: -8%; left: 2%; }
.aip-aurora span:nth-child(2) { background: radial-gradient(circle, #C026D3, transparent 60%); top: 18%; right: -6%; animation-delay: -7s; }
.aip-aurora span:nth-child(3) { background: radial-gradient(circle, #22C55E, transparent 60%); bottom: -18%; left: 30%; animation-delay: -13s; }
@keyframes aip-float { 0%,100% { transform: translate3d(0,0,0) scale(1);} 33% { transform: translate3d(5%,-6%,0) scale(1.12);} 66% { transform: translate3d(-4%,5%,0) scale(.94);} }

.aip-frame { position: relative; border-radius: 18px; padding: 2px; background: linear-gradient(120deg, #6C4DFF, #C026D3, #22C55E, #6C4DFF); background-size: 300% 300%; animation: aip-border 9s linear infinite; box-shadow: 0 24px 70px -22px rgba(108,77,255,.55); will-change: background-position; }
@keyframes aip-border { 0% { background-position: 0% 50%;} 100% { background-position: 300% 50%;} }

.aip-glow { position: relative; animation: aip-pulse 2.8s ease-in-out infinite; }
@keyframes aip-pulse { 0%,100% { box-shadow: 0 0 0 rgba(108,77,255,.0);} 50% { box-shadow: 0 0 24px rgba(108,77,255,.55);} }

.aip-menu { position: absolute; top: calc(100% + 8px); right: 0; z-index: 50; min-width: 250px; padding: 8px; border-radius: 18px; background: rgba(14,14,22,.92); backdrop-filter: blur(24px) saturate(160%); -webkit-backdrop-filter: blur(24px) saturate(160%); border: 1px solid rgba(255,255,255,.14); box-shadow: 0 28px 70px -20px rgba(0,0,0,.7); display: flex; flex-direction: column; gap: 2px; animation: aip-pop .18s cubic-bezier(.2,.9,.3,1.2); transform-origin: top right; }
@keyframes aip-pop { from { opacity: 0; transform: scale(.92) translateY(-6px);} to { opacity: 1; transform: scale(1) translateY(0);} }
.aip-menu-title { padding: 6px 12px 8px; font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: #8A8AA5; }
.aip-menu-item { display: flex; align-items: center; gap: 12px; box-sizing: border-box; width: 100%; margin: 0; text-align: left; white-space: nowrap; cursor: pointer; padding: 11px 14px; border: none; border-radius: 12px; background: transparent; font-family: inherit; font-size: 15px; font-weight: 600; line-height: 1.2; color: #FFFFFF; transition: background .15s ease; }
.aip-menu-item:hover { background: rgba(108,77,255,.30); }
.aip-menu-ico { display: inline-flex; align-items: center; justify-content: center; width: 26px; height: 26px; border-radius: 8px; background: rgba(255,255,255,.08); font-size: 14px; flex: none; }
.aip-menu-label { flex: 1; }
.aip-menu-ext { font-size: 12px; font-weight: 500; color: #9A9AB5; }

@media (prefers-reduced-motion: reduce) {
  .aip-aurora span, .aip-frame, .aip-glow, .aip-menu { animation: none !important; }
}
`}</style>
  );
}
