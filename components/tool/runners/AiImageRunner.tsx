'use client';

import { useState } from 'react';
import { ErrorBox, Processing, ShareButton, useToolPhase } from '../shared';
import { aiImage } from '@/lib/ai';
import { downloadDataUrl } from '@/lib/download';
import Icon from '../../Icon';

const sizes = [
  { label: 'Square (1024×1024)', w: 1024, h: 1024 },
  { label: 'Landscape (1280×720)', w: 1280, h: 720 },
  { label: 'Portrait (720×1280)', w: 720, h: 1280 },
  { label: 'Widescreen (1920×1080)', w: 1920, h: 1080 },
];

const styles = ['None', 'Photorealistic', 'Digital art', 'Anime', '3D render', 'Watercolor', 'Cyberpunk', 'Minimalist logo'];

export default function AiImageRunner() {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [prompt, setPrompt] = useState('');
  const [sizeIdx, setSizeIdx] = useState(0);
  const [style, setStyle] = useState('None');
  const [imgUrl, setImgUrl] = useState('');
  const [imgBlob, setImgBlob] = useState<Blob | null>(null);

  const run = async () => {
    if (!prompt.trim()) return;
    setPhase('working');
    try {
      const full = style === 'None' ? prompt : `${prompt}, ${style.toLowerCase()} style, high quality`;
      const url = await aiImage(full, sizes[sizeIdx].w, sizes[sizeIdx].h);
      setImgUrl(url);
      const blob = await fetch(url).then((r) => r.blob());
      setImgBlob(blob);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        <div className="field">
          <label>Describe your image</label>
          <textarea value={prompt} placeholder="e.g. A glowing violet hexagon floating in deep space, cinematic lighting" onChange={(e) => setPrompt(e.target.value)} />
        </div>
        <div className="field"><label>Size</label>
          <select value={sizeIdx} onChange={(e) => setSizeIdx(+e.target.value)}>
            {sizes.map((s, i) => <option key={s.label} value={i}>{s.label}</option>)}
          </select></div>
        <div className="field"><label>Style</label>
          <select value={style} onChange={(e) => setStyle(e.target.value)}>
            {styles.map((s) => <option key={s} value={s}>{s}</option>)}
          </select></div>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={!prompt.trim() || phase === 'working'} onClick={() => void run()}>
          <Icon name="sparkles" size={15} /> {phase === 'working' ? 'Creating...' : 'Generate Image'}
        </button>
        <p className="muted" style={{ fontSize: 12 }}>Free AI image generation. Each generation uses a random seed — regenerate for variations.</p>
      </div>
      <div>
        {phase === 'working' && <Processing label="Painting your image with AI..." />}
        {imgUrl && phase === 'done' && (
          <div className="result-box" style={{ padding: 0 }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={imgUrl} alt={prompt} className="result-preview" style={{ maxHeight: 460 }} />
            <div className="result-actions">
              <button className="btn btn-primary" onClick={() => downloadDataUrl(imgUrl, 'toolnest-ai-image.png')}><Icon name="download" size={15} /> Download</button>
              {imgBlob && <ShareButton file={{ name: 'toolnest-ai-image.png', blob: imgBlob }} toolSlug="ai-image-generator" />}
              <button className="btn btn-ghost" onClick={() => void run()}><Icon name="refresh" size={15} /> Regenerate</button>
            </div>
          </div>
        )}
        {phase === 'idle' && <div className="output-area" style={{ minHeight: 300, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)' }}>Your generated image will appear here ✨</div>}
      </div>
    </div>
  );
}
