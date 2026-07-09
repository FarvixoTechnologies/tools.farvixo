'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import Link from 'next/link';
import Icon from '@/components/Icon';
import { FileDrop, Processing, ErrorBox, useToolPhase, type ResultFile } from '../shared';
import ToolWorkspace from '../ToolWorkspace';

import {
  type EditorTool,
  type PageAnnotation,
  exportAnnotatedPdf,
  extractTextItems,
  loadPdfDocument,
  newAnnotationId,
  renderPageToCanvas,
  detectPiiInText,
} from '@/lib/engines/pdf-editor-engine';
import { analyzeDocument } from '@/lib/pdf-intelligence';
import { recordJob } from '@/lib/jobs';
import { trackEvent } from '@/lib/analytics-client';


const TOOLS: { id: EditorTool; label: string; icon: string }[] = [
  { id: 'select', label: 'Select', icon: 'hand' },
  { id: 'text', label: 'Text', icon: 'type' },
  { id: 'highlight', label: 'Highlight', icon: 'pen' },
  { id: 'rect', label: 'Rectangle', icon: 'crop' },
  { id: 'draw', label: 'Draw', icon: 'pen' },
  { id: 'image', label: 'Image', icon: 'image' },
];

export default function PdfEditorRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [file, setFile] = useState<File | null>(null);
  const [pageCount, setPageCount] = useState(0);
  const [pageIndex, setPageIndex] = useState(0);
  const [scale, setScale] = useState(1.2);
  const [activeTool, setActiveTool] = useState<EditorTool>('select');
  const [annotations, setAnnotations] = useState<PageAnnotation[]>([]);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [status, setStatus] = useState('');
  const [aiSummary, setAiSummary] = useState('');
  const [piiHits, setPiiHits] = useState<ReturnType<typeof detectPiiInText>>([]);
  const [undoStack, setUndoStack] = useState<PageAnnotation[][]>([]);

  const containerRef = useRef<HTMLDivElement>(null);
  const bgCanvasRef = useRef<HTMLCanvasElement>(null);
  const overlayRef = useRef<HTMLCanvasElement>(null);
  const pdfBytesRef = useRef<ArrayBuffer | null>(null);
  const pdfRef = useRef<Awaited<ReturnType<typeof loadPdfDocument>> | null>(null);
  const drawingRef = useRef(false);
  const drawPointsRef = useRef<number[]>([]);
  const dragStartRef = useRef<{ x: number; y: number } | null>(null);

  const pushUndo = useCallback(() => {
    setUndoStack((s) => [...s.slice(-30), [...annotations]]);
  }, [annotations]);

  const undo = () => {
    const prev = undoStack[undoStack.length - 1];
    if (!prev) return;
    setAnnotations(prev);
    setUndoStack((s) => s.slice(0, -1));
  };

  const renderPage = useCallback(async () => {
    if (!pdfRef.current || !bgCanvasRef.current || !overlayRef.current) return;
    const canvas = await renderPageToCanvas(pdfRef.current, pageIndex + 1, scale);
    const bg = bgCanvasRef.current;
    bg.width = canvas.width;
    bg.height = canvas.height;
    bg.getContext('2d')!.drawImage(canvas, 0, 0);
    const ov = overlayRef.current;
    ov.width = canvas.width;
    ov.height = canvas.height;
    redrawOverlay();
  }, [pageIndex, scale]);

  const redrawOverlay = useCallback(() => {
    const ov = overlayRef.current;
    if (!ov) return;
    const ctx = ov.getContext('2d')!;
    ctx.clearRect(0, 0, ov.width, ov.height);
    for (const ann of annotations.filter((a) => a.pageIndex === pageIndex)) {
      ctx.globalAlpha = ann.opacity ?? (ann.tool === 'highlight' ? 0.35 : 1);
      switch (ann.tool) {
        case 'highlight':
          ctx.fillStyle = ann.color ?? '#FFE566';
          ctx.fillRect(ann.x, ann.y, ann.width ?? 100, ann.height ?? 18);
          break;
        case 'rect':
          ctx.strokeStyle = ann.color ?? '#6C4DFF';
          ctx.lineWidth = 2;
          ctx.strokeRect(ann.x, ann.y, ann.width ?? 80, ann.height ?? 40);
          break;
        case 'text':
          ctx.fillStyle = ann.color ?? '#1a1a28';
          ctx.font = `${ann.fontSize ?? 14}px Inter, sans-serif`;
          ctx.fillText(ann.text ?? '', ann.x, ann.y);
          break;
        case 'draw':
          if (ann.points && ann.points.length >= 4) {
            ctx.strokeStyle = ann.color ?? '#3333cc';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(ann.points[0], ann.points[1]);
            for (let i = 2; i < ann.points.length; i += 2) ctx.lineTo(ann.points[i], ann.points[i + 1]);
            ctx.stroke();
          }
          break;
        case 'image':
        case 'stamp':
          if (ann.imageDataUrl) {
            const img = new Image();
            img.src = ann.imageDataUrl;
            img.onload = () => ctx.drawImage(img, ann.x, ann.y, ann.width ?? 80, ann.height ?? 80);
          }
          break;
        default:
          break;
      }
      ctx.globalAlpha = 1;
    }
  }, [annotations, pageIndex]);

  useEffect(() => { void renderPage(); }, [renderPage]);
  useEffect(() => { redrawOverlay(); }, [redrawOverlay]);

  const loadFile = async (files: File[]) => {
    const f = files[0];
    if (!f) return;
    setFile(f);
    setPhase('working');
    setStatus('Loading PDF...');
    try {
      const bytes = await f.arrayBuffer();
      pdfBytesRef.current = bytes;
      const pdf = await loadPdfDocument(f);
      pdfRef.current = pdf;
      setPageCount(pdf.numPages);
      setPageIndex(0);
      setAnnotations([]);
      setResults([]);
      setPhase('idle');
      setStatus('');
      const textItems = await extractTextItems(pdf, 1);
      const fullText = textItems.map((t) => t.text).join(' ');
      setPiiHits(detectPiiInText(fullText));
    } catch (e) {
      fail(e);
    }
  };

  const onOverlayPointer = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const ov = overlayRef.current;
    if (!ov) return;
    const rect = ov.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * ov.width;
    const y = ((e.clientY - rect.top) / rect.height) * ov.height;

    if (activeTool === 'draw') {
      if (e.type === 'pointerdown') {
        drawingRef.current = true;
        drawPointsRef.current = [x, y];
      } else if (e.type === 'pointermove' && drawingRef.current) {
        drawPointsRef.current.push(x, y);
        redrawOverlay();
        const ctx = ov.getContext('2d')!;
        const pts = drawPointsRef.current;
        ctx.strokeStyle = '#3333cc';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(pts[0], pts[1]);
        for (let i = 2; i < pts.length; i += 2) ctx.lineTo(pts[i], pts[i + 1]);
        ctx.stroke();
      } else if (e.type === 'pointerup' && drawingRef.current) {
        drawingRef.current = false;
        pushUndo();
        setAnnotations((a) => [...a, {
          id: newAnnotationId(), pageIndex, tool: 'draw', x: 0, y: 0, points: [...drawPointsRef.current],
        }]);
      }
      return;
    }

    if (activeTool === 'text' && e.type === 'pointerdown') {
      const text = window.prompt('Enter text:');
      if (!text) return;
      pushUndo();
      setAnnotations((a) => [...a, {
        id: newAnnotationId(), pageIndex, tool: 'text', x, y, text, fontSize: 14,
      }]);
      return;
    }

    if ((activeTool === 'highlight' || activeTool === 'rect') && e.type === 'pointerdown') {
      dragStartRef.current = { x, y };
    } else if ((activeTool === 'highlight' || activeTool === 'rect') && e.type === 'pointerup' && dragStartRef.current) {
      const s = dragStartRef.current;
      dragStartRef.current = null;
      pushUndo();
      setAnnotations((a) => [...a, {
        id: newAnnotationId(),
        pageIndex,
        tool: activeTool,
        x: Math.min(s.x, x),
        y: Math.min(s.y, y),
        width: Math.abs(x - s.x),
        height: Math.abs(y - s.y),
      }]);
    }

    if (activeTool === 'image' && e.type === 'pointerdown') {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.onchange = () => {
        const imgFile = input.files?.[0];
        if (!imgFile) return;
        const reader = new FileReader();
        reader.onload = () => {
          pushUndo();
          setAnnotations((a) => [...a, {
            id: newAnnotationId(), pageIndex, tool: 'image', x, y, width: 120, height: 80,
            imageDataUrl: reader.result as string,
          }]);
        };
        reader.readAsDataURL(imgFile);
      };
      input.click();
    }
  };

  const redactPii = () => {
    pushUndo();
    const newAnns: PageAnnotation[] = piiHits.map((h, i) => ({
      id: newAnnotationId(),
      pageIndex: 0,
      tool: 'highlight' as const,
      x: 40 + i * 5,
      y: 80 + i * 22,
      width: Math.max(80, h.match.length * 8),
      height: 18,
      color: '#000000',
      opacity: 1,
    }));
    setAnnotations((a) => [...a, ...newAnns]);
    trackEvent('pdf_editor_ai_action', { action: 'smart_redact', count: newAnns.length });
  };

  const runAiSummary = async () => {
    if (!file) return;
    setStatus('AI analyzing page...');
    try {
      const doc = await analyzeDocument(file, () => {});
      setAiSummary(
        `Document type: ${doc.documentType}. ${doc.totalWords} words across ${doc.pageCount} pages. ` +
        `Headings: ${doc.headings.length}, Tables detected: ${doc.tables.length}.`,
      );
      trackEvent('pdf_editor_ai_action', { action: 'summarize' });
    } catch {
      setAiSummary('Could not analyze document.');
    } finally {
      setStatus('');
    }
  };

  const exportPdf = async () => {
    if (!pdfBytesRef.current || !file) return;
    setPhase('working');
    setStatus('Exporting PDF...');
    try {
      const out = await exportAnnotatedPdf(pdfBytesRef.current, annotations, scale);
      const blob = new Blob([new Uint8Array(out)], { type: 'application/pdf' });
      const name = file.name.replace(/\.pdf$/i, '') + '-edited.pdf';
      setResults([{ name, blob }]);
      setPhase('done');
      recordJob(tool.slug, 'completed');
      trackEvent('pdf_editor_export', { pages: pageCount, annotations: annotations.length });
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => {
    setFile(null);
    setAnnotations([]);
    setResults([]);
    pdfRef.current = null;
    pdfBytesRef.current = null;
    reset();
  };

  if (phase === 'done' && results.length > 0) {
    return (
      <ToolWorkspace file={results[0]} toolSlug={tool.slug}>
        <div className="result-box">
          <span className="result-badge"><Icon name="check-circle" size={16} /> PDF exported</span>
          <div className="result-actions">
            <button className="btn btn-primary" onClick={() => {
              const url = URL.createObjectURL(results[0].blob);
              const a = document.createElement('a');
              a.href = url;
              a.download = results[0].name;
              a.click();
            }}>
              <Icon name="download" size={16} /> Download
            </button>
            <button className="btn btn-ghost" onClick={resetAll}><Icon name="refresh" size={15} /> Edit Another</button>
          </div>
        </div>
      </ToolWorkspace>
    );
  }

  return (
    <ToolWorkspace
      file={results[0] ?? null}
      toolSlug={tool.slug}
      onFilesPasted={(files) => void loadFile(files)}
    >
      <div className="pdf-editor">
        {!file && (
          <FileDrop accept=".pdf" files={[]} onFiles={(f) => void loadFile(f)} hint="PDF only · Edit in browser" />
        )}

        {phase === 'working' && <Processing label={status || 'Processing...'} />}
        {phase === 'error' && <ErrorBox message={error} onRetry={resetAll} />}

        {file && phase !== 'working' && (
          <>
            <div className="pdf-editor-toolbar glass">
              <div className="pdf-editor-tools">
                {TOOLS.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    className={`btn btn-ghost btn-sm ${activeTool === t.id ? 'active' : ''}`}
                    onClick={() => setActiveTool(t.id)}
                    aria-label={t.label}
                  >
                    <Icon name={t.icon} size={15} /> {t.label}
                  </button>
                ))}
              </div>
              <div className="pdf-editor-actions">
                <button type="button" className="btn btn-ghost btn-sm" onClick={undo} disabled={!undoStack.length}>
                  <Icon name="rotate" size={14} /> Undo
                </button>
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => setScale((s) => Math.max(0.5, s - 0.2))}>−</button>
                <span className="mono muted">{Math.round(scale * 100)}%</span>
                <button type="button" className="btn btn-ghost btn-sm" onClick={() => setScale((s) => Math.min(3, s + 0.2))}>+</button>
                <button type="button" className="btn btn-primary btn-sm" onClick={() => void exportPdf()}>
                  <Icon name="download" size={14} /> Export PDF
                </button>
              </div>
            </div>

            <div className="pdf-editor-layout">
              <aside className="pdf-editor-sidebar glass">
                <h4>Pages</h4>
                {Array.from({ length: pageCount }, (_, i) => (
                  <button
                    key={i}
                    type="button"
                    className={`pdf-editor-thumb ${pageIndex === i ? 'active' : ''}`}
                    onClick={() => setPageIndex(i)}
                  >
                    Page {i + 1}
                  </button>
                ))}

                <h4 className="mt-4">AI Assistant</h4>
                <button type="button" className="btn btn-ghost btn-sm w-full" onClick={() => void runAiSummary()}>
                  <Icon name="sparkles" size={14} /> Summarize
                </button>
                {piiHits.length > 0 && (
                  <button type="button" className="btn btn-ghost btn-sm w-full mt-2" onClick={redactPii}>
                    <Icon name="shield" size={14} /> Redact PII ({piiHits.length})
                  </button>
                )}
                {aiSummary && <p className="muted pdf-editor-ai-note">{aiSummary}</p>}

                <h4 className="mt-4">Handoff</h4>
                <Link href="/tools/pdf/compress-pdf" className="btn btn-ghost btn-sm w-full">Compress PDF</Link>
                <Link href="/tools/pdf/sign-pdf" className="btn btn-ghost btn-sm w-full mt-2">Sign PDF</Link>
              </aside>

              <div ref={containerRef} className="pdf-editor-canvas-wrap">
                <canvas ref={bgCanvasRef} className="pdf-editor-bg" />
                <canvas
                  ref={overlayRef}
                  className="pdf-editor-overlay"
                  onPointerDown={onOverlayPointer}
                  onPointerMove={onOverlayPointer}
                  onPointerUp={onOverlayPointer}
                  onPointerLeave={onOverlayPointer}
                />
              </div>

              <aside className="pdf-editor-panel glass">
                <h4>Layers ({annotations.filter((a) => a.pageIndex === pageIndex).length})</h4>
                <ul className="pdf-editor-layers">
                  {annotations.filter((a) => a.pageIndex === pageIndex).map((ann) => (
                    <li key={ann.id}>
                      {ann.tool} {ann.text ? `— ${ann.text.slice(0, 20)}` : ''}
                      <button
                        type="button"
                        className="icon-btn"
                        aria-label="Remove"
                        onClick={() => {
                          pushUndo();
                          setAnnotations((a) => a.filter((x) => x.id !== ann.id));
                        }}
                      >
                        <Icon name="x" size={12} />
                      </button>
                    </li>
                  ))}
                </ul>
              </aside>
            </div>
          </>
        )}
      </div>
    </ToolWorkspace>
  );
}
