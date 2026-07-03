'use client';

import { useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, Processing, ErrorBox, ResultView, useToolPhase, type ResultFile } from '../shared';
import { renderPdfPages } from '@/lib/pdf';
import { canvasToBlob } from '@/lib/image';
import { replaceExt } from '@/lib/download';

export default function PdfRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset, progress, setProgress } = useToolPhase();
  const [files, setFiles] = useState<File[]>([]);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [status, setStatus] = useState('Processing your PDF...');

  // options
  const [quality, setQuality] = useState(60);
  const [dpiScale, setDpiScale] = useState(1.2);
  const [splitMode, setSplitMode] = useState<'all' | 'range'>('all');
  const [range, setRange] = useState('1-3');
  const [password, setPassword] = useState('');
  const [pageSize, setPageSize] = useState<'a4' | 'fit'>('a4');
  const [convertDir, setConvertDir] = useState<'to-pdf' | 'to-images'>('to-pdf');
  const [editText, setEditText] = useState('');
  const [editPos, setEditPos] = useState<'header' | 'footer'>('footer');
  const [addPageNumbers, setAddPageNumbers] = useState(true);
  const [signPage, setSignPage] = useState(1);
  const [signPos, setSignPos] = useState<'bottom-right' | 'bottom-left' | 'top-right' | 'top-left'>('bottom-right');
  const sigCanvasRef = useRef<HTMLCanvasElement>(null);
  const drawing = useRef(false);
  const [hasSignature, setHasSignature] = useState(false);

  const mode = tool.mode;
  const targetKB = (tool.config?.targetKB as number) || 0;

  const sigDraw = (e: React.PointerEvent<HTMLCanvasElement>, kind: 'down' | 'move' | 'up') => {
    const c = sigCanvasRef.current;
    if (!c) return;
    const ctx = c.getContext('2d')!;
    const rect = c.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * c.width;
    const y = ((e.clientY - rect.top) / rect.height) * c.height;
    if (kind === 'down') { drawing.current = true; ctx.beginPath(); ctx.moveTo(x, y); c.setPointerCapture(e.pointerId); }
    else if (kind === 'move' && drawing.current) {
      ctx.strokeStyle = '#1a1aff';
      ctx.lineWidth = 2.5;
      ctx.lineCap = 'round';
      ctx.lineTo(x, y);
      ctx.stroke();
      setHasSignature(true);
    } else if (kind === 'up') drawing.current = false;
  };

  const run = async () => {
    if (files.length === 0) return;
    setPhase('working');
    try {
      const { PDFDocument, StandardFonts, rgb } = await import('@cantoo/pdf-lib');
      const out: ResultFile[] = [];

      if (mode === 'merge') {
        setStatus('Merging PDFs...');
        const merged = await PDFDocument.create();
        for (const f of files) {
          const src = await PDFDocument.load(await f.arrayBuffer(), { ignoreEncryption: true });
          const pages = await merged.copyPages(src, src.getPageIndices());
          pages.forEach((p) => merged.addPage(p));
        }
        out.push({ name: 'merged.pdf', blob: new Blob([new Uint8Array(await merged.save())], { type: 'application/pdf' }) });
      } else if (mode === 'split') {
        setStatus('Splitting PDF...');
        const src = await PDFDocument.load(await files[0].arrayBuffer(), { ignoreEncryption: true });
        const total = src.getPageCount();
        let ranges: number[][];
        if (splitMode === 'all') {
          ranges = Array.from({ length: total }, (_, i) => [i]);
        } else {
          const m = range.match(/(\d+)\s*-\s*(\d+)/);
          const a = m ? Math.max(1, +m[1]) : 1;
          const b = m ? Math.min(total, +m[2]) : total;
          ranges = [Array.from({ length: b - a + 1 }, (_, i) => a - 1 + i)];
        }
        for (let r = 0; r < ranges.length; r++) {
          const doc = await PDFDocument.create();
          const pages = await doc.copyPages(src, ranges[r]);
          pages.forEach((p) => doc.addPage(p));
          out.push({ name: `${files[0].name.replace(/\.pdf$/i, '')}-part${r + 1}.pdf`, blob: new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }) });
          setProgress((r + 1) / ranges.length);
        }
      } else if (mode === 'compress') {
        setStatus('Compressing PDF (re-rendering pages)...');
        const pages = await renderPdfPages(files[0], dpiScale, (d, t) => setProgress((d / t) * 0.7));
        const doc = await PDFDocument.create();
        const q = targetKB ? 0.55 : quality / 100;
        for (let i = 0; i < pages.length; i++) {
          const jpg = await canvasToBlob(pages[i].canvas, 'image/jpeg', q);
          const img = await doc.embedJpg(await jpg.arrayBuffer());
          const page = doc.addPage([pages[i].width, pages[i].height]);
          page.drawImage(img, { x: 0, y: 0, width: pages[i].width, height: pages[i].height });
          setProgress(0.7 + ((i + 1) / pages.length) * 0.3);
        }
        out.push({ name: replaceExt(files[0].name, 'pdf').replace(/\.pdf$/, '-compressed.pdf'), blob: new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }) });
      } else if (mode === 'protect') {
        setStatus('Encrypting PDF...');
        if (!password) throw new Error('Please enter a password.');
        const doc = await PDFDocument.load(await files[0].arrayBuffer(), { ignoreEncryption: true });
        await Promise.resolve(doc.encrypt({ userPassword: password, ownerPassword: password }));
        out.push({ name: replaceExt(files[0].name, 'pdf').replace(/\.pdf$/, '-protected.pdf'), blob: new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }) });
      } else if (mode === 'sign') {
        setStatus('Placing your signature...');
        const c = sigCanvasRef.current;
        if (!c || !hasSignature) throw new Error('Please draw your signature first.');
        const doc = await PDFDocument.load(await files[0].arrayBuffer(), { ignoreEncryption: true });
        const pngBlob = await canvasToBlob(c, 'image/png');
        const png = await doc.embedPng(await pngBlob.arrayBuffer());
        const pageIdx = Math.min(Math.max(1, signPage), doc.getPageCount()) - 1;
        const page = doc.getPage(pageIdx);
        const w = 160;
        const h = (c.height / c.width) * w;
        const margin = 36;
        const x = signPos.includes('right') ? page.getWidth() - w - margin : margin;
        const y = signPos.includes('bottom') ? margin : page.getHeight() - h - margin;
        page.drawImage(png, { x, y, width: w, height: h });
        out.push({ name: replaceExt(files[0].name, 'pdf').replace(/\.pdf$/, '-signed.pdf'), blob: new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }) });
      } else if (mode === 'img2pdf' || (mode === 'convert' && convertDir === 'to-pdf')) {
        setStatus('Building PDF from images...');
        const doc = await PDFDocument.create();
        const imgs = files.filter((f) => f.type.startsWith('image/'));
        if (imgs.length === 0) throw new Error('Please add at least one image.');
        for (let i = 0; i < imgs.length; i++) {
          const bytes = await imgs[i].arrayBuffer();
          const embedded = imgs[i].type === 'image/png' ? await doc.embedPng(bytes) : await doc.embedJpg(bytes);
          if (pageSize === 'a4') {
            const page = doc.addPage([595.28, 841.89]);
            const s = Math.min((595.28 - 48) / embedded.width, (841.89 - 48) / embedded.height);
            const w = embedded.width * s;
            const h = embedded.height * s;
            page.drawImage(embedded, { x: (595.28 - w) / 2, y: (841.89 - h) / 2, width: w, height: h });
          } else {
            const page = doc.addPage([embedded.width, embedded.height]);
            page.drawImage(embedded, { x: 0, y: 0, width: embedded.width, height: embedded.height });
          }
          setProgress((i + 1) / imgs.length);
        }
        out.push({ name: 'images.pdf', blob: new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }) });
      } else if (mode === 'convert' && convertDir === 'to-images') {
        setStatus('Rendering PDF pages to images...');
        const pdf = files.find((f) => f.type === 'application/pdf');
        if (!pdf) throw new Error('Please add a PDF file.');
        const pages = await renderPdfPages(pdf, 2, (d, t) => setProgress(d / t));
        const JSZip = (await import('jszip')).default;
        const zip = new JSZip();
        for (let i = 0; i < pages.length; i++) {
          const blob = await canvasToBlob(pages[i].canvas, 'image/png');
          zip.file(`page-${i + 1}.png`, blob);
        }
        out.push({ name: replaceExt(pdf.name, 'zip'), blob: await zip.generateAsync({ type: 'blob' }) });
      } else if (mode === 'edit') {
        setStatus('Applying edits...');
        const doc = await PDFDocument.load(await files[0].arrayBuffer(), { ignoreEncryption: true });
        const font = await doc.embedFont(StandardFonts.Helvetica);
        const pages = doc.getPages();
        pages.forEach((page, i) => {
          if (editText) {
            const y = editPos === 'header' ? page.getHeight() - 30 : 18;
            page.drawText(editText, { x: 36, y, size: 10, font, color: rgb(0.35, 0.35, 0.45) });
          }
          if (addPageNumbers) {
            const label = `${i + 1} / ${pages.length}`;
            page.drawText(label, { x: page.getWidth() - 60, y: 18, size: 10, font, color: rgb(0.35, 0.35, 0.45) });
          }
        });
        out.push({ name: replaceExt(files[0].name, 'pdf').replace(/\.pdf$/, '-edited.pdf'), blob: new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }) });
      } else {
        throw new Error(`Unknown PDF mode: ${mode}`);
      }

      setResults(out);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => { reset(); setFiles([]); setResults([]); setHasSignature(false); };

  if (phase === 'working') return <Processing label={status} progress={progress} />;
  if (phase === 'done') {
    const before = files.reduce((s, f) => s + f.size, 0);
    const after = results.reduce((s, f) => s + f.blob.size, 0);
    return <ResultView files={results} before={mode === 'compress' ? before : undefined} after={mode === 'compress' ? after : undefined} onReset={resetAll} />;
  }

  const cta: Record<string, string> = { merge: 'Merge Now', split: 'Split Now', compress: 'Compress Now', protect: 'Protect Now', sign: 'Sign Now', img2pdf: 'Convert Now', convert: 'Convert Now', edit: 'Apply Edits' };

  return (
    <div className="workspace-grid">
      <div>
        <FileDrop accept={tool.accept} multiple={tool.multiple || mode === 'merge'} files={files} onFiles={setFiles} />
      </div>
      <div className="options-panel">
        <h3>Options</h3>

        {mode === 'compress' && !targetKB && (
          <>
            <div className="field"><label>Quality <span className="range-value">{quality}%</span></label>
              <input type="range" min={20} max={95} value={quality} onChange={(e) => setQuality(+e.target.value)} /></div>
            <div className="field"><label>Resolution</label>
              <select value={dpiScale} onChange={(e) => setDpiScale(+e.target.value)}>
                <option value={1}>Standard (smaller file)</option>
                <option value={1.2}>Balanced</option>
                <option value={1.6}>High (larger file)</option>
              </select></div>
          </>
        )}
        {mode === 'compress' && targetKB > 0 && <p className="muted" style={{ fontSize: 13 }}>Optimized for UIDAI upload (~{targetKB}KB target).</p>}

        {mode === 'split' && (
          <>
            <div className="field"><label>Split mode</label>
              <select value={splitMode} onChange={(e) => setSplitMode(e.target.value as 'all' | 'range')}>
                <option value="all">Every page → separate PDF</option>
                <option value="range">Extract a page range</option>
              </select></div>
            {splitMode === 'range' && <div className="field"><label>Page range</label><input value={range} placeholder="e.g. 2-5" onChange={(e) => setRange(e.target.value)} /></div>}
          </>
        )}

        {mode === 'protect' && (
          <div className="field"><label>Password</label><input type="password" value={password} placeholder="Choose a strong password" onChange={(e) => setPassword(e.target.value)} /></div>
        )}

        {mode === 'sign' && (
          <>
            <div className="field">
              <label>Draw your signature</label>
              <canvas
                ref={sigCanvasRef}
                width={400}
                height={140}
                className="preview-canvas"
                style={{ background: '#fff', touchAction: 'none', cursor: 'crosshair', width: '100%' }}
                onPointerDown={(e) => sigDraw(e, 'down')}
                onPointerMove={(e) => sigDraw(e, 'move')}
                onPointerUp={(e) => sigDraw(e, 'up')}
              />
              <button className="btn btn-ghost btn-sm mt-2" onClick={() => { const c = sigCanvasRef.current; c?.getContext('2d')?.clearRect(0, 0, c.width, c.height); setHasSignature(false); }}>Clear</button>
            </div>
            <div className="field-row">
              <div className="field"><label>Page #</label><input type="number" min={1} value={signPage} onChange={(e) => setSignPage(+e.target.value)} /></div>
              <div className="field"><label>Position</label>
                <select value={signPos} onChange={(e) => setSignPos(e.target.value as typeof signPos)}>
                  <option value="bottom-right">Bottom right</option>
                  <option value="bottom-left">Bottom left</option>
                  <option value="top-right">Top right</option>
                  <option value="top-left">Top left</option>
                </select></div>
            </div>
          </>
        )}

        {(mode === 'img2pdf' || mode === 'convert') && (
          <>
            {mode === 'convert' && (
              <div className="field"><label>Direction</label>
                <select value={convertDir} onChange={(e) => setConvertDir(e.target.value as 'to-pdf' | 'to-images')}>
                  <option value="to-pdf">Images → PDF</option>
                  <option value="to-images">PDF → Images (ZIP)</option>
                </select></div>
            )}
            {(mode === 'img2pdf' || convertDir === 'to-pdf') && (
              <div className="field"><label>Page size</label>
                <select value={pageSize} onChange={(e) => setPageSize(e.target.value as 'a4' | 'fit')}>
                  <option value="a4">A4 (centered)</option>
                  <option value="fit">Fit to image</option>
                </select></div>
            )}
          </>
        )}

        {mode === 'edit' && (
          <>
            <div className="field"><label>Header/footer text (optional)</label><input value={editText} placeholder="e.g. Confidential — ToolNest" onChange={(e) => setEditText(e.target.value)} /></div>
            <div className="field"><label>Position</label>
              <select value={editPos} onChange={(e) => setEditPos(e.target.value as 'header' | 'footer')}>
                <option value="footer">Footer</option>
                <option value="header">Header</option>
              </select></div>
            <label className="checkbox-row"><input type="checkbox" checked={addPageNumbers} onChange={(e) => setAddPageNumbers(e.target.checked)} /> Add page numbers</label>
          </>
        )}

        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void run()}>{cta[mode] || 'Process Now'}</button>
      </div>
    </div>
  );
}
