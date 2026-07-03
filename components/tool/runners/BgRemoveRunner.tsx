'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, Processing, ErrorBox, ResultView, useToolPhase, type ResultFile } from '../shared';
import { loadImage, makeCanvas, canvasToBlob } from '@/lib/image';
import { replaceExt } from '@/lib/download';

type ImglyModule = { removeBackground: (src: Blob, cfg?: Record<string, unknown>) => Promise<Blob> };

let imglyPromise: Promise<ImglyModule> | null = null;
function loadImgly(): Promise<ImglyModule> {
  if (!imglyPromise) {
    // Load the AI model library from CDN at runtime (bypasses the bundler on purpose)
    const dynamicImport = new Function('u', 'return import(u)') as (u: string) => Promise<ImglyModule>;
    imglyPromise = dynamicImport('https://cdn.jsdelivr.net/npm/@imgly/background-removal@1.5.5/+esm');
  }
  return imglyPromise;
}

/** Simple diffusion inpainting: fills masked pixels from surrounding pixels. */
function inpaint(canvas: HTMLCanvasElement, mask: Uint8Array, iterations = 60): void {
  const ctx = canvas.getContext('2d')!;
  const { width: w, height: h } = canvas;
  const img = ctx.getImageData(0, 0, w, h);
  const d = img.data;
  const masked: number[] = [];
  for (let i = 0; i < mask.length; i++) if (mask[i]) masked.push(i);
  for (let it = 0; it < iterations; it++) {
    for (const idx of masked) {
      const x = idx % w;
      const y = (idx / w) | 0;
      let r = 0;
      let g = 0;
      let b = 0;
      let n = 0;
      for (let dy = -1; dy <= 1; dy++) {
        for (let dx = -1; dx <= 1; dx++) {
          if (!dx && !dy) continue;
          const nx = x + dx;
          const ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          const ni = ny * w + nx;
          if (it === 0 && mask[ni]) continue; // first pass: only take from clean pixels
          r += d[ni * 4];
          g += d[ni * 4 + 1];
          b += d[ni * 4 + 2];
          n++;
        }
      }
      if (n > 0) {
        d[idx * 4] = r / n;
        d[idx * 4 + 1] = g / n;
        d[idx * 4 + 2] = b / n;
        d[idx * 4 + 3] = 255;
      }
    }
  }
  ctx.putImageData(img, 0, 0);
}

