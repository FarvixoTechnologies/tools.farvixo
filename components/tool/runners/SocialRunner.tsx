'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { ErrorBox, FileDrop } from '../shared';
import { downloadDataUrl } from '@/lib/download';
import { loadImage } from '@/lib/image';
import Icon from '../../Icon';

function ytId(input: string): string {
  const m = input.match(/(?:youtu\.be\/|v=|shorts\/|embed\/)([\w-]{11})/) || input.match(/^([\w-]{11})$/);
  return m ? m[1] : '';
}

export default function SocialRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [error, setError] = useState('');

  /* yt-thumb */
  const [ytUrl, setYtUrl] = useState('');
  const [thumbs, setThumbs] = useState<{ label: string; url: string }[]>([]);

  /* ig-dp */
  const [igUser, setIgUser] = useState('');
  const [igResult, setIgResult] = useState('');
  const [busy, setBusy] = useState(false);

  /* thumbnail maker */
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [tTitle, setTTitle] = useState('MY AWESOME VIDEO');
  const [tSub, setTSub] = useState('Watch till the end!');
  const [tBg, setTBg] = useState('#7C3AED');
  const [tBg2, setTBg2] = useState('#C026D3');
  const [tTextColor, setTTextColor] = useState('#FFFFFF');
  const [tImg, setTImg] = useState<File[]>([]);
  const [bgImage, setBgImage] = useState<HTMLImageElement | null>(null);

  useEffect(() => {
    if (tImg[0]) void loadImage(tImg[0]).then(setBgImage);
    else setBgImage(null);
  }, [tImg]);

  useEffect(() => {
    if (mode !== 'thumb-maker') return;
    const c = canvasRef.current;
    if (!c) return;
    const ctx = c.getContext('2d')!;
    // background
    if (bgImage) {
      const s = Math.max(1280 / bgImage.width, 720 / bgImage.height);
      ctx.drawImage(bgImage, (1280 - bgImage.width * s) / 2, (720 - bgImage.height * s) / 2, bgImage.width * s, bgImage.height * s);
      const grad = ctx.createLinearGradient(0, 0, 0, 720);
      grad.addColorStop(0.4, 'rgba(0,0,0,0)');
      grad.addColorStop(1, 'rgba(0,0,0,0.75)');
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, 1280, 720);
    } else {
      const grad = ctx.createLinearGradient(0, 0, 1280, 720);
      grad.addColorStop(0, tBg);
      grad.addColorStop(1, tBg2);
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, 1280, 720);
      ctx.fillStyle = 'rgba(255,255,255,0.06)';
      for (let i = 0; i < 6; i++) {
        ctx.beginPath();
        ctx.arc(1100 + i * 20, 100 + i * 40, 180 - i * 22, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    // title
    ctx.textAlign = 'left';
    ctx.fillStyle = tTextColor;
    ctx.strokeStyle = 'rgba(0,0,0,0.55)';
    ctx.lineWidth = 10;
    ctx.font = '900 92px Arial, sans-serif';
    const words = tTitle.split(' ');
    const lines: string[] = [];
    let line = '';
    for (const w of words) {
      const attempt = line ? `${line} ${w}` : w;
      if (ctx.measureText(attempt).width > 1120 && line) { lines.push(line); line = w; } else line = attempt;
    }
    if (line) lines.push(line);
    let y = 720 - 140 - (lines.length - 1) * 100;
    for (const l of lines) {
      ctx.strokeText(l, 70, y);
      ctx.fillText(l, 70, y);
      y += 100;
    }
    // subtitle badge
    if (tSub) {
      ctx.font = 'bold 38px Arial, sans-serif';
      const w = ctx.measureText(tSub).width + 48;
      ctx.fillStyle = '#F5B93D';
      ctx.beginPath();
      ctx.roundRect(70, 70, w, 64, 14);
      ctx.fill();
      ctx.fillStyle = '#1a1200';
      ctx.fillText(tSub, 94, 114);
    }
  }, [mode, tTitle, tSub, tBg, tBg2, tTextColor, bgImage]);

  const getThumbs = () => {
    setError('');
    const id = ytId(ytUrl.trim());
    if (!id) { setError('Could not find a video ID in that URL.'); return; }
    setThumbs([
      { label: 'Max resolution (1280×720)', url: `https://img.youtube.com/vi/${id}/maxresdefault.jpg` },
      { label: 'HQ (480×360)', url: `https://img.youtube.com/vi/${id}/hqdefault.jpg` },
      { label: 'Medium (320×180)', url: `https://img.youtube.com/vi/${id}/mqdefault.jpg` },
      { label: 'SD (640×480)', url: `https://img.youtube.com/vi/${id}/sddefault.jpg` },
    ]);
  };

  const getIgDp = async () => {
    setError('');
    setIgResult('');
    const u = igUser.trim().replace(/^@/, '');
    if (!u) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/social/instagram?user=${encodeURIComponent(u)}`);
      const json = await res.json();
      if (!json.success) throw new Error(json.error || 'Could not fetch profile.');
      setIgResult(json.data.url as string);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  if (mode === 'yt-thumb') {
    return (
      <div className="workspace-grid">
        <div className="options-panel">
          <div className="field"><label>YouTube video URL</label>
            <input value={ytUrl} placeholder="https://www.youtube.com/watch?v=..." onChange={(e) => setYtUrl(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && getThumbs()} /></div>
          {error && <ErrorBox message={error} />}
          <button className="btn btn-primary" onClick={getThumbs}><Icon name="download" size={15} /> Get Thumbnails</button>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {thumbs.map((t) => (
            <div key={t.url} className="glass" style={{ padding: 14 }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={t.url} alt={t.label} style={{ width: '100%', borderRadius: 8 }} />
              <div className="mt-2" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="muted" style={{ fontSize: 13 }}>{t.label}</span>
                <a className="btn btn-ghost btn-sm" href={t.url} target="_blank" rel="noreferrer" download>Open / Save</a>
              </div>
            </div>
          ))}
          {thumbs.length === 0 && <div className="output-area" style={{ minHeight: 180, color: 'var(--text-muted)' }}>Thumbnails will appear here.</div>}
        </div>
      </div>
    );
  }

  if (mode === 'ig-dp') {
    return (
      <div className="workspace-grid">
        <div className="options-panel">
          <div className="field"><label>Instagram username</label>
            <input value={igUser} placeholder="@username" onChange={(e) => setIgUser(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && void getIgDp()} /></div>
          {error && <ErrorBox message={error} />}
          <button className="btn btn-primary" disabled={busy} onClick={() => void getIgDp()}>{busy ? 'Fetching...' : 'Get Profile Photo'}</button>
          <p className="muted" style={{ fontSize: 12 }}>Works for public profiles only. Instagram sometimes blocks automated requests — try again if it fails.</p>
        </div>
        <div>
          {igResult ? (
            <div className="result-box">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={igResult} alt="Profile" className="result-preview" style={{ borderRadius: '50%', maxWidth: 280 }} />
              <a className="btn btn-primary" href={igResult} target="_blank" rel="noreferrer">Open Full Size</a>
            </div>
          ) : <div className="output-area" style={{ minHeight: 200, color: 'var(--text-muted)' }}>Profile photo will appear here.</div>}
        </div>
      </div>
    );
  }

  // thumb-maker
  return (
    <div className="workspace-grid">
      <div>
        <canvas ref={canvasRef} width={1280} height={720} className="preview-canvas w-full" />
      </div>
      <div className="options-panel">
        <h3>Design</h3>
        <div className="field"><label>Title</label><input value={tTitle} onChange={(e) => setTTitle(e.target.value)} /></div>
        <div className="field"><label>Badge text</label><input value={tSub} onChange={(e) => setTSub(e.target.value)} /></div>
        <div className="field-row">
          <div className="field"><label>Color 1</label><input type="color" value={tBg} onChange={(e) => setTBg(e.target.value)} /></div>
          <div className="field"><label>Color 2</label><input type="color" value={tBg2} onChange={(e) => setTBg2(e.target.value)} /></div>
          <div className="field"><label>Text</label><input type="color" value={tTextColor} onChange={(e) => setTTextColor(e.target.value)} /></div>
        </div>
        <div className="field"><label>Background photo (optional)</label>
          <FileDrop accept="image/*" files={tImg} onFiles={setTImg} hint="Add a background image" /></div>
        <button className="btn btn-primary" onClick={() => canvasRef.current && downloadDataUrl(canvasRef.current.toDataURL('image/png'), 'youtube-thumbnail.png')}>
          <Icon name="download" size={15} /> Download 1280×720 PNG
        </button>
      </div>
    </div>
  );
}
