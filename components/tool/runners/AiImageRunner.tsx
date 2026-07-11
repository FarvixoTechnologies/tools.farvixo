'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { ErrorBox, Processing, ShareButton, useStepScrollReset, useToolPhase } from '../shared';
import { downloadBlob } from '@/lib/download';
import {
  AI_MODELS,
  ASPECT_PRESETS,
  DEFAULT_ADJUSTMENTS,
  DEFAULT_CONTROLS,
  GENERATION_MODES,
  PROMPT_TEMPLATES,
  RESOLUTIONS,
  SAMPLERS,
  SCHEDULERS,
  STUDIO_STEPS,
  STYLES,
  addPromptHistory,
  analyzeImageCreative,
  applyAdjustments,
  blurBackground,
  enhancePrompt,
  expandCanvasImage,
  expandPrompt,
  exportImage,
  generateBatch,
  generateStudioImage,
  getPromptHistory,
  getResolution,
  loadBlobToCanvas,
  magicPrompt,
  randomPrompt,
  rewritePrompt,
  saveSession,
  scorePrompt,
  shortenPrompt,
  translatePrompt,
  upscaleCanvas,
  type BatchJob,
  type CreativeScores,
  type EditAdjustments,
  type ExportFormat,
  type GeneratedImage,
  type GenerationControls,
  type GenerationMode,
  type ReferenceSlot,
  type StudioStep,
} from '@/lib/engines/ai-image-studio-engine';

/* ─── Helpers ───────────────────────────────────────────────────────────── */

function uid() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function ScoreBar({ label, value, color }: { label: string; value: number; color?: string }) {
  return (
    <div className="aistudio-score-row">
      <span>{label}</span>
      <div className="aistudio-score-track">
        <div className="aistudio-score-fill" style={{ width: `${value}%`, background: color || 'var(--brand-primary)' }} />
      </div>
      <b>{value}</b>
    </div>
  );
}

function StudioSteps({ current }: { current: StudioStep }) {
  const idx = STUDIO_STEPS.findIndex((s) => s.id === current);
  return (
    <div className="aistudio-steps" aria-label="Creative workflow">
      {STUDIO_STEPS.map((s, i) => (
        <div key={s.id} className={`aistudio-step ${i < idx ? 'done' : ''} ${i === idx ? 'active' : ''}`}>
          <span className="aistudio-step-dot">{i < idx ? <Icon name="check" size={11} /> : i + 1}</span>
          <span>{s.label}</span>
          {i < STUDIO_STEPS.length - 1 && <span className="aistudio-step-line" aria-hidden />}
        </div>
      ))}
    </div>
  );
}

/* ─── Main Component ──────────────────────────────────────────────────────── */

