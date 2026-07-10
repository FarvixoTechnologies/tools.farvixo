'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { aiComplete } from '@/lib/ai';
import type { Tool } from '@/data/tools';

/* ─────────────────────────────────────────────────────────────
   Farvixo · HTML Online Viewer — advanced in-browser IDE
   Tabbed editor · live sandboxed preview · devices · console · AI
   No external deps — fully client-side & Cloudflare-safe.
   ───────────────────────────────────────────────────────────── */

type Tab = 'html' | 'css' | 'js';
type PreviewTheme = 'auto' | 'light' | 'dark';

interface Device { id: string; label: string; w: number; h: number; }

const DEVICES: Device[] = [
  { id: 'responsive', label: 'Responsive', w: 0, h: 0 },
  { id: 'desktop', label: 'Desktop', w: 1440, h: 900 },
  { id: 'laptop', label: 'Laptop', w: 1280, h: 800 },
  { id: 'tablet', label: 'Tablet', w: 768, h: 1024 },
  { id: 'mobile', label: 'Mobile', w: 390, h: 844 },
  { id: 'foldable', label: 'Foldable', w: 344, h: 882 },
  { id: 'ultrawide', label: 'Ultra Wide', w: 1920, h: 720 },
  { id: 'tv', label: 'TV 4K', w: 2560, h: 1440 },
];

const STARTER_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Farvixo Live Preview</title>
</head>
<body>
  <main class="card">
    <h1>Build Beyond 🚀</h1>
    <p>Edit HTML, CSS &amp; JS — see it live instantly.</p>
    <button id="btn">Click me</button>
  </main>