export default function BgRemoveRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [files, setFiles] = useState<File[]>([]);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [preview, setPreview] = useState('');
  const [status, setStatus] = useState('Processing...');

  const [bgKind, setBgKind] = useState<'color' | 'image'>('color');
  const [bgColor, setBgColor] = useState('#7c3aed');
  const [bgFile, setBgFile] = useState<File[]>([]);
  const [brushSize, setBrushSize] = useState(28);

  // brush mask (object remover)
  const brushCanvasRef = useRef<HTMLCanvasElement>(null);
  const maskCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const [img, setImg] = useState<HTMLImageElement | null>(null);
  const painting = useRef(false);

  const mode = tool.mode; // remove | change | object

  useEffect(() => {
    if (files[0] && mode === 'object') void loadImage(files[0]).then(setImg);
  }, [files, mode]);

  useEffect(() => {
    const canvas = brushCanvasRef.current;
    if (!canvas || !img) return;
    const maxW = 640;
    const scale = Math.min(1, maxW / img.width);
    canvas.width = img.width * scale;
    canvas.height = img.height * scale;
    canvas.getContext('2d')!.drawImage(img, 0, 0, canvas.width, canvas.height);
    const m = document.createElement('canvas');
    m.width = canvas.width;
    m.height = canvas.height;
    maskCanvasRef.current = m;
  }, [img]);

  const paint = (e: React.PointerEvent<HTMLCanvasElement>, kind: 'down' | 'move' | 'up') => {
    const canvas = brushCanvasRef.current;
    const m = maskCanvasRef.current;
    if (!canvas || !m) return;
    if (kind === 'down') { painting.current = true; canvas.setPointerCapture(e.pointerId); }
    if (kind === 'up') { painting.current = false; return; }
    if (!painting.current) return;
    const rect = canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * canvas.width;
    const y = ((e.clientY - rect.top) / rect.height) * canvas.height;
    const mctx = m.getContext('2d')!;
    mctx.fillStyle = '#fff';
    mctx.beginPath();
    mctx.arc(x, y, brushSize / 2, 0, Math.PI * 2);
    mctx.fill();
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = 'rgba(239,68,68,0.45)';
    ctx.beginPath();
    ctx.arc(x, y, brushSize / 2, 0, Math.PI * 2);
    ctx.fill();
  };

  const run = async () => {
    if (files.length === 0) return;
    setPhase('working');
    try {
      const file = files[0];
      let blob: Blob;

      if (mode === 'object') {
        if (!img || !maskCanvasRef.current) throw new Error('Please brush over the area to remove first.');
        setStatus('Removing selected area...');
        const scale = img.width / maskCanvasRef.current.width;
        const [c, ctx] = makeCanvas(img.width, img.height);
        ctx.drawImage(img, 0, 0);
        // upscale mask to full resolution
        const [mc, mctx] = makeCanvas(img.width, img.height);
        mctx.drawImage(maskCanvasRef.current, 0, 0, img.width, img.height);
        const md = mctx.getImageData(0, 0, img.width, img.height).data;
        const mask = new Uint8Array(img.width * img.height);
        let any = false;
        for (let i = 0; i < mask.length; i++) {
          if (md[i * 4 + 3] > 10) { mask[i] = 1; any = true; }
        }
        void mc; void scale;
        if (!any) throw new Error('Please brush over the watermark/object you want to remove first.');
        inpaint(c, mask);
        blob = await canvasToBlob(c, 'image/jpeg', 0.94);
      } else {
        setStatus('Loading AI model (first run downloads ~40MB, then cached)...');
        const imgly = await loadImgly();
        setStatus('Removing background with AI...');
        const cut = await imgly.removeBackground(file);
        if (mode === 'change') {
          setStatus('Compositing new background...');
          const fg = await loadImage(new File([cut], 'cut.png', { type: 'image/png' }));
          const [c, ctx] = makeCanvas(fg.width, fg.height);
          if (bgKind === 'image' && bgFile[0]) {
            const bg = await loadImage(bgFile[0]);
            const s = Math.max(c.width / bg.width, c.height / bg.height);
            ctx.drawImage(bg, (c.width - bg.width * s) / 2, (c.height - bg.height * s) / 2, bg.width * s, bg.height * s);
          } else {
            ctx.fillStyle = bgColor;
            ctx.fillRect(0, 0, c.width, c.height);
          }
          ctx.drawImage(fg, 0, 0);
          blob = await canvasToBlob(c, 'image/png');
        } else {
          blob = cut;
        }
      }

      const name = replaceExt(file.name, mode === 'object' ? 'jpg' : 'png');
      setResults([{ name, blob }]);
      setPreview(URL.createObjectURL(blob));
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => { reset(); setFiles([]); setResults([]); setPreview(''); setImg(null); };

  if (phase === 'working') return <Processing label={status} />;
  if (phase === 'done') return <ResultView files={results} previewUrl={preview} onReset={resetAll} />;

  return (
    <div className="workspace-grid">
      <div>
        <FileDrop accept={tool.accept} files={files} onFiles={setFiles} />
        {mode === 'object' && img && (
          <div className="mt-4">
            <canvas
              ref={brushCanvasRef}
              className="preview-canvas"
              style={{ touchAction: 'none', cursor: 'crosshair' }}
              onPointerDown={(e) => paint(e, 'down')}
              onPointerMove={(e) => paint(e, 'move')}
              onPointerUp={(e) => paint(e, 'up')}
            />
            <p className="muted mt-2" style={{ fontSize: 12 }}>Brush over the watermark/object you want removed.</p>
          </div>
        )}
      </div>
      <div className="options-panel">
        <h3>Options</h3>
        {mode === 'remove' && <p className="muted" style={{ fontSize: 13 }}>AI background removal runs fully in your browser. The first run downloads the model (~40MB); after that it&apos;s instant and 100% private.</p>}
        {mode === 'change' && (
          <>
            <div className="field">
              <label>New background</label>
              <select value={bgKind} onChange={(e) => setBgKind(e.target.value as 'color' | 'image')}>
                <option value="color">Solid color</option>
                <option value="image">Another image</option>
              </select>
            </div>
            {bgKind === 'color'
              ? <div className="field"><label>Background color</label><input type="color" value={bgColor} onChange={(e) => setBgColor(e.target.value)} /></div>
              : <div className="field"><label>Background image</label><FileDrop accept="image/*" files={bgFile} onFiles={setBgFile} hint="Choose the new background" /></div>}
          </>
        )}
        {mode === 'object' && (
          <div className="field">
            <label>Brush size <span className="range-value">{brushSize}px</span></label>
            <input type="range" min={8} max={80} value={brushSize} onChange={(e) => setBrushSize(+e.target.value)} />
          </div>
        )}
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void run()}>
          {mode === 'object' ? 'Remove Now' : mode === 'change' ? 'Change Background' : 'Remove Background'}
        </button>
      </div>
    </div>
  );
}
