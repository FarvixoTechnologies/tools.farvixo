'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, Processing, ErrorBox, ResultView, useToolPhase, type ResultFile } from '../shared';
import { loadImage, makeCanvas, canvasToBlob, canvasToTargetSize, drawCover, sharpen, autoEnhance, extFromMime } from '@/lib/image';
import { replaceExt } from '@/lib/download';

interface Preset { label: string; w: number; h: number; kb: number }

export default function ImageRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [files, setFiles] = useState<File[]>([]);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [preview, setPreview] = useState('');
  const [sizes, setSizes] = useState<{ before: number; after: number } | undefined>();

  // Options
  const [format, setFormat] = useState('image/jpeg');
  const [quality, setQuality] = useState(80);
  const [width, setWidth] = useState('');
  const [height, setHeight] = useState('');
  const [keepAspect, setKeepAspect] = useState(true);
  const [angle, setAngle] = useState(90);
  const [flipH, setFlipH] = useState(false);
  const [flipV, setFlipV] = useState(false);
  const [scaleFactor, setScaleFactor] = useState(2);
  const [wmText, setWmText] = useState('© Farvixo');
  const [wmSize, setWmSize] = useState(36);
  const [wmOpacity, setWmOpacity] = useState(50);
  const [wmColor, setWmColor] = useState('#ffffff');
  const [presetIdx, setPresetIdx] = useState(0);

  // Crop state
  const cropCanvasRef = useRef<HTMLCanvasElement>(null);
  const [cropImg, setCropImg] = useState<HTMLImageElement | null>(null);
  const [cropBox, setCropBox] = useState({ x: 0.1, y: 0.1, w: 0.8, h: 0.8 });
  const dragRef = useRef<{ startX: number; startY: number; mode: 'move' | 'resize'; box: typeof cropBox } | null>(null);

  const presets: Preset[] = (tool.config?.presets as Preset[]) || [];
  const mode = tool.mode;
  const naturalDims = useRef({ w: 0, h: 0 });

  useEffect(() => {
    if (files[0] && (mode === 'crop' || mode === 'resize')) {
      void loadImage(files[0]).then((img) => {
        naturalDims.current = { w: img.width, h: img.height };
        if (mode === 'resize') { setWidth(String(img.width)); setHeight(String(img.height)); }
        if (mode === 'crop') setCropImg(img);
      });
    } else if (files[0] && mode !== 'crop') {
      setCropImg(null);
    }
  }, [files, mode]);

  // Crop canvas drawing
  useEffect(() => {
    const canvas = cropCanvasRef.current;
    if (!canvas || !cropImg || mode !== 'crop') return;
    const maxW = 640;
    const scale = Math.min(1, maxW / cropImg.width);
    canvas.width = cropImg.width * scale;
    canvas.height = cropImg.height * scale;
    const ctx = canvas.getContext('2d')!;
    ctx.drawImage(cropImg, 0, 0, canvas.width, canvas.height);
    ctx.fillStyle = 'rgba(0,0,0,0.55)';
    const bx = cropBox.x * canvas.width;
    const by = cropBox.y * canvas.height;
    const bw = cropBox.w * canvas.width;
    const bh = cropBox.h * canvas.height;
    ctx.fillRect(0, 0, canvas.width, by);
    ctx.fillRect(0, by + bh, canvas.width, canvas.height - by - bh);
    ctx.fillRect(0, by, bx, bh);
    ctx.fillRect(bx + bw, by, canvas.width - bx - bw, bh);
    ctx.strokeStyle = '#8570ff';
    ctx.lineWidth = 2;
    ctx.strokeRect(bx, by, bw, bh);
    ctx.fillStyle = '#8570ff';
    ctx.fillRect(bx + bw - 8, by + bh - 8, 8, 8);
  }, [cropImg, cropBox, mode]);

  const cropPointer = (e: React.PointerEvent<HTMLCanvasElement>, kind: 'down' | 'move' | 'up') => {
    const canvas = cropCanvasRef.current;
    if (!canvas || !cropImg) return;
    const rect = canvas.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width;
    const py = (e.clientY - rect.top) / rect.height;
    if (kind === 'down') {
      const nearCorner = Math.abs(px - (cropBox.x + cropBox.w)) < 0.05 && Math.abs(py - (cropBox.y + cropBox.h)) < 0.05;
      dragRef.current = { startX: px, startY: py, mode: nearCorner ? 'resize' : 'move', box: { ...cropBox } };
      canvas.setPointerCapture(e.pointerId);
    } else if (kind === 'move' && dragRef.current) {
      const d = dragRef.current;
      const dx = px - d.startX;
      const dy = py - d.startY;
      if (d.mode === 'move') {
        setCropBox({
          ...d.box,
          x: Math.min(Math.max(0, d.box.x + dx), 1 - d.box.w),
          y: Math.min(Math.max(0, d.box.y + dy), 1 - d.box.h),
        });
      } else {
        setCropBox({
          ...d.box,
          w: Math.min(Math.max(0.05, d.box.w + dx), 1 - d.box.x),
          h: Math.min(Math.max(0.05, d.box.h + dy), 1 - d.box.y),
        });
      }
    } else if (kind === 'up') {
      dragRef.current = null;
    }
  };

  const run = async () => {
    if (files.length === 0) return;
    setPhase('working');
    try {
      const out: ResultFile[] = [];
      let totalBefore = 0;
      let totalAfter = 0;
      for (const file of files) {
        const img = await loadImage(file);
        totalBefore += file.size;
        let blob: Blob;
        let name: string;

        if (mode === 'convert') {
          const [c, ctx] = makeCanvas(img.width, img.height);
          if (format === 'image/jpeg') { ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, c.width, c.height); }
          ctx.drawImage(img, 0, 0);
          blob = await canvasToBlob(c, format, quality / 100);
          name = replaceExt(file.name, extFromMime(format));
        } else if (mode === 'compress') {
          const [c, ctx] = makeCanvas(img.width, img.height);
          ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, c.width, c.height);
          ctx.drawImage(img, 0, 0);
          blob = await canvasToBlob(c, 'image/jpeg', quality / 100);
          name = replaceExt(file.name, 'jpg');
        } else if (mode === 'resize') {
          const w = parseInt(width) || img.width;
          const h = keepAspect ? Math.round((w / img.width) * img.height) : parseInt(height) || img.height;
          const [c, ctx] = makeCanvas(w, h);
          ctx.drawImage(img, 0, 0, w, h);
          blob = await canvasToBlob(c, file.type === 'image/png' ? 'image/png' : 'image/jpeg', 0.92);
          name = file.name;
        } else if (mode === 'crop') {
          const sx = cropBox.x * img.width;
          const sy = cropBox.y * img.height;
          const sw = cropBox.w * img.width;
          const sh = cropBox.h * img.height;
          const [c, ctx] = makeCanvas(sw, sh);
          ctx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
          blob = await canvasToBlob(c, 'image/png');
          name = replaceExt(file.name, 'png');
        } else if (mode === 'rotate') {
          const rad = (angle * Math.PI) / 180;
          const swap = angle % 180 !== 0;
          const [c, ctx] = makeCanvas(swap ? img.height : img.width, swap ? img.width : img.height);
          ctx.translate(c.width / 2, c.height / 2);
          ctx.rotate(rad);
          ctx.scale(flipH ? -1 : 1, flipV ? -1 : 1);
          ctx.drawImage(img, -img.width / 2, -img.height / 2);
          blob = await canvasToBlob(c, 'image/png');
          name = replaceExt(file.name, 'png');
        } else if (mode === 'upscale') {
          const [c, ctx] = makeCanvas(img.width * scaleFactor, img.height * scaleFactor);
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'high';
          ctx.drawImage(img, 0, 0, c.width, c.height);
          if (c.width * c.height <= 4096 * 4096) sharpen(c, 0.3);
          blob = await canvasToBlob(c, 'image/png');
          name = replaceExt(file.name, 'png');
        } else if (mode === 'enhance') {
          const [c, ctx] = makeCanvas(img.width, img.height);
          ctx.drawImage(img, 0, 0);
          autoEnhance(c);
          blob = await canvasToBlob(c, 'image/jpeg', 0.95);
          name = replaceExt(file.name, 'jpg');
        } else if (mode === 'watermark') {
          const [c, ctx] = makeCanvas(img.width, img.height);
          ctx.drawImage(img, 0, 0);
          ctx.globalAlpha = wmOpacity / 100;
          ctx.fillStyle = wmColor;
          ctx.font = `bold ${wmSize}px sans-serif`;
          ctx.textAlign = 'right';
          ctx.fillText(wmText, img.width - 24, img.height - 24);
          ctx.globalAlpha = 1;
          blob = await canvasToBlob(c, 'image/jpeg', 0.93);
          name = replaceExt(file.name, 'jpg');
        } else if (mode === 'gov-photo') {
          const p = presets[presetIdx] || presets[0];
          const c = drawCover(img, p.w, p.h);
          blob = await canvasToTargetSize(c, p.kb);
          name = replaceExt(file.name, 'jpg');
        } else {
          throw new Error(`Unknown mode: ${mode}`);
        }

        totalAfter += blob.size;
        out.push({ name, blob });
      }
      setResults(out);
      setSizes({ before: totalBefore, after: totalAfter });
      setPreview(URL.createObjectURL(out[0].blob));
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => { reset(); setFiles([]); setResults([]); setPreview(''); setSizes(undefined); };

  if (phase === 'working') return <Processing />;
  if (phase === 'done') return <ResultView files={results} before={sizes?.before} after={sizes?.after} previewUrl={preview} onReset={resetAll} />;

  const verb: Record<string, string> = { convert: 'Convert', compress: 'Compress', resize: 'Resize', crop: 'Crop', rotate: 'Apply', upscale: 'Upscale', enhance: 'Enhance', watermark: 'Add Watermark', 'gov-photo': 'Resize' };

  return (
    <div className="workspace-grid">
      <div>
        <FileDrop accept={tool.accept} multiple={tool.multiple} files={files} onFiles={setFiles} />
        {mode === 'crop' && cropImg && (
          <div className="mt-4">
            <canvas
              ref={cropCanvasRef}
              className="preview-canvas"
              style={{ touchAction: 'none', cursor: 'move' }}
              onPointerDown={(e) => cropPointer(e, 'down')}
              onPointerMove={(e) => cropPointer(e, 'move')}
              onPointerUp={(e) => cropPointer(e, 'up')}
            />
            <p className="muted mt-2" style={{ fontSize: 12 }}>Drag to move the crop area · drag the bottom-right corner to resize.</p>
          </div>
        )}
      </div>
      <div className="options-panel">
        <h3>Options</h3>

        {mode === 'convert' && (
          <div className="field">
            <label>Output format</label>
            <select value={format} onChange={(e) => setFormat(e.target.value)}>
              <option value="image/jpeg">JPG</option>
              <option value="image/png">PNG</option>
              <option value="image/webp">WebP</option>
              <option value="image/bmp">BMP</option>
            </select>
          </div>
        )}

        {(mode === 'convert' || mode === 'compress') && (
          <div className="field">
            <label>Quality <span className="range-value">{quality}%</span></label>
            <input type="range" min={10} max={100} value={quality} onChange={(e) => setQuality(+e.target.value)} />
          </div>
        )}

        {mode === 'resize' && (
          <>
            <div className="field-row">
              <div className="field"><label>Width (px)</label><input type="number" value={width} onChange={(e) => { setWidth(e.target.value); if (keepAspect && naturalDims.current.w) setHeight(String(Math.round((+e.target.value / naturalDims.current.w) * naturalDims.current.h))); }} /></div>
              <div className="field"><label>Height (px)</label><input type="number" value={height} disabled={keepAspect} onChange={(e) => setHeight(e.target.value)} /></div>
            </div>
            <label className="checkbox-row"><input type="checkbox" checked={keepAspect} onChange={(e) => setKeepAspect(e.target.checked)} /> Lock aspect ratio</label>
          </>
        )}

        {mode === 'rotate' && (
          <>
            <div className="field">
              <label>Rotate</label>
              <select value={angle} onChange={(e) => setAngle(+e.target.value)}>
                <option value={0}>0°</option>
                <option value={90}>90° clockwise</option>
                <option value={180}>180°</option>
                <option value={270}>90° counter-clockwise</option>
              </select>
            </div>
            <label className="checkbox-row"><input type="checkbox" checked={flipH} onChange={(e) => setFlipH(e.target.checked)} /> Flip horizontally</label>
            <label className="checkbox-row"><input type="checkbox" checked={flipV} onChange={(e) => setFlipV(e.target.checked)} /> Flip vertically</label>
          </>
        )}

        {mode === 'upscale' && (
          <div className="field">
            <label>Upscale factor</label>
            <select value={scaleFactor} onChange={(e) => setScaleFactor(+e.target.value)}>
              <option value={2}>2× (recommended)</option>
              <option value={3}>3×</option>
              <option value={4}>4×</option>
            </select>
          </div>
        )}

        {mode === 'watermark' && (
          <>
            <div className="field"><label>Watermark text</label><input value={wmText} onChange={(e) => setWmText(e.target.value)} /></div>
            <div className="field-row">
              <div className="field"><label>Size <span className="range-value">{wmSize}px</span></label><input type="range" min={12} max={120} value={wmSize} onChange={(e) => setWmSize(+e.target.value)} /></div>
              <div className="field"><label>Opacity <span className="range-value">{wmOpacity}%</span></label><input type="range" min={5} max={100} value={wmOpacity} onChange={(e) => setWmOpacity(+e.target.value)} /></div>
            </div>
            <div className="field"><label>Color</label><input type="color" value={wmColor} onChange={(e) => setWmColor(e.target.value)} /></div>
          </>
        )}

        {mode === 'gov-photo' && (
          <div className="field">
            <label>Preset</label>
            <select value={presetIdx} onChange={(e) => setPresetIdx(+e.target.value)}>
              {presets.map((p, i) => (<option key={i} value={i}>{p.label}</option>))}
            </select>
          </div>
        )}

        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void run()}>
          {verb[mode] || 'Process'} Now
        </button>
      </div>
    </div>
  );
}