</body>
</html>`;

const STARTER_CSS = `* { box-sizing: border-box; }
body {
  margin: 0; min-height: 100vh; display: grid; place-items: center;
  font-family: system-ui, sans-serif;
  background: radial-gradient(circle at 30% 20%, #7c3aed33, transparent 60%), #0a0a12;
  color: #f5f5fa;
}
.card {
  padding: 40px; border-radius: 20px; text-align: center;
  background: rgba(26,26,40,.6); border: 1px solid rgba(255,255,255,.08);
  backdrop-filter: blur(12px);
}
h1 { margin: 0 0 8px; }
button {
  margin-top: 16px; padding: 12px 24px; border: 0; border-radius: 10px;
  background: linear-gradient(135deg,#7c3aed,#c026d3); color: #fff;
  font-weight: 600; cursor: pointer;
}`;

const STARTER_JS = `const btn = document.getElementById('btn');
let n = 0;
btn.addEventListener('click', () => {
  n++;
  btn.textContent = 'Clicked ' + n + '×';
  console.log('Button clicked', n);
});`;

const LS_KEY = 'farvixo-html-viewer-v1';

interface ConsoleEntry { level: string; msg: string; t: number; }

const CONSOLE_BRIDGE = `<script>(function(){
  var send=function(level,args){try{parent.postMessage({__fvhtml:1,level:level,msg:args.map(function(a){try{return typeof a==='object'?JSON.stringify(a):String(a)}catch(e){return String(a)}}).join(' ')},'*')}catch(e){}};
  ['log','error','warn','info'].forEach(function(l){var o=console[l];console[l]=function(){send(l,[].slice.call(arguments));try{o.apply(console,arguments)}catch(e){}}});
  window.addEventListener('error',function(e){send('error',[e.message+' ('+(e.lineno||0)+':'+(e.colno||0)+')'])});
  window.addEventListener('unhandledrejection',function(e){send('error',['Unhandled: '+(e.reason&&e.reason.message||e.reason)])});
})();<\/script>`;

function buildDoc(html: string, css: string, js: string): string {
  const styleTag = css.trim() ? `<style>\n${css}\n</style>` : '';
  const scriptTag = js.trim() ? `<script>\ntry{\n${js}\n}catch(e){console.error(e.message)}\n<\/script>` : '';
  const hasDoc = /<html[\s>]/i.test(html);
  if (hasDoc) {
    let out = html;
    // Inject bridge first, then styles into head, script before </body>.
    if (/<\/head>/i.test(out)) out = out.replace(/<\/head>/i, `${CONSOLE_BRIDGE}\n${styleTag}\n</head>`);
    else out = CONSOLE_BRIDGE + styleTag + out;
    if (/<\/body>/i.test(out)) out = out.replace(/<\/body>/i, `${scriptTag}\n</body>`);
    else out += scriptTag;
    return out;
  }
  return `<!DOCTYPE html><html><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" />${CONSOLE_BRIDGE}${styleTag}</head><body>${html}${scriptTag}</body></html>`;
}

/* Lightweight formatters (indentation only — safe, dependency-free). */
function formatHtml(src: string): string {
  const tokens = src.replace(/>\s*</g, '>\n<').split('\n');
  let indent = 0;
  return tokens
    .map((raw) => {
      const line = raw.trim();
      if (!line) return '';
      if (/^<\/(?!.*<)/.test(line)) indent = Math.max(0, indent - 1);
      const out = '  '.repeat(indent) + line;
      const isVoid = /<(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr|!doctype)/i.test(line);
      const selfClose = /\/>\s*$/.test(line);
      const openNoClose = /^<[a-zA-Z][^>]*>[^<]*$/.test(line) && !/<\//.test(line);
      if (openNoClose && !isVoid && !selfClose) indent++;
      return out;
    })
    .filter(Boolean)
    .join('\n');
}

function formatCssJs(src: string): string {
  // Normalise brace indentation for CSS / basic JS blocks.
  let indent = 0;
  const lines: string[] = [];
  src.replace(/\r/g, '').split('\n').forEach((raw) => {
    const line = raw.trim();
    if (!line) return;
    if (line.startsWith('}')) indent = Math.max(0, indent - 1);
    lines.push('  '.repeat(indent) + line);
    const opens = (line.match(/\{/g) || []).length;
    const closes = (line.match(/\}/g) || []).length;
    indent = Math.max(0, indent + opens - closes);
  });
  return lines.join('\n');
}

function extractCodeBlock(text: string): string | null {
  const m = text.match(/```(?:html|HTML)?\s*([\s\S]*?)```/);
  return m ? m[1].trim() : null;
}

export default function HtmlViewerRunner({ tool }: { tool: Tool }) {
  const { toast } = useUI();

  const [html, setHtml] = useState(STARTER_HTML);
  const [css, setCss] = useState(STARTER_CSS);
  const [js, setJs] = useState(STARTER_JS);
  const [tab, setTab] = useState<Tab>('html');

  const [device, setDevice] = useState<Device>(DEVICES[0]);
  const [rotated, setRotated] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [previewTheme, setPreviewTheme] = useState<PreviewTheme>('auto');
  const [autoRun, setAutoRun] = useState(true);
  const [fullscreen, setFullscreen] = useState(false);

  const [srcDoc, setSrcDoc] = useState(() => buildDoc(STARTER_HTML, STARTER_CSS, STARTER_JS));
  const [logs, setLogs] = useState<ConsoleEntry[]>([]);
  const [consoleOpen, setConsoleOpen] = useState(true);

  const [aiOpen, setAiOpen] = useState(false);
  const [aiBusy, setAiBusy] = useState(false);
  const [aiText, setAiText] = useState('');
  const [aiApply, setAiApply] = useState<string | null>(null);
  const [aiPrompt, setAiPrompt] = useState('');

  const fileRef = useRef<HTMLInputElement>(null);
  const gutterRef = useRef<HTMLDivElement>(null);
  const taRef = useRef<HTMLTextAreaElement>(null);

  const value = tab === 'html' ? html : tab === 'css' ? css : js;
  const setValue = tab === 'html' ? setHtml : tab === 'css' ? setCss : setJs;

  // Restore session
  useEffect(() => {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (raw) {
        const s = JSON.parse(raw) as { html?: string; css?: string; js?: string };
        if (s.html !== undefined) setHtml(s.html);
        if (s.css !== undefined) setCss(s.css);
        if (s.js !== undefined) setJs(s.js);
      }
    } catch { /* ignore */ }
  }, []);

  // Persist session (debounced)
  useEffect(() => {
    const t = setTimeout(() => {
      try { localStorage.setItem(LS_KEY, JSON.stringify({ html, css, js })); } catch { /* quota */ }
    }, 600);
    return () => clearTimeout(t);
  }, [html, css, js]);

  const run = useCallback(() => {
    setLogs([]);
    setSrcDoc(buildDoc(html, css, js));
  }, [html, css, js]);

  // Auto-run (debounced)
  useEffect(() => {
    if (!autoRun) return;
    const t = setTimeout(run, 500);
    return () => clearTimeout(t);
  }, [html, css, js, autoRun, run]);

  // Console bridge listener
  useEffect(() => {
    const onMsg = (e: MessageEvent) => {
      const d = e.data;
      if (d && d.__fvhtml) {
        setLogs((prev) => [...prev.slice(-99), { level: d.level, msg: d.msg, t: Date.now() }]);
      }
    };
    window.addEventListener('message', onMsg);
    return () => window.removeEventListener('message', onMsg);
  }, []);

  const lineCount = useMemo(() => value.split('\n').length, [value]);

  const onEditorScroll = () => {
    if (gutterRef.current && taRef.current) gutterRef.current.scrollTop = taRef.current.scrollTop;
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    const ta = e.currentTarget;
    if (e.key === 'Tab') {
      e.preventDefault();
      const s = ta.selectionStart, en = ta.selectionEnd;
      const next = value.slice(0, s) + '  ' + value.slice(en);
      setValue(next);
      requestAnimationFrame(() => { ta.selectionStart = ta.selectionEnd = s + 2; });
    }
    // Ctrl/Cmd+Enter → run
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); run(); }
  };

  /* ── Import ── */
  const loadHtmlString = (str: string) => {
    setHtml(str);
    setTab('html');
    toast('HTML imported', 'success');
  };

  const importFile = async (file: File) => {
    const name = file.name.toLowerCase();
    try {
      if (name.endsWith('.zip')) {
        const JSZip = (await import('jszip')).default;
        const zip = await JSZip.loadAsync(file);
        const entry = Object.keys(zip.files).find((n) => /index\.html?$/i.test(n)) || Object.keys(zip.files).find((n) => /\.html?$/i.test(n));
        if (!entry) { toast('No HTML file in ZIP', 'error'); return; }
        loadHtmlString(await zip.files[entry].async('string'));
        const cssE = Object.keys(zip.files).find((n) => /\.css$/i.test(n));
        const jsE = Object.keys(zip.files).find((n) => /\.js$/i.test(n));
        if (cssE) setCss(await zip.files[cssE].async('string'));
        if (jsE) setJs(await zip.files[jsE].async('string'));
      } else if (/\.(html?|css|js|svg|xml|txt|md)$/i.test(name)) {
        const text = await file.text();
        if (name.endsWith('.css')) { setCss(text); setTab('css'); toast('CSS imported', 'success'); }
        else if (name.endsWith('.js')) { setJs(text); setTab('js'); toast('JS imported', 'success'); }
        else loadHtmlString(text);
      } else {
        toast('Unsupported file', 'error');
      }
    } catch {
      toast('Could not read file', 'error');
    }
  };

  const importUrl = async () => {
    const url = prompt('Enter a page URL to import (must allow CORS):');
    if (!url) return;
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error();
      loadHtmlString(await res.text());
    } catch {
      toast('Fetch blocked (CORS) — paste the HTML instead', 'error');
    }
  };

  /* ── Export ── */
  const downloadBlob = (content: string | Blob, filename: string, type = 'text/plain') => {
    const blob = content instanceof Blob ? content : new Blob([content], { type });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const exportHtml = () => downloadBlob(buildDoc(html, css, js), 'farvixo-page.html', 'text/html');

  const exportZip = async () => {
    try {
      const JSZip = (await import('jszip')).default;
      const zip = new JSZip();
      zip.file('index.html', html);
      if (css.trim()) zip.file('style.css', css);
      if (js.trim()) zip.file('script.js', js);
      downloadBlob(await zip.generateAsync({ type: 'blob' }), 'farvixo-project.zip');
      toast('ZIP exported', 'success');
    } catch { toast('ZIP export failed', 'error'); }
  };

  const copyCombined = async () => {
    try { await navigator.clipboard.writeText(buildDoc(html, css, js)); toast('HTML copied', 'success'); }
    catch { toast('Copy failed', 'error'); }
  };

  const openNewTab = () => {
    const w = window.open('', '_blank');
    if (w) { w.document.open(); w.document.write(buildDoc(html, css, js)); w.document.close(); }
  };

  const formatActive = () => {
    if (tab === 'html') setHtml(formatHtml(html));
    else if (tab === 'css') setCss(formatCssJs(css));
    else setJs(formatCssJs(js));
    toast('Formatted', 'success');
  };

  /* ── AI actions ── */
  const runAi = async (mode: string, instruction: string, expectCode: boolean, extra?: string) => {
    setAiOpen(true);
    setAiBusy(true);
    setAiText('');
    setAiApply(null);
    const combined = `HTML:\n${html}\n\nCSS:\n${css}\n\nJS:\n${js}`;
    const userMsg = expectCode
      ? `${instruction}\n\n${extra || ''}\n\nHere is the current code:\n${combined}\n\nReturn ONLY the complete corrected/updated standalone HTML document inside a single \`\`\`html code block (inline the CSS in <style> and JS in <script>). No prose.`
      : `${instruction}\n\n${extra || ''}\n\nCode:\n${combined}`;
    try {
      const full = await aiComplete(
        [{ role: 'user', content: userMsg }],
        `You are Farvixo AI, an expert front-end engineer inside the Farvixo HTML Viewer. Be precise and practical.`,
        (streamed) => setAiText(streamed),
      );
      if (expectCode) {
        const code = extractCodeBlock(full);
        if (code) setAiApply(code);
      }
    } catch (err) {
      setAiText(`⚠️ ${err instanceof Error ? err.message : 'AI error'}`);
    } finally {
      setAiBusy(false);
    }
    void mode;
  };

  const copyAiOutput = async () => {
    try {
      await navigator.clipboard.writeText(aiApply || aiText);
      toast('Copied to clipboard', 'success');
    } catch {
      toast('Copy failed', 'error');
    }
  };

  const applyAiCode = () => {
    if (!aiApply) return;
    setHtml(aiApply);
    setCss('');
    setJs('');
    setTab('html');
    setAiOpen(false);
    run();
    toast('AI changes applied', 'success');
  };

  const generatePage = () => {
    const p = aiPrompt.trim();
    if (!p) { toast('Describe the page first', 'error'); return; }
    void runAi('generate', `Generate a complete, modern, responsive HTML page: ${p}`, true);
  };

  /* ── Preview sizing ── */
  const dW = device.w === 0 ? 0 : (rotated ? device.h : device.w);
  const dH = device.h === 0 ? 0 : (rotated ? device.w : device.h);
  const frameStyle: React.CSSProperties = device.w === 0
    ? { width: '100%', height: '100%' }
    : { width: dW, height: dH, transform: `scale(${zoom})`, transformOrigin: 'top center' };

  const previewWrapClass = `hv-preview-canvas ${previewTheme === 'dark' ? 'is-dark' : previewTheme === 'light' ? 'is-light' : ''}`;

  return (
    <div className={`hv-shell ${fullscreen ? 'hv-fullscreen' : ''}`}>
      <input ref={fileRef} type="file" hidden accept=".html,.htm,.css,.js,.svg,.xml,.txt,.md,.zip"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) void importFile(f); e.target.value = ''; }} />

      {/* Toolbar */}
      <div className="hv-toolbar">
        <div className="hv-toolbar-group">
          <button className="hv-btn" onClick={() => fileRef.current?.click()} title="Import file / ZIP"><Icon name="upload" size={15} /> Import</button>
          <button className="hv-btn" onClick={importUrl} title="Import from URL"><Icon name="link" size={15} /> URL</button>
        </div>
        <div className="hv-toolbar-group">
          <button className="hv-btn hv-btn-primary" onClick={run} title="Run (Ctrl+Enter)"><Icon name="play" size={15} /> Run</button>
          <label className="hv-toggle" title="Auto refresh">
            <input type="checkbox" checked={autoRun} onChange={(e) => setAutoRun(e.target.checked)} /> Auto
          </label>
          <button className="hv-btn" onClick={formatActive} title="Format code"><Icon name="wand" size={15} /> Format</button>
        </div>
        <div className="hv-toolbar-group hv-toolbar-right">
          <button className="hv-btn hv-btn-ai" onClick={() => setAiOpen((v) => !v)}><Icon name="sparkles" size={15} /> AI</button>
          <button className="hv-btn" onClick={copyCombined} title="Copy HTML"><Icon name="copy" size={15} /></button>
          <button className="hv-btn" onClick={exportHtml} title="Download HTML"><Icon name="download" size={15} /></button>
          <button className="hv-btn" onClick={exportZip} title="Download ZIP"><Icon name="folder" size={15} /></button>
          <button className="hv-btn" onClick={openNewTab} title="Open in new tab"><Icon name="share" size={15} /></button>
          <button className="hv-btn" onClick={() => setFullscreen((v) => !v)} title="Fullscreen"><Icon name="scaling" size={15} /></button>
        </div>
      </div>

      <div className="hv-body">
        {/* Editor */}
        <div className="hv-editor-pane">
          <div className="hv-tabs">
            {(['html', 'css', 'js'] as Tab[]).map((t) => (
              <button key={t} className={`hv-tab ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)}>
                <Icon name={t === 'js' ? 'braces' : 'code'} size={13} /> {t.toUpperCase()}
              </button>
            ))}
            <span className="hv-tab-meta">{lineCount} lines</span>
          </div>
          <div className="hv-editor">
            <div className="hv-gutter" ref={gutterRef} aria-hidden="true">
              {Array.from({ length: lineCount }, (_, i) => <div key={i}>{i + 1}</div>)}
            </div>
            <textarea
              ref={taRef}
              className="hv-code"
              value={value}
              spellCheck={false}
              onChange={(e) => setValue(e.target.value)}
              onScroll={onEditorScroll}
              onKeyDown={onKeyDown}
              placeholder={`Write ${tab.toUpperCase()} here…`}
            />
          </div>
        </div>

        {/* Preview */}
        <div className="hv-preview-pane">
          <div className="hv-preview-bar">
            <select className="hv-select" value={device.id} onChange={(e) => setDevice(DEVICES.find((d) => d.id === e.target.value) || DEVICES[0])}>
              {DEVICES.map((d) => <option key={d.id} value={d.id}>{d.label}{d.w ? ` · ${d.w}×${d.h}` : ''}</option>)}
            </select>
            <button className="hv-icon-btn" onClick={() => setRotated((v) => !v)} disabled={device.w === 0} title="Rotate"><Icon name="rotate" size={14} /></button>
            <div className="hv-zoom">
              <button className="hv-icon-btn" onClick={() => setZoom((z) => Math.max(0.25, +(z - 0.1).toFixed(2)))} disabled={device.w === 0}>−</button>
              <span>{Math.round(zoom * 100)}%</span>
              <button className="hv-icon-btn" onClick={() => setZoom((z) => Math.min(1.5, +(z + 0.1).toFixed(2)))} disabled={device.w === 0}>+</button>
            </div>
            <div className="hv-theme-seg">
              {(['auto', 'light', 'dark'] as PreviewTheme[]).map((th) => (
                <button key={th} className={`hv-seg ${previewTheme === th ? 'active' : ''}`} onClick={() => setPreviewTheme(th)}>
                  {th === 'light' ? <Icon name="sun" size={13} /> : th === 'dark' ? <Icon name="moon" size={13} /> : 'A'}
                </button>
              ))}
            </div>
          </div>
          <div className={previewWrapClass}>
            <iframe
              title="Live preview"
              className="hv-frame"
              style={frameStyle}
              srcDoc={srcDoc}
              sandbox="allow-scripts allow-modals allow-forms allow-popups"
            />
          </div>

          {/* Console */}
          <div className={`hv-console ${consoleOpen ? 'open' : ''}`}>
            <div className="hv-console-head" onClick={() => setConsoleOpen((v) => !v)}>
              <Icon name="code" size={13} /> Console
              {logs.length > 0 && <span className="hv-console-count">{logs.length}</span>}
              <button className="hv-console-clear" onClick={(e) => { e.stopPropagation(); setLogs([]); }} title="Clear">Clear</button>
              <Icon name={consoleOpen ? 'chevron-down' : 'chevron-up'} size={14} className="hv-console-chevron" />
            </div>
            {consoleOpen && (
              <div className="hv-console-body">
                {logs.length === 0
                  ? <div className="hv-console-empty">No output. console.log() and runtime errors appear here.</div>
                  : logs.map((l, i) => (
                    <div key={i} className={`hv-log hv-log-${l.level}`}>
                      <span className="hv-log-badge">{l.level}</span>
                      <span className="hv-log-msg">{l.msg}</span>
                    </div>
                  ))}
              </div>
            )}
          </div>
        </div>

        {/* AI panel */}
        {aiOpen && (
          <div className="hv-ai-pane">
            <div className="hv-ai-head">
              <b><Icon name="sparkles" size={15} /> Farvixo AI</b>
              <button className="hv-icon-btn" onClick={() => setAiOpen(false)}><Icon name="x" size={16} /></button>
            </div>
            <div className="hv-ai-actions">
              <button className="hv-btn" disabled={aiBusy} onClick={() => runAi('explain', 'Explain what this code does, clearly and concisely.', false)}>Explain</button>
              <button className="hv-btn" disabled={aiBusy} onClick={() => runAi('fix', 'Find and fix all bugs and invalid markup in this code.', true)}>Fix</button>
              <button className="hv-btn" disabled={aiBusy} onClick={() => runAi('improve', 'Improve this page: modern design, clean semantic HTML, better UX.', true)}>Improve</button>
              <button className="hv-btn" disabled={aiBusy} onClick={() => runAi('a11y', 'Fix accessibility issues (WCAG): ARIA, alt text, contrast, semantics, focus.', true)}>A11y Fix</button>
              <button className="hv-btn" disabled={aiBusy} onClick={() => runAi('seo', 'Optimize for SEO: meta tags, Open Graph, headings, semantic structure.', true)}>SEO Fix</button>
            </div>
            <div className="hv-ai-gen">
              <input className="hv-input" placeholder="Generate a page… e.g. SaaS pricing section"
                value={aiPrompt} onChange={(e) => setAiPrompt(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') generatePage(); }} disabled={aiBusy} />
              <button className="hv-btn hv-btn-primary" onClick={generatePage} disabled={aiBusy}><Icon name="wand" size={14} /></button>
            </div>
            <div className="hv-ai-output">
              {aiBusy && !aiText && <div className="hv-ai-loading">Thinking…</div>}
              {aiText && (
                <div className="hv-ai-text-wrap">
                  <button className="hv-ai-copy" onClick={copyAiOutput} title={aiApply ? 'Copy code' : 'Copy'}>
                    <Icon name="copy" size={13} /> Copy{aiApply ? ' code' : ''}
                  </button>
                  <pre className="hv-ai-text">{aiText}</pre>
                </div>
              )}
            </div>
            {aiApply && !aiBusy && (
              <button className="hv-btn hv-btn-primary hv-ai-apply" onClick={applyAiCode}><Icon name="check" size={15} /> Apply to editor</button>
            )}
          </div>
        )}
      </div>

      <div className="hv-footer">
        <span><Icon name="shield" size={12} /> 100% client-side · nothing uploaded</span>
        <span className="hv-footer-brand"><Icon name="sparkles" size={11} /> {tool.name} · Farvixo</span>
      </div>
    </div>
  );
}
