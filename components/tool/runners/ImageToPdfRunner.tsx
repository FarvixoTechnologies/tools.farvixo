'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import type { Tool } from '@/data/tools';
import Icon from '@/components/Icon';
import UniversalDragDropUploader from '../UniversalDragDropUploader';
import { ErrorBox, Processing, ResultView, useToolPhase, type ResultFile } from '../shared';
import { useUI } from '@/components/GlobalUI';
import { formatBytes } from '@/lib/download';
import { recordJob } from '@/lib/jobs';
import {
  DEFAULT_IMG2PDF_SETTINGS,
  IMG2PDF_ACCEPT,
  buildPdfFromImages,
  createImg2PdfItem,
  extractImagesFromZip,
  fetchImageFromUrl,
  loadImg2PdfSession,
  markDuplicates,
  saveImg2PdfSession,
  type Img2PdfItem,
  type Img2PdfSettings,
} from '@/lib/engines/image-to-pdf-engine';

const ShareModal = dynamic(() => import('../ShareModal'), { ssr: false });

const STEPS = ['Upload', 'Organize', 'Optimize', 'Convert'] as const;

function Steps({ current }: { current: number }) {
  return (
    <div className="pdfconv-steps" aria-label="Image to PDF progress">
      {STEPS.map((s, i) => (
        <div key={s} className={`pdfconv-step ${i < current ? 'done' : ''} ${i === current ? 'active' : ''}`}>
          <span className="pdfconv-step-dot">
            {i < current ? <Icon name="check" size={12} /> : i + 1}
          </span>
          <span className="pdfconv-step-label">{s}</span>
          {i < STEPS.length - 1 && <span className="pdfconv-step-line" aria-hidden />}
        </div>
      ))}
    </div>
  );
}