export default function AiImageRunner() {
  const { toast } = useUI();
  const { phase, setPhase, error, fail, reset } = useToolPhase();

  // Workflow
  const [step, setStep] = useState<StudioStep>('prompt');
  useStepScrollReset(step); // every step opens from the top, like a new page
  const [leftTab, setLeftTab] = useState<'prompt' | 'model' | 'controls' | 'refs'>('prompt');
  const [rightTab, setRightTab] = useState<'edit' | 'enhance' | 'export' | 'assistant'>('edit');

  // Prompt studio
  const [prompt, setPrompt] = useState('');
  const [negativePrompt, setNegativePrompt] = useState('');
  const [style, setStyle] = useState('None');
  const [mode, setMode] = useState<GenerationMode>('text-to-image');
  const [templateCat, setTemplateCat] = useState('All');
  const [promptLoading, setPromptLoading] = useState<string | null>(null);
  const [favorites, setFavorites] = useState<string[]>([]);
  const [promptHistory, setPromptHistory] = useState<string[]>([]);

  // Generation
  const [controls, setControls] = useState<GenerationControls>({ ...DEFAULT_CONTROLS });
  const [references, setReferences] = useState<ReferenceSlot[]>([]);
  const [images, setImages] = useState<GeneratedImage[]>([]);
  const [activeIdx, setActiveIdx] = useState(0);
  const [progress, setProgress] = useState(0);
  const [viewMode, setViewMode] = useState<'single' | 'grid' | 'compare'>('single');
  const [zoom, setZoom] = useState(100);
  const [fullscreen, setFullscreen] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  // Edit
  const [adjustments, setAdjustments] = useState<EditAdjustments>({ ...DEFAULT_ADJUSTMENTS });
  const [editPreview, setEditPreview] = useState<string>('');
  const [undoStack, setUndoStack] = useState<Blob[]>([]);
  const [redoStack, setRedoStack] = useState<Blob[]>([]);

  // Export
  const [exportFormat, setExportFormat] = useState<ExportFormat>('png');
  const [exportQuality, setExportQuality] = useState(92);
  const [transparentExport, setTransparentExport] = useState(false);

  // Assistant scores
  const [scores, setScores] = useState<CreativeScores | null>(null);
  const [scoresLoading, setScoresLoading] = useState(false);

  // Batch
  const [batchPrompts, setBatchPrompts] = useState('');
  const [batchJobs, setBatchJobs] = useState<BatchJob[]>([]);
  const [showBatch, setShowBatch] = useState(false);

  // FAB menus
  const [fabOpen, setFabOpen] = useState<'history' | 'library' | 'settings' | null>(null);
  const fabRef = useRef<HTMLDivElement>(null);

  // Private mode
  const [privateMode, setPrivateMode] = useState(false);

  const activeImage = images[activeIdx];
  const promptScore = scorePrompt(prompt);
  const resolution = getResolution(controls);

  useEffect(() => {
    setPromptHistory(getPromptHistory());
  }, []);

  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      if (fabRef.current?.contains(e.target as Node)) return;
      if ((e.target as Element).closest?.('.mergepdf-fab-menu-portal')) return;
      setFabOpen(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  // Live edit preview
  useEffect(() => {
    if (!activeImage?.blob) { setEditPreview(''); return; }
    let cancelled = false;
    void (async () => {
      const canvas = await loadBlobToCanvas(activeImage.blob);
      const edited = applyAdjustments(canvas, adjustments);
      const blob = await new Promise<Blob>((res, rej) => edited.toBlob((b) => b ? res(b) : rej(), 'image/png'));
      if (!cancelled) setEditPreview(URL.createObjectURL(blob));
    })();
    return () => { cancelled = true; };
  }, [activeImage?.blob, adjustments]);

  const pushUndo = useCallback((blob: Blob) => {
    setUndoStack((s) => [...s.slice(-19), blob]);
    setRedoStack([]);
  }, []);

  const generate = async () => {
    if (!prompt.trim()) { toast('Enter a prompt first', 'error'); return; }
    setStep('generate');
    setPhase('working');
    setProgress(0);
    abortRef.current = new AbortController();

    try {
      const count = Math.min(controls.numImages, 4);
      const results: GeneratedImage[] = [];

      for (let i = 0; i < count; i++) {
        const img = await generateStudioImage({
          prompt,
          negativePrompt,
          style,
          mode,
          controls: { ...controls, randomSeed: controls.randomSeed || i > 0 },
          references,
          signal: abortRef.current.signal,
          onProgress: (p) => setProgress(Math.round(((i + p / 100) / count) * 100)),
        });
        results.push(img);
      }

      setImages(results);
      setActiveIdx(0);
      addPromptHistory(prompt);
      setPromptHistory(getPromptHistory());
      if (!privateMode) saveSession({ prompt, negativePrompt, style, mode, controls });
      setPhase('done');
      setStep('edit');
      toast(`Generated ${results.length} image${results.length > 1 ? 's' : ''}`, 'success');

      if (results[0]) {
        setScoresLoading(true);
        void analyzeImageCreative(results[0].blob, prompt).then(setScores).finally(() => setScoresLoading(false));
      }
    } catch (e) {
      if ((e as Error).name !== 'AbortError') fail(e);
    }
  };

  const runPromptAction = async (action: string, fn: () => Promise<string>) => {
    setPromptLoading(action);
    try {
      const result = await fn();
      setPrompt(result.trim());
      toast(`${action} complete`, 'success');
    } catch {
      toast(`${action} failed`, 'error');
    }
    setPromptLoading(null);
  };

  const applyTemplate = (t: typeof PROMPT_TEMPLATES[0]) => {
    setPrompt(t.prompt);
    if (t.negative) setNegativePrompt(t.negative);
    toast(`Applied: ${t.title}`, 'info');
  };

  const addReference = (type: ReferenceSlot['type']) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = () => {
      const file = input.files?.[0];
      if (!file) return;
      const preview = URL.createObjectURL(file);
      setReferences((r) => [...r, { id: uid(), type, file, preview, weight: 0.7 }]);
    };
    input.click();
  };

  const runEnhancement = async (type: string) => {
    if (!activeImage) return;
    pushUndo(activeImage.blob);
    setPhase('working');
    try {
      let canvas = await loadBlobToCanvas(activeImage.blob);
      if (type === 'upscale2') canvas = await upscaleCanvas(canvas, 2);
      else if (type === 'upscale4') canvas = await upscaleCanvas(canvas, 4);
      else if (type === 'upscale8') canvas = await upscaleCanvas(canvas, 8);
      else if (type === 'expand') canvas = await expandCanvasImage(canvas, 20);
      else if (type === 'blur-bg') canvas = await blurBackground(canvas, 12);
      else if (type === 'auto') {
        const { autoEnhance } = await import('@/lib/image');
        autoEnhance(canvas);
      }

      const blob = await new Promise<Blob>((res, rej) => canvas.toBlob((b) => b ? res(b) : rej(), 'image/png'));
      const url = URL.createObjectURL(blob);
      const updated = { ...activeImage, blob, url, width: canvas.width, height: canvas.height };
      setImages((imgs) => imgs.map((img, i) => i === activeIdx ? updated : img));
      setPhase('done');
      toast(`${type} applied`, 'success');
    } catch (e) {
      fail(e);
    }
  };

  const handleExport = async () => {
    if (!activeImage) return;
    setStep('export');
    try {
      const blob = editPreview
        ? await exportImage(await fetch(editPreview).then((r) => r.blob()), exportFormat, exportQuality / 100, transparentExport)
        : await exportImage(activeImage.blob, exportFormat, exportQuality / 100, transparentExport);
      downloadBlob(blob, `farvixo-ai-${Date.now()}.${exportFormat}`);
      toast('Download started', 'success');
    } catch {
      toast('Export failed', 'error');
    }
  };

  const runBatch = async () => {
    const prompts = batchPrompts.split('\n').map((p) => p.trim()).filter(Boolean);
    if (!prompts.length) return;
    setShowBatch(true);
    setPhase('working');
    const jobs = await generateBatch(prompts, { negativePrompt, style, mode, controls, references }, setBatchJobs);
    setPhase('done');
    const done = jobs.filter((j) => j.status === 'done' && j.result);
    if (done.length) {
      setImages(done.map((j) => j.result!));
      setActiveIdx(0);
    }
  };

  const displayUrl = editPreview || activeImage?.url;

  const templateCategories = ['All', ...Array.from(new Set(PROMPT_TEMPLATES.map((t) => t.category)))];

  return (
    <div className="aistudio">
      {/* Header */}
      <div className="aistudio-header">
        <div className="aistudio-header-left">
          <div className="aistudio-badge"><Icon name="sparkles" size={14} /> Galactic Edition v15 · 100% Free</div>
          <h2 className="aistudio-title">AI Creative Studio</h2>
          <p className="aistudio-free-note">No login · No API key · Unlimited generations</p>
        </div>
        <StudioSteps current={step} />
        <div className="aistudio-header-actions">
          <button type="button" className={`aistudio-chip ${privateMode ? 'active' : ''}`} onClick={() => setPrivateMode((p) => !p)} title="Private mode">
            <Icon name="lock" size={13} /> Private
          </button>
          <button type="button" className="aistudio-chip" onClick={() => setShowBatch((b) => !b)}>
            <Icon name="grid" size={13} /> Batch
          </button>
        </div>
      </div>

      {/* Mode strip */}
      <div className="aistudio-modes" role="tablist" aria-label="Generation modes">
        {GENERATION_MODES.map((m) => (
          <button key={m.id} type="button" role="tab" aria-selected={mode === m.id}
            className={`aistudio-mode-btn ${mode === m.id ? 'active' : ''}`}
            onClick={() => setMode(m.id)}>
            <Icon name={m.icon} size={14} />
            <span>{m.label}</span>
          </button>
        ))}
      </div>

      {/* Main layout */}
      <div className="aistudio-layout">
        {/* Left sidebar */}
        <aside className="aistudio-sidebar aistudio-sidebar-left">
          <div className="aistudio-tabs">
            {(['prompt', 'model', 'controls', 'refs'] as const).map((t) => (
              <button key={t} type="button" className={leftTab === t ? 'active' : ''} onClick={() => setLeftTab(t)}>
                {t === 'prompt' ? 'Prompt' : t === 'model' ? 'Models' : t === 'controls' ? 'Controls' : 'Refs'}
              </button>
            ))}
          </div>

          <div className="aistudio-panel-body">
            {leftTab === 'prompt' && (
              <>
                <div className="field">
                  <div className="aistudio-label-row">
                    <label>Prompt</label>
                    <span className="aistudio-token-badge">{promptScore.tokens} tokens · Score {promptScore.score}</span>
                  </div>
                  <textarea value={prompt} rows={4} placeholder="Describe your vision in detail..."
                    onChange={(e) => setPrompt(e.target.value)} aria-label="Image prompt" />
                  <div className="aistudio-score-track aistudio-prompt-score">
                    <div className="aistudio-score-fill" style={{ width: `${promptScore.score}%` }} />
                  </div>
                </div>

                <div className="field">
                  <label>Negative Prompt</label>
                  <textarea value={negativePrompt} rows={2} placeholder="What to avoid..."
                    onChange={(e) => setNegativePrompt(e.target.value)} />
                </div>

                <div className="field">
                  <label>Style</label>
                  <select value={style} onChange={(e) => setStyle(e.target.value)}>
                    {STYLES.map((s) => <option key={s} value={s}>{s}</option>)}
                  </select>
                </div>

                <div className="aistudio-prompt-actions">
                  {[
                    { id: 'Enhance', icon: 'sparkles', fn: () => enhancePrompt(prompt, style) },
                    { id: 'Rewrite', icon: 'refresh', fn: () => rewritePrompt(prompt) },
                    { id: 'Expand', icon: 'scaling', fn: () => expandPrompt(prompt) },
                    { id: 'Shorten', icon: 'chevron-down', fn: () => shortenPrompt(prompt) },
                    { id: 'Magic', icon: 'zap', fn: () => magicPrompt(prompt, mode) },
                  ].map((a) => (
                    <button key={a.id} type="button" className="aistudio-mini-btn" disabled={!!promptLoading}
                      onClick={() => void runPromptAction(a.id, a.fn)}>
                      <Icon name={a.icon} size={12} /> {promptLoading === a.id ? '…' : a.id}
                    </button>
                  ))}
                </div>

                <div className="aistudio-prompt-actions">
                  <button type="button" className="aistudio-mini-btn" onClick={() => setPrompt(randomPrompt())}>
                    <Icon name="refresh" size={12} /> Surprise
                  </button>
                  <button type="button" className="aistudio-mini-btn" onClick={() => void runPromptAction('Translate', () => translatePrompt(prompt, 'English'))}>
                    <Icon name="globe" size={12} /> Translate
                  </button>
                </div>

                {promptScore.suggestions.length > 0 && (
                  <div className="aistudio-suggestions">
                    {promptScore.suggestions.map((s) => <span key={s}>💡 {s}</span>)}
                  </div>
                )}

                <details className="aistudio-details">
                  <summary>Prompt Templates</summary>
                  <div className="aistudio-template-cats">
                    {templateCategories.map((c) => (
                      <button key={c} type="button" className={templateCat === c ? 'active' : ''} onClick={() => setTemplateCat(c)}>{c}</button>
                    ))}
                  </div>
                  <div className="aistudio-templates">
                    {PROMPT_TEMPLATES.filter((t) => templateCat === 'All' || t.category === templateCat).map((t) => (
                      <button key={t.id} type="button" className="aistudio-template-item" onClick={() => applyTemplate(t)}>
                        <b>{t.title}</b><span>{t.category}</span>
                      </button>
                    ))}
                  </div>
                </details>
              </>
            )}

            {leftTab === 'model' && (
              <div className="aistudio-model-grid">
                {AI_MODELS.map((m) => (
                  <button key={m.id} type="button"
                    className={`aistudio-model-card ${controls.model === m.id ? 'active' : ''}`}
                    onClick={() => setControls((c) => ({ ...c, model: m.id }))}>
                    <div className="aistudio-model-head">
                      <b>{m.label}</b>
                      <span className="aistudio-free-tag">FREE</span>
                    </div>
                    <span className="aistudio-model-provider">{m.provider}</span>
                    <p>{m.description}</p>
                  </button>
                ))}
              </div>
            )}

            {leftTab === 'controls' && (
              <>
                <div className="field">
                  <label>Aspect Ratio</label>
                  <select value={controls.aspectId} onChange={(e) => setControls((c) => ({ ...c, aspectId: e.target.value, useCustomResolution: false }))}>
                    {ASPECT_PRESETS.map((a) => <option key={a.id} value={a.id}>{a.label} ({a.w}×{a.h})</option>)}
                  </select>
                </div>

                <div className="field checkbox-row">
                  <input type="checkbox" id="custom-res" checked={controls.useCustomResolution}
                    onChange={(e) => setControls((c) => ({ ...c, useCustomResolution: e.target.checked }))} />
                  <label htmlFor="custom-res">Custom Resolution</label>
                </div>

                {controls.useCustomResolution ? (
                  <div className="field-row">
                    <div className="field">
                      <label>Width</label>
                      <input type="number" min={256} max={8192} value={controls.customWidth}
                        onChange={(e) => setControls((c) => ({ ...c, customWidth: +e.target.value }))} />
                    </div>
                    <div className="field">
                      <label>Height</label>
                      <input type="number" min={256} max={8192} value={controls.customHeight}
                        onChange={(e) => setControls((c) => ({ ...c, customHeight: +e.target.value }))} />
                    </div>
                  </div>
                ) : (
                  <div className="aistudio-res-chips">
                    {RESOLUTIONS.map((r) => (
                      <button key={r} type="button" className="aistudio-res-chip"
                        onClick={() => {
                          const preset = ASPECT_PRESETS.find((a) => a.id === controls.aspectId) || ASPECT_PRESETS[0];
                          const scale = r / Math.max(preset.w, preset.h);
                          setControls((c) => ({ ...c, customWidth: Math.round(preset.w * scale), customHeight: Math.round(preset.h * scale), useCustomResolution: true }));
                        }}>{r}</button>
                    ))}
                  </div>
                )}

                <div className="field">
                  <label>CFG Scale <span className="range-value">{controls.cfgScale}</span></label>
                  <input type="range" min={1} max={20} value={controls.cfgScale}
                    onChange={(e) => setControls((c) => ({ ...c, cfgScale: +e.target.value }))} />
                </div>
                <div className="field">
                  <label>Steps <span className="range-value">{controls.steps}</span></label>
                  <input type="range" min={10} max={50} value={controls.steps}
                    onChange={(e) => setControls((c) => ({ ...c, steps: +e.target.value }))} />
                </div>
                <div className="field">
                  <label>Creativity <span className="range-value">{controls.creativity}%</span></label>
                  <input type="range" min={0} max={100} value={controls.creativity}
                    onChange={(e) => setControls((c) => ({ ...c, creativity: +e.target.value }))} />
                </div>
                <div className="field">
                  <label>Denoise Strength <span className="range-value">{controls.denoiseStrength}</span></label>
                  <input type="range" min={0} max={1} step={0.05} value={controls.denoiseStrength}
                    onChange={(e) => setControls((c) => ({ ...c, denoiseStrength: +e.target.value }))} />
                </div>
                <div className="field-row">
                  <div className="field">
                    <label>Sampler</label>
                    <select value={controls.sampler} onChange={(e) => setControls((c) => ({ ...c, sampler: e.target.value }))}>
                      {SAMPLERS.map((s) => <option key={s}>{s}</option>)}
                    </select>
                  </div>
                  <div className="field">
                    <label>Scheduler</label>
                    <select value={controls.scheduler} onChange={(e) => setControls((c) => ({ ...c, scheduler: e.target.value }))}>
                      {SCHEDULERS.map((s) => <option key={s}>{s}</option>)}
                    </select>
                  </div>
                </div>
                <div className="field-row">
                  <div className="field">
                    <label>Seed</label>
                    <input type="number" value={controls.seed} disabled={controls.randomSeed}
                      onChange={(e) => setControls((c) => ({ ...c, seed: +e.target.value }))} />
                  </div>
                  <div className="field checkbox-row" style={{ alignSelf: 'end', paddingBottom: 10 }}>
                    <input type="checkbox" id="rand-seed" checked={controls.randomSeed}
                      onChange={(e) => setControls((c) => ({ ...c, randomSeed: e.target.checked }))} />
                    <label htmlFor="rand-seed">Random</label>
                  </div>
                </div>
                <div className="field">
                  <label>Images <span className="range-value">{controls.numImages}</span></label>
                  <input type="range" min={1} max={4} value={controls.numImages}
                    onChange={(e) => setControls((c) => ({ ...c, numImages: +e.target.value }))} />
                </div>
                <p className="aistudio-meta">{resolution.w}×{resolution.h} · {controls.model}</p>
              </>
            )}

            {leftTab === 'refs' && (
              <>
                <p className="aistudio-meta">Upload reference images to guide generation</p>
                <div className="aistudio-ref-actions">
                  {(['style', 'character', 'face', 'pose', 'object', 'sketch', 'source'] as const).map((t) => (
                    <button key={t} type="button" className="aistudio-mini-btn" onClick={() => addReference(t)}>
                      <Icon name="upload" size={12} /> {t}
                    </button>
                  ))}
                </div>
                <div className="aistudio-ref-grid">
                  {references.map((r) => (
                    <div key={r.id} className="aistudio-ref-card">
                      {r.preview && /* eslint-disable-next-line @next/next/no-img-element */ <img src={r.preview} alt={r.type} />}
                      <span>{r.type}</span>
                      <input type="range" min={0} max={1} step={0.1} value={r.weight}
                        onChange={(e) => setReferences((refs) => refs.map((x) => x.id === r.id ? { ...x, weight: +e.target.value } : x))} />
                      <button type="button" className="aistudio-ref-remove" onClick={() => setReferences((refs) => refs.filter((x) => x.id !== r.id))}>
                        <Icon name="x" size={12} />
                      </button>
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>

          <div className="aistudio-sidebar-footer">
            {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
            <p className="aistudio-free-hint"><Icon name="check-circle" size={13} /> Powered by free AI — no credit card ever</p>
            <button type="button" className="btn btn-primary aistudio-generate-btn" disabled={!prompt.trim() || phase === 'working'}
              onClick={() => void generate()}>
              <Icon name="sparkles" size={16} />
              {phase === 'working' ? 'Generating...' : `Generate ${controls.numImages > 1 ? `(${controls.numImages})` : ''}`}
            </button>
          </div>
        </aside>

        {/* Center canvas */}
        <main className="aistudio-canvas">
          <div className="aistudio-canvas-toolbar">
            <div className="aistudio-view-toggle">
              {(['single', 'grid', 'compare'] as const).map((v) => (
                <button key={v} type="button" className={viewMode === v ? 'active' : ''} onClick={() => setViewMode(v)} aria-label={`${v} view`}>
                  <Icon name={v === 'single' ? 'image' : 'grid'} size={15} />
                </button>
              ))}
            </div>
            <div className="aistudio-zoom">
              <button type="button" onClick={() => setZoom((z) => Math.max(25, z - 25))} aria-label="Zoom out"><Icon name="chevron-down" size={14} /></button>
              <span>{zoom}%</span>
              <button type="button" onClick={() => setZoom((z) => Math.min(400, z + 25))} aria-label="Zoom in"><Icon name="chevron-up" size={14} /></button>
            </div>
            <button type="button" className="aistudio-icon-btn" onClick={() => setFullscreen((f) => !f)} aria-label="Fullscreen">
              <Icon name="scaling" size={15} />
            </button>
          </div>

          <div className={`aistudio-viewport ${fullscreen ? 'fullscreen' : ''}`}>
            {phase === 'working' && (
              <div className="aistudio-generating">
                <Processing label="Creating your masterpiece..." progress={progress / 100} />
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => abortRef.current?.abort()}>Cancel</button>
              </div>
            )}

            {phase !== 'working' && viewMode === 'single' && !displayUrl && (
              <div className="aistudio-empty">
                <div className="aistudio-empty-icon"><Icon name="sparkles" size={40} /></div>
                <b>Your canvas awaits</b>
                <p>Write a prompt and hit Generate to create stunning AI art</p>
              </div>
            )}

            {phase !== 'working' && viewMode === 'single' && displayUrl && (
              <div className="aistudio-image-wrap" style={{ transform: `scale(${zoom / 100})` }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={displayUrl} alt={prompt || 'Generated image'} className="aistudio-main-image" />
              </div>
            )}

            {viewMode === 'grid' && images.length > 0 && (
              <div className="aistudio-gallery">
                {images.map((img, i) => (
                  <button key={img.id} type="button" className={`aistudio-gallery-item ${i === activeIdx ? 'active' : ''}`}
                    onClick={() => { setActiveIdx(i); setViewMode('single'); }}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={img.url} alt={`Variation ${i + 1}`} />
                  </button>
                ))}
              </div>
            )}

            {viewMode === 'compare' && images.length >= 2 && (
              <div className="aistudio-compare">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={images[0]?.url} alt="Before" />
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={images[1]?.url} alt="After" />
              </div>
            )}
          </div>

          {activeImage && (
            <div className="aistudio-meta-bar">
              <span>{activeImage.width}×{activeImage.height}</span>
              <span>Seed {activeImage.seed}</span>
              <span>{activeImage.model}</span>
              <span>{new Date(activeImage.createdAt).toLocaleTimeString()}</span>
            </div>
          )}
        </main>

        {/* Right sidebar */}
        <aside className="aistudio-sidebar aistudio-sidebar-right">
          <div className="aistudio-tabs">
            {(['edit', 'enhance', 'export', 'assistant'] as const).map((t) => (
              <button key={t} type="button" className={rightTab === t ? 'active' : ''} onClick={() => setRightTab(t)}>
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </button>
            ))}
          </div>

          <div className="aistudio-panel-body">
            {rightTab === 'edit' && (
              <>
                <div className="aistudio-undo-row">
                  <button type="button" className="aistudio-mini-btn" disabled={!undoStack.length} onClick={() => {
                    if (!activeImage || !undoStack.length) return;
                    setRedoStack((r) => [...r, activeImage.blob]);
                    const prev = undoStack[undoStack.length - 1];
                    setUndoStack((s) => s.slice(0, -1));
                    const url = URL.createObjectURL(prev);
                    setImages((imgs) => imgs.map((img, i) => i === activeIdx ? { ...img, blob: prev, url } : img));
                  }}><Icon name="refresh" size={12} /> Undo</button>
                  <button type="button" className="aistudio-mini-btn" disabled={!redoStack.length} onClick={() => {
                    if (!activeImage || !redoStack.length) return;
                    setUndoStack((s) => [...s, activeImage.blob]);
                    const next = redoStack[redoStack.length - 1];
                    setRedoStack((r) => r.slice(0, -1));
                    const url = URL.createObjectURL(next);
                    setImages((imgs) => imgs.map((img, i) => i === activeIdx ? { ...img, blob: next, url } : img));
                  }}><Icon name="rotate" size={12} /> Redo</button>
                </div>

                {(['brightness', 'contrast', 'saturation', 'sharpness', 'blur', 'hue', 'warmth'] as const).map((key) => (
                  <div key={key} className="field">
                    <label>{key.charAt(0).toUpperCase() + key.slice(1)} <span className="range-value">{adjustments[key]}</span></label>
                    <input type="range" min={key === 'blur' ? 0 : -50} max={50} value={adjustments[key]}
                      onChange={(e) => setAdjustments((a) => ({ ...a, [key]: +e.target.value }))} />
                  </div>
                ))}

                <button type="button" className="btn btn-ghost btn-sm" onClick={() => setAdjustments({ ...DEFAULT_ADJUSTMENTS })}>
                  Reset Adjustments
                </button>
              </>
            )}

            {rightTab === 'enhance' && (
              <div className="aistudio-enhance-grid">
                {[
                  { id: 'upscale2', label: 'Upscale 2×', icon: 'scaling' },
                  { id: 'upscale4', label: 'Upscale 4×', icon: 'scaling' },
                  { id: 'upscale8', label: 'Upscale 8×', icon: 'scaling' },
                  { id: 'auto', label: 'Auto Enhance', icon: 'sparkles' },
                  { id: 'expand', label: 'Expand Canvas', icon: 'scaling' },
                  { id: 'blur-bg', label: 'Blur Background', icon: 'eye' },
                ].map((e) => (
                  <button key={e.id} type="button" className="aistudio-enhance-btn" disabled={!activeImage || phase === 'working'}
                    onClick={() => void runEnhancement(e.id)}>
                    <Icon name={e.icon} size={16} />
                    <span>{e.label}</span>
                  </button>
                ))}
              </div>
            )}

            {rightTab === 'export' && (
              <>
                <div className="field">
                  <label>Format</label>
                  <div className="aistudio-format-grid">
                    {(['png', 'jpg', 'webp', 'bmp', 'tiff', 'avif'] as ExportFormat[]).map((f) => (
                      <button key={f} type="button" className={exportFormat === f ? 'active' : ''} onClick={() => setExportFormat(f)}>
                        {f.toUpperCase()}
                      </button>
                    ))}
                  </div>
                </div>
                <div className="field">
                  <label>Quality <span className="range-value">{exportQuality}%</span></label>
                  <input type="range" min={50} max={100} value={exportQuality} onChange={(e) => setExportQuality(+e.target.value)} />
                </div>
                <div className="field checkbox-row">
                  <input type="checkbox" id="transparent" checked={transparentExport} onChange={(e) => setTransparentExport(e.target.checked)} />
                  <label htmlFor="transparent">Transparent PNG</label>
                </div>
                <div className="aistudio-export-actions">
                  <button type="button" className="btn btn-primary" disabled={!activeImage} onClick={() => void handleExport()}>
                    <Icon name="download" size={15} /> Download
                  </button>
                  {activeImage && <ShareButton file={{ name: `farvixo-ai.${exportFormat}`, blob: activeImage.blob }} toolSlug="ai-image-generator" />}
                  <button type="button" className="btn btn-ghost" disabled={!displayUrl} onClick={async () => {
                    if (!displayUrl) return;
                    try {
                      await navigator.clipboard.write([new ClipboardItem({ 'image/png': await fetch(displayUrl).then((r) => r.blob()) })]);
                      toast('Copied to clipboard', 'success');
                    } catch { toast('Copy failed', 'error'); }
                  }}>
                    <Icon name="copy" size={15} /> Copy
                  </button>
                </div>
              </>
            )}

            {rightTab === 'assistant' && (
              <div className="aistudio-scores">
                {scoresLoading && <p className="aistudio-meta">Analyzing...</p>}
                {scores && (
                  <>
                    <ScoreBar label="Quality" value={scores.quality} />
                    <ScoreBar label="Creativity" value={scores.creativity} color="#c026d3" />
                    <ScoreBar label="Commercial" value={scores.commercial} color="#f5b93d" />
                    <ScoreBar label="Composition" value={scores.composition} />
                    <ScoreBar label="Lighting" value={scores.lighting} />
                    <ScoreBar label="NSFW Risk" value={scores.nsfwRisk} color="#ef4444" />
                  </>
                )}
                {!scores && !scoresLoading && <p className="aistudio-meta">Generate an image to see AI analysis scores</p>}
                <div className="aistudio-safety">
                  <Icon name="shield" size={14} /> NSFW filter active · Secure processing
                </div>
              </div>
            )}
          </div>
        </aside>
      </div>

      {/* Batch panel */}
      {showBatch && (
        <div className="aistudio-batch">
          <div className="aistudio-batch-head">
            <b>Batch Studio</b>
            <button type="button" onClick={() => setShowBatch(false)} aria-label="Close"><Icon name="x" size={16} /></button>
          </div>
          <textarea value={batchPrompts} rows={4} placeholder="One prompt per line..."
            onChange={(e) => setBatchPrompts(e.target.value)} />
          <button type="button" className="btn btn-primary btn-sm" onClick={() => void runBatch()}>Run Batch</button>
          {batchJobs.length > 0 && (
            <div className="aistudio-batch-jobs">
              {batchJobs.map((j) => (
                <div key={j.id} className={`aistudio-batch-job ${j.status}`}>
                  <span>{j.prompt.slice(0, 50)}...</span>
                  <span>{j.status}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* FAB rail */}
      <div ref={fabRef} className="aistudio-fab-rail" aria-label="Quick actions">
        <div className="mergepdf-fab-wrap">
          <button type="button" className={`mergepdf-fab mergepdf-fab-ai ${fabOpen === 'history' ? 'active' : ''}`}
            onClick={() => setFabOpen((m) => m === 'history' ? null : 'history')} title="History">
            <Icon name="clock" size={18} />
          </button>
          {fabOpen === 'history' && typeof document !== 'undefined' && createPortal(
            <div className="mergepdf-fab-menu mergepdf-fab-menu-portal mergepdf-fab-menu-wide"
              style={{ position: 'fixed', bottom: 100, right: 24 }} role="menu">
              <div className="mergepdf-fab-menu-title">Prompt History</div>
              {promptHistory.length === 0 && <p className="aistudio-meta" style={{ padding: '0 12px' }}>No history yet</p>}
              {promptHistory.map((p) => (
                <button key={p} type="button" className="mergepdf-fab-menu-item" onClick={() => { setPrompt(p); setFabOpen(null); }}>
                  {p.slice(0, 80)}{p.length > 80 ? '...' : ''}
                </button>
              ))}
            </div>, document.body,
          )}
        </div>
        <div className="mergepdf-fab-wrap">
          <button type="button" className={`mergepdf-fab ${fabOpen === 'library' ? 'active' : ''}`}
            onClick={() => setFabOpen((m) => m === 'library' ? null : 'library')} title="Prompt Library">
            <Icon name="file-text" size={18} />
          </button>
          {fabOpen === 'library' && typeof document !== 'undefined' && createPortal(
            <div className="mergepdf-fab-menu mergepdf-fab-menu-portal mergepdf-fab-menu-wide"
              style={{ position: 'fixed', bottom: 100, right: 80 }} role="menu">
              <div className="mergepdf-fab-menu-title">Favorites</div>
              {favorites.length === 0 && <p className="aistudio-meta" style={{ padding: '0 12px' }}>Star prompts to save them</p>}
              {favorites.map((p) => (
                <button key={p} type="button" className="mergepdf-fab-menu-item" onClick={() => { setPrompt(p); setFabOpen(null); }}>{p.slice(0, 80)}</button>
              ))}
            </div>, document.body,
          )}
        </div>
        <button type="button" className="mergepdf-fab" title="Favorite prompt"
          onClick={() => { if (prompt) { setFavorites((f) => [...new Set([prompt, ...f])].slice(0, 20)); toast('Added to favorites', 'success'); } }}>
          <Icon name="star" size={18} />
        </button>
        <button type="button" className="mergepdf-fab" title="Regenerate" disabled={!prompt || phase === 'working'}
          onClick={() => void generate()}>
          <Icon name="refresh" size={18} />
        </button>
      </div>
    </div>
  );
}
