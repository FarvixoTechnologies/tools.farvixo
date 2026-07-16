'use client';

import { useCallback, useEffect, useRef, useState, type InputHTMLAttributes, type ReactNode, type RefObject } from 'react';
import { createPortal } from 'react-dom';
import dynamic from 'next/dynamic';
import type { Tool } from '@/data/tools';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { downloadBlob, formatBytes } from '@/lib/download';
import { recordJob } from '@/lib/jobs';
import { ErrorBox, ShareButton, useStepScrollReset, useToolPhase, type ResultFile } from '../shared';
import UniversalDragDropUploader from '../UniversalDragDropUploader';
import {
  DEFAULT_ENHANCEMENT,
  DEFAULT_OCR_OPTIONS,
  OCR_LANGUAGES,
  aiAssistOcr,
  analyzeDocument,
  applyEnhancements,
  detectPii,
  drawOcrOverlay,
  exportOcrBatchZip,
  exportOcrResult,
  extractOcrImagesFromZip,
  fetchOcrImageFromUrl,
  isAcceptedOcrFile,
  isOcrPdfFile,
  pdfToPageFiles,
  maskPii,
  runOcrOnFile,
  type DocumentDetection,
  type ExportFormat,
  type OcrEnhancementOptions,
  type OcrResult,
  type OcrRunOptions,
  type PreviewMode,
} from '@/lib/engines/ocr-engine';

const ShareModal = dynamic(() => import('../ShareModal'), { ssr: false });

const STEPS = ['Upload', 'AI Detect', 'Extract', 'Export'] as const;
type Step = 0 | 1 | 2 | 3;

interface OcrJob {
  id: string;
  file: File;
  detection?: DocumentDetection;
  result?: OcrResult;
  previewUrl?: string;
}

function uid() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

function Steps({ current }: { current: number }) {
  return (
    <div className="pdfconv-steps" aria-label="OCR progress">
      {STEPS.map((s, i) => (
        <div key={s} className={`pdfconv-step ${i < current ? 'done' : ''} ${i === current ? 'active' : ''}`}>
          <span className="pdfconv-step-dot">{i < current ? <Icon name="check" size={12} /> : i + 1}</span>
          <span className="pdfconv-step-label">{s}</span>
          {i < STEPS.length - 1 && <span className="pdfconv-step-line" aria-hidden />}
        </div>
      ))}
    </div>
  );
}

function ProgressRing({ progress, label }: { progress: number; label: string }) {
  const pct = Math.round(progress * 100);
  const r = 52;
  const circ = 2 * Math.PI * r;
  return (
    <div className="pdfconv-progress-ring-wrap">
      <svg className="pdfconv-progress-ring" viewBox="0 0 120 120">
        <circle cx="60" cy="60" r={r} fill="none" stroke="var(--border-subtle)" strokeWidth="8" />
        <circle cx="60" cy="60" r={r} fill="none" stroke="var(--brand-primary)" strokeWidth="8"
          strokeDasharray={circ} strokeDashoffset={circ * (1 - progress)} strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.3s', transform: 'rotate(-90deg)', transformOrigin: 'center' }}
        />
      </svg>
      <div className="pdfconv-progress-text"><b>{pct}%</b><span>{label}</span></div>
    </div>
  );
}

function FabDropdown({ open, anchorRef, wide, children }: {
  open: boolean;
  anchorRef: RefObject<HTMLDivElement | null>;
  wide?: boolean;
  children: ReactNode;
}) {
  const [pos, setPos] = useState({ top: 0, left: 0, transform: 'none' as string });
  useEffect(() => {
    if (!open || !anchorRef.current) return;
    const place = () => {
      const el = anchorRef.current!;
      const r = el.getBoundingClientRect();
      const menuW = wide ? 300 : 240;
      let left = r.right + 10;
      let top = r.top;
      let transform = 'none';
      if (left + menuW > window.innerWidth - 12) left = Math.max(12, r.left - menuW - 10);
      if (top + 280 > window.innerHeight - 12) { top = r.top; transform = 'translateY(calc(-100% - 8px))'; }
      setPos({ top, left, transform });
    };
    place();
    window.addEventListener('resize', place);
    window.addEventListener('scroll', place, true);
    return () => { window.removeEventListener('resize', place); window.removeEventListener('scroll', place, true); };
  }, [open, anchorRef, wide]);
  if (!open || typeof document === 'undefined') return null;
  return createPortal(
    <div className={`mergepdf-fab-menu mergepdf-fab-menu-portal ${wide ? 'mergepdf-fab-menu-wide' : ''}`}
      style={{ top: pos.top, left: pos.left, transform: pos.transform }} role="menu">{children}</div>,
    document.body,
  );
}