export default function ImageToPdfRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const { toast, openAI } = useUI();
  const [step, setStep] = useState(0);
  const [items, setItems] = useState<Img2PdfItem[]>([]);
  const [settings, setSettings] = useState<Img2PdfSettings>(DEFAULT_IMG2PDF_SETTINGS);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [dragId, setDragId] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [status, setStatus] = useState('');
  const [results, setResults] = useState<ResultFile[]>([]);
  const [previewId, setPreviewId] = useState<string | null>(null);
  const [urlOpen, setUrlOpen] = useState(false);
  const [urlValue, setUrlValue] = useState('');
  const [urlBusy, setUrlBusy] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const cameraRef = useRef<HTMLInputElement>(null);
  const zipRef = useRef<HTMLInputElement>(null);

  const totalBytes = useMemo(() => items.reduce((s, it) => s + it.file.size, 0), [items]);
  const previewItem = items.find((it) => it.id === previewId) ?? items[0];
  const history = loadImg2PdfSession();

  const addFiles = useCallback(async (files: File[]) => {
    const imageFiles: File[] = [];
    for (const f of files) {
      if (f.type === 'application/zip' || f.name.endsWith('.zip')) {
        try {
          imageFiles.push(...await extractImagesFromZip(f));
        } catch {
          toast('Could not read ZIP', 'error');
        }
      } else {
        imageFiles.push(f);
      }
    }
    if (!imageFiles.length) return;
    const created: Img2PdfItem[] = [];
    for (const f of imageFiles) {
      try {
        created.push(await createImg2PdfItem(f));
      } catch {
        toast(`Skipped ${f.name}`, 'error');
      }
    }
    setItems((prev) => markDuplicates([...prev, ...created]));
    saveImg2PdfSession([...items, ...created].map((i) => i.name));
    if (created.length) toast(`${created.length} image(s) added`, 'success');
  }, [items, toast]);

  useEffect(() => {
    const onPaste = async (e: ClipboardEvent) => {
      if (step !== 0) return;
      const files: File[] = [];
      for (const item of e.clipboardData?.items ?? []) {
        if (item.kind === 'file' && item.type.startsWith('image/')) {
          const f = item.getAsFile();
          if (f) files.push(f);
        }
      }
      if (files.length) {
        e.preventDefault();
        void addFiles(files);
      }
    };
    window.addEventListener('paste', onPaste);
    return () => window.removeEventListener('paste', onPaste);
  }, [addFiles, step]);

  const reorder = (fromId: string, toId: string) => {
    setItems((prev) => {
      const from = prev.findIndex((i) => i.id === fromId);
      const to = prev.findIndex((i) => i.id === toId);
      if (from < 0 || to < 0 || from === to) return prev;
      const next = [...prev];
      const [moved] = next.splice(from, 1);
      next.splice(to, 0, moved);
      return next;
    });
  };

  const rotateSelected = (deg: 90 | -90) => {
    setItems((prev) =>
      prev.map((it) => {
        if (!selected.has(it.id) && selected.size > 0) return it;
        if (selected.size === 0 && it.id !== previewId) return it;
        const next = ((it.rotation + deg + 360) % 360) as 0 | 90 | 180 | 270;
        return { ...it, rotation: next };
      }),
    );
  };

  const deleteSelected = () => {
    if (!selected.size) return;
    setItems((prev) => prev.filter((it) => !selected.has(it.id)));
    setSelected(new Set());
  };

  const duplicateSelected = () => {
    setItems((prev) => {
      const extras: Img2PdfItem[] = [];
      for (const it of prev) {
        if (selected.has(it.id)) {
          extras.push({ ...it, id: `${it.id}-dup`, name: `copy-${it.name}` });
        }
      }
      return [...prev, ...extras];
    });
  };

  const sortBy = (mode: 'name' | 'size' | 'date') => {
    setItems((prev) => {
      const next = [...prev];
      if (mode === 'name') next.sort((a, b) => a.name.localeCompare(b.name));
      else if (mode === 'size') next.sort((a, b) => b.file.size - a.file.size);
      else next.sort((a, b) => b.file.lastModified - a.file.lastModified);
      return next;
    });
  };

  const runConvert = async () => {
    if (!items.length) return;
    setPhase('working');
    setProgress(0);
    try {
      const blob = await buildPdfFromImages(items, settings, (p) => {
        setProgress(p.progress);
        setStatus(p.label);
      });
      const name = settings.advanced.title
        ? `${settings.advanced.title.replace(/\s+/g, '-').toLowerCase()}.pdf`
        : 'images.pdf';
      setResults([{ name, blob }]);
      recordJob(tool.slug, 'completed');
      setPhase('done');
      setStep(3);
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => {
    items.forEach((it) => URL.revokeObjectURL(it.thumbUrl));
    reset();
    setItems([]);
    setResults([]);
    setStep(0);
    setSelected(new Set());
    setPreviewId(null);
    setSettings(DEFAULT_IMG2PDF_SETTINGS);
  };

  if (phase === 'working') {
    return <Processing label={status || 'Building PDF…'} progress={progress} />;
  }

  if (phase === 'done' && results.length) {
    return (
      <>
        <ResultView
          files={results}
          before={totalBytes}
          after={results[0].blob.size}
          onReset={resetAll}
        />
        <div className="mergepdf-fab-rail" aria-label="Quick actions">
          <button type="button" className="mergepdf-fab mergepdf-fab-ai" title="AI Assistant" onClick={openAI}>
            <Icon name="sparkles" size={18} />
          </button>
          <button type="button" className="mergepdf-fab" title="Share" onClick={() => setShareOpen(true)}>
            <Icon name="link" size={18} />
          </button>
        </div>
        {shareOpen && (
          <ShareModal open={shareOpen} onClose={() => setShareOpen(false)} file={results[0]} toolSlug={tool.slug} />
        )}
      </>
    );
  }

  return (
    <div className="img2pdf-shell">
      <Steps current={step} />

      {error && <ErrorBox message={error} />}

      {step === 0 && (
        <section className="img2pdf-panel glass">
          <div className="img2pdf-upload-grid">
            <UniversalDragDropUploader
              accept={tool.accept ?? IMG2PDF_ACCEPT}
              multiple
              onFiles={(f) => void addFiles(f)}
              title="Drop images here"
              note="JPG · PNG · WEBP · HEIC · AVIF · GIF · BMP · TIFF · SVG · ZIP batch"
              accent="var(--accent-image)"
            />
            <div className="img2pdf-upload-actions">
              <button type="button" className="btn btn-outline btn-sm" onClick={() => cameraRef.current?.click()}>
                <Icon name="image" size={15} /> Camera
              </button>
              <button type="button" className="btn btn-outline btn-sm" onClick={() => zipRef.current?.click()}>
                <Icon name="folder" size={15} /> ZIP Upload
              </button>
              <button type="button" className="btn btn-outline btn-sm" onClick={() => setUrlOpen((v) => !v)}>
                <Icon name="link" size={15} /> Import URL
              </button>
              <span className="muted img2pdf-hint"><Icon name="copy" size={13} /> Ctrl+V to paste images</span>
            </div>
            {urlOpen && (
              <div className="img2pdf-url-row">
                <input
                  type="url"
                  placeholder="https://example.com/photo.jpg"
                  value={urlValue}
                  onChange={(e) => setUrlValue(e.target.value)}
                />
                <button
                  type="button"
                  className="btn btn-primary btn-sm"
                  disabled={urlBusy || !urlValue.trim()}
                  onClick={async () => {
                    setUrlBusy(true);
                    try {
                      const f = await fetchImageFromUrl(urlValue.trim());
                      await addFiles([f]);
                      setUrlValue('');
                      setUrlOpen(false);
                    } catch (e) {
                      toast(e instanceof Error ? e.message : 'Import failed', 'error');
                    } finally {
                      setUrlBusy(false);
                    }
                  }}
                >
                  Import
                </button>
              </div>
            )}
            {history.length > 0 && (
              <p className="muted img2pdf-history">
                <Icon name="clock" size={13} /> Recent: {history.slice(0, 4).join(', ')}
              </p>
            )}
          </div>
          {items.length > 0 && (
            <div className="img2pdf-staged">
              <p><b>{items.length}</b> images · {formatBytes(totalBytes)}</p>
              <div className="img2pdf-thumb-row">
                {items.slice(0, 8).map((it) => (
                  <img key={it.id} src={it.thumbUrl} alt="" className="img2pdf-thumb" />
                ))}
                {items.length > 8 && <span className="img2pdf-more">+{items.length - 8}</span>}
              </div>
            </div>
          )}
          <div className="img2pdf-nav">
            <button type="button" className="btn btn-primary" disabled={!items.length} onClick={() => setStep(1)}>
              Organize →
            </button>
          </div>
        </section>
      )}

      {step === 1 && (
        <section className="img2pdf-panel glass">
          <div className="img2pdf-toolbar">
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => rotateSelected(90)}><Icon name="rotate" size={14} /> Rotate</button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={duplicateSelected} disabled={!selected.size}><Icon name="copy" size={14} /> Duplicate</button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={deleteSelected} disabled={!selected.size}><Icon name="x" size={14} /> Delete</button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => sortBy('name')}>Sort A–Z</button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => sortBy('size')}>Sort size</button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setItems((p) => [...p].reverse())}>Reverse</button>
          </div>
          <div className="img2pdf-timeline" role="list">
            {items.map((it) => (
              <div
                key={it.id}
                role="listitem"
                className={`img2pdf-card ${selected.has(it.id) ? 'selected' : ''} ${dragId === it.id ? 'dragging' : ''}`}
                draggable
                onDragStart={() => setDragId(it.id)}
                onDragOver={(e) => e.preventDefault()}
                onDrop={() => { if (dragId) reorder(dragId, it.id); setDragId(null); }}
                onClick={() => {
                  setPreviewId(it.id);
                  setSelected((s) => {
                    const n = new Set(s);
                    if (n.has(it.id)) n.delete(it.id);
                    else n.add(it.id);
                    return n;
                  });
                }}
              >
                <img src={it.thumbUrl} alt="" style={{ transform: `rotate(${it.rotation}deg)` }} />
                <span className="img2pdf-card-name">{it.name}</span>
                {it.analysis?.duplicateOf && <em className="img2pdf-dup">Duplicate</em>}
              </div>
            ))}
          </div>
          {previewItem && (
            <div className="img2pdf-preview glass">
              <img src={previewItem.thumbUrl} alt="" style={{ transform: `rotate(${previewItem.rotation}deg)` }} />
            </div>
          )}
          <div className="img2pdf-nav">
            <button type="button" className="btn btn-ghost" onClick={() => setStep(0)}>← Back</button>
            <button type="button" className="btn btn-primary" onClick={() => setStep(2)}>Optimize →</button>
          </div>
        </section>
      )}

      {step === 2 && (
        <section className="img2pdf-panel glass">
          <div className="img2pdf-split">
            <div className="img2pdf-settings">
              <h3>PDF settings</h3>
              <label>Page size
                <select value={settings.pageSize} onChange={(e) => setSettings({ ...settings, pageSize: e.target.value as Img2PdfSettings['pageSize'] })}>
                  <option value="auto">Auto</option>
                  <option value="a4">A4</option>
                  <option value="a3">A3</option>
                  <option value="a5">A5</option>
                  <option value="letter">Letter</option>
                  <option value="legal">Legal</option>
                  <option value="tabloid">Tabloid</option>
                </select>
              </label>
              <label>Orientation
                <select value={settings.orientation} onChange={(e) => setSettings({ ...settings, orientation: e.target.value as Img2PdfSettings['orientation'] })}>
                  <option value="auto">Auto</option>
                  <option value="portrait">Portrait</option>
                  <option value="landscape">Landscape</option>
                </select>
              </label>
              <label>Margins
                <select value={settings.margin} onChange={(e) => setSettings({ ...settings, margin: e.target.value as Img2PdfSettings['margin'] })}>
                  <option value="none">None</option>
                  <option value="small">Small</option>
                  <option value="medium">Medium</option>
                  <option value="large">Large</option>
                </select>
              </label>
              <label>Fit mode
                <select value={settings.fit} onChange={(e) => setSettings({ ...settings, fit: e.target.value as Img2PdfSettings['fit'] })}>
                  <option value="contain">Contain</option>
                  <option value="fill">Fill</option>
                  <option value="stretch">Stretch</option>
                  <option value="center">Center</option>
                  <option value="original">Original size</option>
                </select>
              </label>
              <h3>AI optimization</h3>
              {(['autoRotate', 'smartCompression', 'autoEnhance', 'sharpen'] as const).map((k) => (
                <label key={k} className="pdfconv-toggle">
                  <input
                    type="checkbox"
                    checked={settings.optimize[k]}
                    onChange={(e) => setSettings({ ...settings, optimize: { ...settings.optimize, [k]: e.target.checked } })}
                  />
                  {k === 'autoRotate' ? 'AI auto-rotate' : k === 'smartCompression' ? 'Smart compression' : k === 'autoEnhance' ? 'Auto enhance' : 'Sharpen'}
                </label>
              ))}
              <label>JPEG quality <span>{Math.round(settings.optimize.jpegQuality * 100)}%</span>
                <input
                  type="range" min={0.5} max={1} step={0.05}
                  value={settings.optimize.jpegQuality}
                  onChange={(e) => setSettings({ ...settings, optimize: { ...settings.optimize, jpegQuality: +e.target.value } })}
                />
              </label>
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => setAdvancedOpen((v) => !v)}>
                {advancedOpen ? 'Hide' : 'Show'} advanced options
              </button>
              {advancedOpen && (
                <div className="img2pdf-advanced">
                  <label>Watermark<input value={settings.advanced.watermark} onChange={(e) => setSettings({ ...settings, advanced: { ...settings.advanced, watermark: e.target.value } })} /></label>
                  <label>PDF password<input type="password" value={settings.advanced.password} onChange={(e) => setSettings({ ...settings, advanced: { ...settings.advanced, password: e.target.value } })} /></label>
                  <label className="pdfconv-toggle"><input type="checkbox" checked={settings.advanced.pageNumbers} onChange={(e) => setSettings({ ...settings, advanced: { ...settings.advanced, pageNumbers: e.target.checked } })} /> Page numbers</label>
                  <label>Title<input value={settings.advanced.title} onChange={(e) => setSettings({ ...settings, advanced: { ...settings.advanced, title: e.target.value } })} /></label>
                  <label>Header<input value={settings.advanced.header} onChange={(e) => setSettings({ ...settings, advanced: { ...settings.advanced, header: e.target.value } })} /></label>
                  <label>Footer<input value={settings.advanced.footer} onChange={(e) => setSettings({ ...settings, advanced: { ...settings.advanced, footer: e.target.value } })} /></label>
                </div>
              )}
            </div>
            <div className="img2pdf-analysis">
              <h3>AI image analysis</h3>
              <div className="img2pdf-analysis-grid">
                {items.slice(0, 12).map((it) => (
                  <div key={it.id} className="img2pdf-analysis-card glass">
                    <img src={it.thumbUrl} alt="" />
                    <div>
                      <b>{it.analysis?.qualityScore ?? '—'}/100</b>
                      <span className="muted">{it.analysis?.width}×{it.analysis?.height}</span>
                      {it.analysis?.isBlurry && <em className="img2pdf-warn">Blurry</em>}
                      {it.analysis?.isDocument && <em className="img2pdf-ok">Document</em>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
          <div className="img2pdf-trust">
            <span className="pdfword-privacy-badge"><Icon name="shield" size={14} /> 100% browser processing · files never leave your device</span>
          </div>
          <div className="img2pdf-nav">
            <button type="button" className="btn btn-ghost" onClick={() => setStep(1)}>← Back</button>
            <button type="button" className="btn btn-primary" onClick={() => void runConvert()}>
              <Icon name="file-text" size={16} /> Convert to PDF
            </button>
          </div>
        </section>
      )}

      <div className="mergepdf-fab-rail" aria-label="Quick actions">
        <button type="button" className="mergepdf-fab mergepdf-fab-ai" title="AI Assistant" onClick={openAI}>
          <Icon name="sparkles" size={18} />
        </button>
        {phase === 'done' && results.length > 0 && (
          <button type="button" className="mergepdf-fab" title="Share" onClick={() => setShareOpen(true)}>
            <Icon name="link" size={18} />
          </button>
        )}
      </div>

      <input ref={cameraRef} type="file" accept="image/*" capture="environment" hidden onChange={(e) => { const f = e.target.files; if (f?.length) void addFiles([...f]); e.target.value = ''; }} />
      <input ref={zipRef} type="file" accept=".zip,application/zip" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) void addFiles([f]); e.target.value = ''; }} />
    </div>
  );
}
