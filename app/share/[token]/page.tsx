'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import Icon from '@/components/Icon';

export default function ShareLandingPage({ params }: { params: Promise<{ token: string }> }) {
  const [token, setToken] = useState('');
  const [meta, setMeta] = useState<{
    fileName: string;
    expiresAt: string;
    requiresPassword: boolean;
    downloads: number;
    maxDownloads: number | null;
  } | null>(null);
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    void params.then((p) => setToken(p.token));
  }, [params]);

  useEffect(() => {
    if (!token) return;
    setLoading(true);
    void fetch(`/api/share/${token}?meta=1`)
      .then(async (r) => {
        const json = (await r.json()) as { success: boolean; data?: typeof meta; error?: string };
        if (!json.success || !json.data) throw new Error(json.error || 'Link unavailable');
        setMeta(json.data);
      })
      .catch((e) => setError(e instanceof Error ? e.message : 'Link unavailable'))
      .finally(() => setLoading(false));
  }, [token]);

  const download = () => {
    const q = password ? `?password=${encodeURIComponent(password)}` : '';
    window.location.href = `/api/share/${token}${q}`;
  };

  if (loading) {
    return (
      <main className="share-landing">
        <div className="spinner" />
        <p className="muted">Loading share link…</p>
      </main>
    );
  }

  if (error || !meta) {
    return (
      <main className="share-landing">
        <Icon name="alert-circle" size={40} />
        <h1>Link unavailable</h1>
        <p className="muted">{error || 'This share link has expired or was removed.'}</p>
        <Link href="/" className="btn btn-primary mt-4">Go to ToolNest</Link>
      </main>
    );
  }

  return (
    <main className="share-landing glass">
      <span className="pill pill-pro">ToolNest Share</span>
      <h1>{meta.fileName}</h1>
      <p className="muted">
        Expires {new Date(meta.expiresAt).toLocaleString()}
        {meta.maxDownloads !== null && ` · ${meta.downloads}/${meta.maxDownloads} downloads`}
      </p>

      {meta.requiresPassword && (
        <div className="field mt-4">
          <label htmlFor="share-pwd">Password</label>
          <input
            id="share-pwd"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter share password"
            autoComplete="off"
          />
        </div>
      )}

      <button className="btn btn-primary w-full mt-4" onClick={download}>
        <Icon name="download" size={16} /> Download File
      </button>

      <p className="muted share-landing-trust mt-4">
        Secure download · Encrypted transfer · Powered by{' '}
        <Link href="/">ToolNest</Link>
      </p>
    </main>
  );
}