const EXPORT_FORMATS: { id: ExportFormat; label: string; icon: string }[] = [
  { id: 'txt', label: 'Plain Text', icon: 'file-text' },
  { id: 'docx', label: 'Word DOCX', icon: 'file-text' },
  { id: 'pdf', label: 'PDF', icon: 'file-text' },
  { id: 'searchable-pdf', label: 'Searchable PDF', icon: 'scan-text' },
  { id: 'csv', label: 'Excel CSV', icon: 'table' },
  { id: 'json', label: 'JSON', icon: 'braces' },
  { id: 'html', label: 'HTML', icon: 'code' },
  { id: 'md', label: 'Markdown', icon: 'hash' },
  { id: 'rtf', label: 'RTF', icon: 'file-text' },
  { id: 'xml', label: 'XML', icon: 'code' },
  { id: 'zip', label: 'ZIP Batch', icon: 'archive' },
];

const DOC_LABELS: Record<string, string> = {
  'printed-document': 'Printed Document',
  handwritten: 'Handwritten Notes',
  invoice: 'Invoice',
  receipt: 'Receipt',
  passport: 'Passport',
  aadhaar: 'Aadhaar Card',
  'pan-card': 'PAN Card',
  'voter-id': 'Voter ID',
  'driving-license': 'Driving License',
  'business-card': 'Business Card',
  resume: 'Resume',
  certificate: 'Certificate',
  'bank-statement': 'Bank Statement',
  'utility-bill': 'Utility Bill',
  'medical-report': 'Medical Report',
  newspaper: 'Newspaper',
  'book-page': 'Book Page',
  menu: 'Menu',
  whiteboard: 'Whiteboard',
  screenshot: 'Screenshot',
  'qr-code': 'QR Code',
  barcode: 'Barcode',
  table: 'Table / Form',
  formula: 'Mathematical Formula',
  unknown: 'Document',
};

