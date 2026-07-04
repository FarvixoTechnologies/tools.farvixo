'use client';

import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import Icon from '../Icon';
import { useUI } from '../GlobalUI';

interface ShareFile {
  name: string;
  blob: Blob;
}

interface ShareInfo {
  url: string;
  expiresAt: string;
}

const EXPIRY_OPTIONS = [
  { hours: 1, label: '1 Hour' },
  { hours: 24, label: '24 Hours' },
  { hours: 168, label: '7 Days' },
  { hours: 720, label: '30 Days' },
];

/**
 * Floating action rail + Share Link modal for processed files.
 * Rendered on every tool result view via <ResultView />.
 */
export default function ShareFab({ file }: { file: ShareFile }) {
  const { toast } = useUI();
  const [open, setOpen] = useState(false);
  const [share, setShare] = useState<ShareInfo | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState('');
  const [expiresIn, setExpiresIn] = useState(24);
  const [oneTime, setOneTime] = useState(false);
  const [creating, setCreating] = useState(false);
  const [copied, setCopied] = useState(false);
  const urlInputRef = useRef<HTMLInputElement>(null);

  // New file → previous link no longer matches; reset.
  useEffect(() => {
    setShare(null);
    setQrDataUrl('');
  }, [file]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open]);

  const createShare = async (): Promise<ShareInfo | null> => {
    if (share) return share;
    if (file.blob.size > 25 * 1024 * 1024) {
      toast('Share links support files up to 25MB', 'error');
      return null;
    }
    setCreating(true);
    try {
      const form = new FormData();
      form.append('file', new File([file.blob], file.name, { type: file.blob.type }));
      form.append('expiresInHours', String(expiresIn));
      form.append('oneTime', String(oneTime));
      const res = await fetch('/api/share', { method: 'POST', body: form });
      const json = (await res.json()) as { success: boolean; data?: ShareInfo; error?: string };
      if (!json.success || !json.data) throw new Error(json.error || 'Could not create share link');
      setShare(json.data);
      const QRCode = (await import('qrcode')).default;
      setQrDataUrl(await QRCode.toDataURL(json.data.url, { width: 480, margin: 2 }));
      return json.data;
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Could not create share link', 'error');
      return null;
    } finally {
      setCreating(false);
    }
  };

  const copyUrl = async (info?: ShareInfo | null) => {
    const target = info ?? share;
    if (!target) return;
    await navigator.clipboard.writeText(target.url);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
    toast('Link copied to clipboard ✓');
  };

  const webShare = async () => {
    const info = await createShare();
    if (!info) return;
    if (navigator.share) {
      try {
        await navigator.share({ title: file.name, text: `Download ${file.name} from ToolNest`, url: info.url });
        return;
      } catch { /* user cancelled — fall through to copy */ }
    }
    await copyUrl(info);
  };

  const openSocial = (kind: 'whatsapp' | 'telegram' | 'email' | 'facebook' | 'x') => {
    if (!share) return;
    const url = encodeURIComponent(share.url);
    const text = encodeURIComponent(`Download ${file.name} from ToolNest`);
    const links: Record<typeof kind, string> = {
      whatsapp: `https://wa.me/?text=${text}%20${url}`,
      telegram: `https://t.me/share/url?url=${url}&text=${text}`,
      email: `mailto:?subject=${text}&body=${url}`,
      facebook: `https://www.facebook.com/sharer/sharer.php?u=${url}`,
      x: `https://twitter.com/intent/tweet?text=${text}&url=${url}`,
    };
    window.open(links[kind], '_blank', 'noopener');
  };

  const downloadQr = () => {
    if (!qrDataUrl) return;
    const a = document.createElement('a');
    a.href = qrDataUrl;
    a.download = `${file.name}-share-qr.png`;
    a.click();
  };

  return (
    <>
      <div className="fab-rail" role="toolbar" aria-label="Share actions">
        <button className="fab-btn" onClick={() => setOpen(true)} aria-label="Share link" title="Share Link">
          <Icon name="link" size={20} />
        </button>
        <button
          className="fab-btn"
          onClick={async () => { const info = await createShare(); if (info) await copyUrl(info); }}
          disabled={creating}
          aria-label="Copy share link"
          title="Copy Link"
        >
          <Icon name="copy" size={20} />
        </button>
        <button className="fab-btn" onClick={() => void webShare()} disabled={creating} aria-label="Share" title="Share">
          <Icon name="share" size={20} />
        </button>
      </div>

      {open && createPortal(
        <div className="share-modal-overlay" onClick={() => setOpen(false)}>
          <div className="share-modal glass" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Copy and share download link">
            <button className="icon-btn share-modal-close" onClick={() => setOpen(false)} aria-label="Close">
              <Icon name="x" size={18} />
            </button>
            <h3>Copy &amp; Share Download Link</h3>
            <p className="muted share-modal-sub">Share your processed file instantly.</p>

            {!share ? (
              <>
                <div className="field">
                  <label>Expire after</label>
                  <select value={expiresIn} onChange={(e) => setExpiresIn(+e.target.value)}>
                    {EXPIRY_OPTIONS.map((o) => (
                      <option key={o.hours} value={o.hours}>{o.label}</option>
                    ))}
                  </select>
                </div>
                <label className="checkbox-row">
                  <input type="checkbox" checked={oneTime} onChange={(e) => setOneTime(e.target.checked)} />
                  One-time download (link stops working after first download)
                </label>
                <button className="btn btn-primary w-full mt-2" disabled={creating} onClick={() => void createShare()}>
                  <Icon name="link" size={15} /> {creating ? 'Generating…' : 'Generate Secure Link'}
                </button>
              </>
            ) : (
              <>
                <div className="share-url-row">
                  <input
                    ref={urlInputRef}
                    readOnly
                    value={share.url}
                    onFocus={(e) => e.target.select()}
                    aria-label="Share URL"
                  />
                  <button className="btn btn-primary btn-sm" onClick={() => void copyUrl()}>
                    <Icon name="copy" size={14} /> {copied ? 'Copied!' : 'Copy'}
                  </button>
                </div>
                <p className="muted share-expiry-note">
                  Expires {new Date(share.expiresAt).toLocaleString()}{oneTime ? ' · one-time download' : ''}
                </p>

                {qrDataUrl && (
                  <div className="share-qr">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={qrDataUrl} alt="QR code for download link" />
                    <p className="muted">Scan using your mobile to download instantly.</p>
                    <button className="btn btn-ghost btn-sm" onClick={downloadQr}>
                      <Icon name="download" size={14} /> Download QR
                    </button>
                  </div>
                )}

                <div className="share-social">
                  <button className="btn btn-ghost btn-sm" onClick={() => void webShare()}><Icon name="share" size={14} /> Share</button>
                  <button className="btn btn-ghost btn-sm" onClick={() => openSocial('whatsapp')}><Icon name="send" size={14} /> WhatsApp</button>
                  <button className="btn btn-ghost btn-sm" onClick={() => openSocial('telegram')}><Icon name="plane" size={14} /> Telegram</button>
                  <button className="btn btn-ghost btn-sm" onClick={() => openSocial('email')}><Icon name="mail" size={14} /> Email</button>
                  <button className="btn btn-ghost btn-sm" onClick={() => openSocial('facebook')}><Icon name="facebook" size={14} /> Facebook</button>
                  <button className="btn btn-ghost btn-sm" onClick={() => openSocial('x')}><Icon name="twitter" size={14} /> X</button>
                </div>
              </>
            )}
          </div>
        </div>,
        document.body,
      )}
    </>
  );
}