export default function OcrImageRunner({ tool }: { tool: Tool }) {
  const { toast } = useUI();
  const { phase, setPhase, error, fail, reset, progress, setProgress } = useToolPhase();
  const [step, setStep] = useState<Step>(0);
  const [jobs, setJobs] = useState<OcrJob[]>([]);
  const [activeIdx, setActiveIdx] = useState(0);
  const [options, setOptions] = useState<OcrRunOptions>(DEFAULT_OCR_OPTIONS);
  const [exportFormat, setExportFormat] = useState<ExportFormat>('txt');
  const [previewMode, setPreviewMode] = useState<PreviewMode>('split');
  const [zoom, setZoom] = useState(100);
  const [search, setSearch] = useState('');
  const [replaceWith, setReplaceWith] = useState('');
  const [editedText, setEditedText] = useState('');
  const [status, setStatus] = useState('');
  const [resultFile, setResultFile] = useState<ResultFile | null>(null);
  const [shareOpen, setShareOpen] = useState(false);
  const [aiPanel, setAiPanel] = useState('');
  const [aiLoading, setAiLoading] = useState(false);
  const [urlValue, setUrlValue] = useState('');
  const [cameraOpen, setCameraOpen] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useStepScrollReset(step);

  const active = jobs[activeIdx];

  const addFiles = useCallback(async (incoming: File[]) => {
    const hasPdf = incoming.some((f) => isOcrPdfFile(f) || f.name.endsWith('.zip'));
    if (hasPdf) toast('Rendering PDF pages…', 'info');
    const images: File[] = [];
    for (const f of incoming) {
      if (f.name.endsWith('.zip')) {
        const extracted = await extractOcrImagesFromZip(f);
        for (const ef of extracted) {
          if (isOcrPdfFile(ef)) images.push(...await pdfToPageFiles(ef));
          else if (isAcceptedOcrFile(ef)) images.push(ef);
        }
      } else if (isOcrPdfFile(f)) {
        images.push(...await pdfToPageFiles(f));
      } else if (isAcceptedOcrFile(f)) {
        images.push(f);
      }
    }
    if (images.length === 0) {
      toast('No supported images found', 'error');
      return;
    }
    const newJobs: OcrJob[] = images.map((file) => ({
      id: uid(),
      file,
      previewUrl: URL.createObjectURL(file),
    }));
    setJobs((prev) => [...prev, ...newJobs]);
    if (jobs.length === 0) setActiveIdx(0);
  }, [jobs.length, toast]);

  useEffect(() => {
    const onPaste = (e: ClipboardEvent) => {
      if (step !== 0) return;
      const items = e.clipboardData?.items;
      if (!items) return;
      const files: File[] = [];
      for (const item of items) {
        if (item.type.startsWith('image/')) {
          const blob = item.getAsFile();
          if (blob) files.push(new File([blob], `pasted-${Date.now()}.png`, { type: blob.type }));
        }
      }
      if (files.length) void addFiles(files);
    };
    window.addEventListener('paste', onPaste);
    return () => window.removeEventListener('paste', onPaste);
  }, [addFiles, step]);

  const runDetection = async () => {
    if (jobs.length === 0) return;
    setPhase('working');
    setStep(1);
    try {
      const updated = [...jobs];
      for (let i = 0; i < updated.length; i++) {
        setStatus(`AI detecting ${i + 1} of ${updated.length}...`);
        setProgress((i + 0.5) / updated.length);
        updated[i] = { ...updated[i], detection: await analyzeDocument(updated[i].file) };
      }
      setJobs(updated);
      setProgress(1);
      setPhase('idle');
      setStep(2);
    } catch (e) {
      fail(e);
    }
  };

  const runExtract = async () => {
    if (jobs.length === 0) return;
    setPhase('working');
    setStep(2);
    try {
      const updated = [...jobs];
      for (let i = 0; i < updated.length; i++) {
        const det = updated[i].detection ?? await analyzeDocument(updated[i].file);
        const result = await runOcrOnFile(updated[i].file, { ...options, enhancement: options.enhancement }, (p, s) => {
          setProgress((i + p) / updated.length);
          setStatus(s);
        });
        updated[i] = { ...updated[i], detection: det, result };
      }
      setJobs(updated);
      setEditedText(updated[activeIdx]?.result?.text ?? '');
      setPhase('idle');
      setStep(3);
      recordJob(tool.slug, 'completed');
    } catch (e) {
      fail(e);
    }
  };

  const handleExport = async () => {
    const results = jobs.filter((j) => j.result).map((j) => j.result!);
    if (results.length === 0) return;
    setPhase('working');
    try {
      let blob: Blob;
      let name: string;
      if (exportFormat === 'zip' || results.length > 1) {
        blob = await exportOcrBatchZip(results, exportFormat === 'zip' ? 'txt' : exportFormat);
        name = `ocr-batch-${Date.now()}.zip`;
      } else {
        const text = editedText || results[0].text;
        const r = { ...results[0], text: options.piiMask ? maskPii(text) : text };
        blob = await exportOcrResult(r, exportFormat, results[0].sourceName);
        const ext = exportFormat === 'searchable-pdf' ? 'pdf' : exportFormat;
        name = `${results[0].sourceName.replace(/\.[^.]+$/, '')}-ocr.${ext}`;
      }
      setResultFile({ name, blob });
      setPhase('done');
      recordJob(tool.slug, 'completed');
    } catch (e) {
      fail(e);
    }
  };

  const openCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
      streamRef.current = stream;
      setCameraOpen(true);
      setTimeout(() => { if (videoRef.current) videoRef.current.srcObject = stream; }, 50);
    } catch {
      toast('Camera access denied', 'error');
    }
  };

  const capturePhoto = () => {
    const video = videoRef.current;
    if (!video) return;
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d')!.drawImage(video, 0, 0);
    canvas.toBlob((blob) => {
      if (!blob) return;
      void addFiles([new File([blob], `camera-${Date.now()}.jpg`, { type: 'image/jpeg' })]);
      closeCamera();
    }, 'image/jpeg', 0.92);
  };

  const closeCamera = () => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    setCameraOpen(false);
  };

  const updateEnhancement = (patch: Partial<OcrEnhancementOptions>) => {
    setOptions((o) => ({ ...o, enhancement: { ...o.enhancement, ...patch } }));
  };

  const displayText = editedText || active?.result?.text || '';
  const highlightedText = search
    ? displayText.split(new RegExp(`(${search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi'))
    : null;

  const getPreviewCanvas = (): string | null => {
    const result = active?.result;
    // GOLDEN RULE: the preview always shows the UNTOUCHED original upload —
    // never the binarized/cropped OCR working copy.
    const base = result?.originalCanvas;
    if ((previewMode === 'overlay' || previewMode === 'heatmap') && base && result) {
      // Draw OCR boxes onto the original, mapping coords back via the transform.
      return drawOcrOverlay(base, result, previewMode === 'heatmap' ? 'heatmap' : 'boxes', result.transform)
        .toDataURL('image/png');
    }
    // Original / Split / Side → the raw uploaded file (best fidelity, no re-encode).
    return active?.previewUrl ?? base?.toDataURL('image/png') ?? null;
  };

  const resetAll = () => {
    reset();
    setStep(0);
    setJobs([]);
    setActiveIdx(0);
    setEditedText('');
    setResultFile(null);
    setSearch('');
    setAiPanel('');
    setStatus('');
    setProgress(undefined);
  };

  const fab = (
    <FabRail
      options={options}
      setOptions={setOptions}
      onAi={async (action) => {
        if (!displayText) return;
        setAiLoading(true);
        try {
          setAiPanel(await aiAssistOcr(action, displayText));
        } catch {
          toast('AI assistant unavailable', 'error');
        }
        setAiLoading(false);
      }}
      aiLoading={aiLoading}
      aiPanel={aiPanel}
      onCopy={() => void navigator.clipboard.writeText(displayText).then(() => toast('Copied', 'success'))}
    />
  );

  if (phase === 'working' && (step === 1 || step === 2)) {
    return (
      <div className="ocr-shell">
        <Steps current={step} />
        <ProgressRing progress={progress ?? 0} label={status || 'Processing...'} />
        <p className="muted" style={{ textAlign: 'center' }}>100% browser OCR — your files never leave your device</p>
      </div>
    );
  }

  if (phase === 'done' && resultFile) {
    return (
      <div className="ocr-shell">
        <Steps current={3} />
        <div className="mergepdf-success-check"><Icon name="check" size={28} /></div>
        <h3 style={{ textAlign: 'center' }}>Export complete</h3>
        <p className="muted" style={{ textAlign: 'center' }}>{resultFile.name} · {formatBytes(resultFile.blob.size)}</p>
        <div className="mergepdf-result-actions">
          <button type="button" className="btn btn-primary" onClick={() => downloadBlob(resultFile.blob, resultFile.name)}>
            <Icon name="download" size={16} /> Download
          </button>
          <ShareButton file={resultFile} toolSlug={tool.slug} />
          <button type="button" className="btn btn-ghost" onClick={() => { setPhase('idle'); setResultFile(null); }}>Edit &amp; re-export</button>
          <button type="button" className="btn btn-ghost" onClick={resetAll}>New scan</button>
        </div>
        {shareOpen && <ShareModal open={shareOpen} onClose={() => setShareOpen(false)} file={resultFile} toolSlug={tool.slug} />}
      </div>
    );
  }

  if (step === 3 && active?.result) {
    const previewUrl = getPreviewCanvas();
    const pii = detectPii(displayText);

    return (
      <div className="ocr-shell ocr-export">
        <Steps current={3} />
        {fab}

        <div className="ocr-confidence-bar">
          <div className="ocr-confidence-meter">
            <div className="ocr-confidence-fill" style={{ width: `${active.result.confidence}%` }} />
          </div>
          <span><b>{active.result.confidence}%</b> OCR confidence · {DOC_LABELS[active.result.detection.documentType] ?? 'Document'}</span>
          {pii.length > 0 && <span className="ocr-pii-badge"><Icon name="shield" size={12} /> PII detected: {pii.join(', ')}</span>}
        </div>

        <div className="bgrem-edit-toolbar">
          <div className="bgrem-preview-modes">
            {(['original', 'overlay', 'split', 'side', 'heatmap'] as PreviewMode[]).map((m) => (
              <button key={m} type="button" className={`btn btn-ghost btn-sm ${previewMode === m ? 'active' : ''}`} onClick={() => setPreviewMode(m)}>
                {m.charAt(0).toUpperCase() + m.slice(1)}
              </button>
            ))}
          </div>
          <div className="bgrem-zoom">
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setZoom((z) => Math.max(50, z - 25))}>−</button>
            <span>{zoom}%</span>
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setZoom((z) => Math.min(300, z + 25))}>+</button>
          </div>
        </div>

        <div className={`ocr-preview-grid ocr-preview-${previewMode}`}>
          {(previewMode === 'original' || previewMode === 'split' || previewMode === 'side' || previewMode === 'overlay' || previewMode === 'heatmap') && previewUrl && (
            <div className="ocr-preview-pane">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={previewUrl} alt="OCR preview" style={{ transform: `scale(${zoom / 100})`, transformOrigin: 'top center' }} />
            </div>
          )}
          {(previewMode === 'split' || previewMode === 'side' || previewMode === 'original') && (
            <div className="ocr-text-pane">
              <div className="ocr-search-row">
                <input placeholder="Search extracted text..." value={search} onChange={(e) => setSearch(e.target.value)} aria-label="Search text" />
                <input placeholder="Replace with..." value={replaceWith} onChange={(e) => setReplaceWith(e.target.value)} aria-label="Replace with" />
                <button type="button" className="btn btn-ghost btn-sm" disabled={!search} onClick={() => setEditedText(displayText.replaceAll(search, replaceWith))}>Replace</button>
              </div>
              <textarea
                className="ocr-text-editor"
                value={displayText}
                onChange={(e) => setEditedText(e.target.value)}
                aria-label="Extracted text"
              />
              {highlightedText && search && (
                <div className="ocr-highlight-preview muted" aria-hidden>
                  {highlightedText.map((part, i) =>
                    part.toLowerCase() === search.toLowerCase()
                      ? <mark key={i}>{part}</mark>
                      : <span key={i}>{part}</span>,
                  )}
                </div>
              )}
            </div>
          )}
        </div>

        {jobs.length > 1 && (
          <div className="bgrem-batch-strip">
            {jobs.map((j, i) => (
              <button key={j.id} type="button" className={`bgrem-batch-thumb ${i === activeIdx ? 'active' : ''}`}
                onClick={() => { setActiveIdx(i); setEditedText(j.result?.text ?? ''); }}>
                {j.file.name.slice(0, 16)}
              </button>
            ))}
          </div>
        )}

        <div className="ocr-export-formats">
          <h4>Export format</h4>
          <div className="ocr-format-grid">
            {EXPORT_FORMATS.map((f) => (
              <button key={f.id} type="button" className={`ocr-format-btn ${exportFormat === f.id ? 'active' : ''}`}
                onClick={() => setExportFormat(f.id)}>
                <Icon name={f.icon} size={16} />
                <span>{f.label}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="ocr-export-actions">
          <button type="button" className="btn btn-primary" onClick={() => void handleExport()}>
            <Icon name="download" size={16} /> Export {exportFormat.toUpperCase()}
          </button>
          <button type="button" className="btn btn-ghost" onClick={() => void navigator.clipboard.writeText(displayText).then(() => toast('Copied', 'success'))}>
            <Icon name="copy" size={15} /> Clipboard
          </button>
          <button type="button" className="btn btn-ghost" onClick={resetAll}>New scan</button>
        </div>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
      </div>
    );
  }

  if (step === 2) {
    const det = active?.detection;
    return (
      <div className="ocr-shell">
        <Steps current={2} />
        {fab}
        {det && (
          <div className="bgrem-detection-card">
            <div className="bgrem-detection-score">
              <b>{det.confidence}%</b>
              <span>AI Match</span>
            </div>
            <div>
              <h3>{DOC_LABELS[det.documentType] ?? 'Document'}</h3>
              <p className="muted">{det.width}×{det.height}px · {det.megapixels} MP</p>
              <ul className="bgrem-features">
                {det.features.slice(0, 10).map((f) => (
                  <li key={f}><Icon name="check" size={12} /> {f}</li>
                ))}
              </ul>
            </div>
          </div>
        )}

        <div className="ocr-options-grid">
          <div className="options-panel">
            <h3>OCR Engine</h3>
            <div className="field">
              <label>Language</label>
              <select value={options.lang} onChange={(e) => setOptions((o) => ({ ...o, lang: e.target.value }))}>
                {OCR_LANGUAGES.map((l) => <option key={l.code} value={l.code}>{l.label}</option>)}
              </select>
            </div>
            <div className="field">
              <label>Mode</label>
              <select value={options.mode} onChange={(e) => setOptions((o) => ({ ...o, mode: e.target.value as OcrRunOptions['mode'] }))}>
                <option value="auto">Auto</option>
                <option value="printed">Printed OCR</option>
                <option value="handwriting">Handwriting OCR</option>
                <option value="mixed">Mixed OCR</option>
                <option value="table">Table OCR</option>
                <option value="form">Form OCR</option>
              </select>
            </div>
            <label className="checkbox-row">
              <input type="checkbox" checked={options.useVision} onChange={(e) => setOptions((o) => ({ ...o, useVision: e.target.checked }))} />
              Vision AI OCR — best for photos, posters &amp; handwriting
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={options.aiRepair} onChange={(e) => setOptions((o) => ({ ...o, aiRepair: e.target.checked }))} />
              AI text repair (all languages)
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={options.piiMask} onChange={(e) => setOptions((o) => ({ ...o, piiMask: e.target.checked }))} />
              AI PII masking on export
            </label>
          </div>

          <div className="options-panel">
            <h3>AI Enhancement</h3>
            {([
              ['binarize', 'Scan Mode (B&W) — best accuracy'],
              ['grayscale', 'Grayscale'],
              ['autoCrop', 'Auto Crop'],
              ['denoise', 'AI Denoise'],
              ['sharpen', 'AI Sharpen'],
              ['contrast', 'Contrast Boost'],
              ['shadowRemoval', 'Shadow Removal'],
              ['upscale2x', 'AI Upscale 2×'],
              ['upscale4x', 'AI Upscale 4×'],
            ] as const).map(([key, label]) => (
              <label key={key} className="checkbox-row">
                <input type="checkbox" checked={options.enhancement[key]} onChange={(e) => updateEnhancement({ [key]: e.target.checked })} />
                {label}
              </label>
            ))}
          </div>
        </div>

        {active?.previewUrl && (
          <div className="ocr-thumb-preview">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={active.previewUrl} alt="Upload preview" />
          </div>
        )}

        <div className="ocr-step-actions">
          <button type="button" className="btn btn-ghost" onClick={() => setStep(0)}>Back</button>
          <button type="button" className="btn btn-primary" onClick={() => void runExtract()}>
            <Icon name="scan-text" size={16} /> Extract Text
          </button>
        </div>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
      </div>
    );
  }

  if (step === 1 && active?.detection) {
    const det = active.detection;
    return (
      <div className="ocr-shell">
        <Steps current={1} />
        <div className="bgrem-detection-card">
          <div className="bgrem-detection-score">
            <b>{det.confidence}%</b>
            <span>Detected</span>
          </div>
          <div>
            <h3>{DOC_LABELS[det.documentType] ?? 'Document'}</h3>
            <p className="muted">AI classified your upload — ready for OCR extraction</p>
            <ul className="bgrem-features">
              {det.features.slice(0, 8).map((f) => (
                <li key={f}><Icon name="sparkles" size={12} /> {f}</li>
              ))}
            </ul>
          </div>
        </div>
        {jobs.length > 1 && <p className="muted" style={{ textAlign: 'center' }}>{jobs.length} images in batch queue</p>}
        <div className="ocr-step-actions">
          <button type="button" className="btn btn-ghost" onClick={() => setStep(0)}>Add more</button>
          <button type="button" className="btn btn-primary" onClick={() => { setStep(2); }}>
            Continue to Extract <Icon name="arrow-right" size={16} />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="ocr-shell">
      <Steps current={0} />
      <UniversalDragDropUploader
        accept={tool.accept}
        multiple
        onFiles={(f) => void addFiles(f)}
        title="Drop images, PDF scans, or ZIP batch"
        buttonLabel="Choose Files"
        note="JPG · PNG · WEBP · HEIC · AVIF · BMP · TIFF · GIF · SVG · PDF · ZIP · 100% private"
        accent="var(--accent-image)"
      />

      <div className="bgrem-upload-actions">
        <button type="button" className="btn btn-outline btn-sm" onClick={() => void openCamera()}>
          <Icon name="camera" size={14} /> Camera Capture
        </button>
        <label className="btn btn-outline btn-sm" style={{ cursor: 'pointer' }}>
          <Icon name="folder" size={14} /> Folder Upload
          <input type="file" multiple hidden {...{ webkitdirectory: '', directory: '' } as InputHTMLAttributes<HTMLInputElement>} onChange={(e) => {
            const f = Array.from(e.target.files ?? []);
            void addFiles(f);
            e.target.value = '';
          }} />
        </label>
      </div>

      <div className="bgrem-url-row">
        <input placeholder="Import from URL..." value={urlValue} onChange={(e) => setUrlValue(e.target.value)} aria-label="Image URL" />
        <button type="button" className="btn btn-primary btn-sm" onClick={() => void fetchOcrImageFromUrl(urlValue.trim())
          .then((f) => addFiles([f]))
          .catch(() => toast('Invalid image URL', 'error'))}>Import</button>
      </div>

      {jobs.length > 0 && (
        <div className="pdfconv-thumbs">
          {jobs.slice(0, 8).map((j, i) => (
            <figure key={j.id} className="pdfconv-thumb">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={j.previewUrl} alt={j.file.name} />
              <figcaption>{j.file.name.slice(0, 18)}</figcaption>
            </figure>
          ))}
          {jobs.length > 8 && <div className="pdfconv-thumb-more">+{jobs.length - 8} more</div>}
        </div>
      )}

      <p className="muted" style={{ textAlign: 'center', fontSize: 13 }}>
        <Icon name="shield" size={13} /> Private browser OCR · Paste with Ctrl+V · WebAssembly engine · No upload to cloud
      </p>

      <div className="ocr-step-actions">
        <button type="button" className="btn btn-primary" disabled={jobs.length === 0} onClick={() => void runDetection()}>
          <Icon name="sparkles" size={16} /> AI Detect &amp; Continue
        </button>
      </div>

      {cameraOpen && (
        <div className="ocr-camera-modal" role="dialog" aria-label="Camera capture">
          <video ref={videoRef} autoPlay playsInline muted className="ocr-camera-video" />
          <div className="ocr-camera-actions">
            <button type="button" className="btn btn-primary" onClick={capturePhoto}><Icon name="camera" size={16} /> Capture</button>
            <button type="button" className="btn btn-ghost" onClick={closeCamera}>Cancel</button>
          </div>
        </div>
      )}

      {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
    </div>
  );
}

function FabRail({ options, setOptions, onAi, aiLoading, aiPanel, onCopy }: {
  options: OcrRunOptions;
  setOptions: (o: OcrRunOptions) => void;
  onAi: (action: 'summarize' | 'translate' | 'keywords' | 'classify') => void;
  aiLoading: boolean;
  aiPanel: string;
  onCopy: () => void;
}) {
  const [openMenu, setOpenMenu] = useState<'settings' | 'ai' | null>(null);
  const railRef = useRef<HTMLDivElement>(null);
  const aiRef = useRef<HTMLDivElement>(null);
  const settingsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDown = (e: MouseEvent) => {
      const t = e.target as Node;
      if (railRef.current?.contains(t)) return;
      if ((t as Element).closest?.('.mergepdf-fab-menu-portal')) return;
      setOpenMenu(null);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, []);

  return (
    <div ref={railRef} className="mergepdf-fab-rail ocr-fab-rail" aria-label="Quick actions">
      <div ref={aiRef} className="mergepdf-fab-wrap">
        <button type="button" className={`mergepdf-fab mergepdf-fab-ai ${openMenu === 'ai' ? 'active' : ''}`}
          onClick={() => setOpenMenu((m) => m === 'ai' ? null : 'ai')} title="AI Assistant">
          <Icon name="sparkles" size={18} />
        </button>
        <FabDropdown open={openMenu === 'ai'} anchorRef={aiRef} wide>
          <p className="mergepdf-fab-menu-title">AI Smart Assistant</p>
          {(['summarize', 'translate', 'keywords', 'classify'] as const).map((a) => (
            <button key={a} type="button" className="mergepdf-fab-menu-item" disabled={aiLoading}
              onClick={() => { onAi(a); setOpenMenu('ai'); }}>
              <Icon name="sparkles" size={14} /> {a.charAt(0).toUpperCase() + a.slice(1)}
            </button>
          ))}
          {aiPanel && <p className="mergepdf-fab-menu-note" style={{ whiteSpace: 'pre-wrap' }}>{aiPanel}</p>}
        </FabDropdown>
      </div>
      <button type="button" className="mergepdf-fab" onClick={onCopy} title="Copy to clipboard">
        <Icon name="copy" size={18} />
      </button>
      <div ref={settingsRef} className="mergepdf-fab-wrap">
        <button type="button" className={`mergepdf-fab ${openMenu === 'settings' ? 'active' : ''}`}
          onClick={() => setOpenMenu((m) => m === 'settings' ? null : 'settings')} title="Settings">
          <Icon name="settings" size={18} />
        </button>
        <FabDropdown open={openMenu === 'settings'} anchorRef={settingsRef} wide>
          <p className="mergepdf-fab-menu-title">OCR Settings</p>
          <label className="mergepdf-fab-menu-item" style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input type="checkbox" checked={options.preserveFormatting} onChange={(e) => setOptions({ ...options, preserveFormatting: e.target.checked })} />
            Preserve formatting
          </label>
          <label className="mergepdf-fab-menu-item" style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input type="checkbox" checked={options.preserveParagraphs} onChange={(e) => setOptions({ ...options, preserveParagraphs: e.target.checked })} />
            Preserve paragraphs
          </label>
          <label className="mergepdf-fab-menu-item" style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input type="checkbox" checked={options.piiMask} onChange={(e) => setOptions({ ...options, piiMask: e.target.checked })} />
            PII masking
          </label>
          <button type="button" className="mergepdf-fab-menu-item" onClick={() => setOptions({ ...options, enhancement: DEFAULT_ENHANCEMENT })}>
            Reset enhancements
          </button>
        </FabDropdown>
      </div>
    </div>
  );
}
