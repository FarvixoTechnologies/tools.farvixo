'use client';

import React, { useCallback, useState } from 'react';
import dynamic from 'next/dynamic';
import Icon from '../Icon';
import { formatBytes } from '@/lib/download';
import UniversalDragDropUploader, { fileMatchesAccept as matchesAccept } from './UniversalDragDropUploader';

const ShareModal = dynamic(() => import('./ShareModal'), { ssr: false });

/* ─────────── Inline share button (secure URL + QR + Web Share) ─────────── */

export function ShareButton({ file, toolSlug }: { file: ResultFile; toolSlug?: string }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button className="btn btn-outline" onClick={() => setOpen(true)}>
        <Icon name="link" size={15} /> Share Link
      </button>
      {open && <ShareModal open={open} onClose={() => setOpen(false)} file={file} toolSlug={toolSlug} />}
    </>
  );
}

/* ─────────── Universal Upload Engine UI ─────────── */

export interface FileDropProps {
  accept?: string;
  multiple?: boolean;
  files: File[];
  onFiles: (files: File[]) => void;
  hint?: string;
}

// Single source of truth for accept matching + kind derivation lives with the
// universal uploader; re-exported here for existing importers.
export { fileMatchesAccept, acceptKind } from './UniversalDragDropUploader';

export function FileDrop({ accept, multiple, files, onFiles, hint }: FileDropProps) {
  const add = useCallback(
    (incoming: File[]) => {
      onFiles(multiple ? [...files, ...incoming] : incoming.slice(0, 1));
    },
    [files, multiple, onFiles],
  );

  return (
    <div>
      <UniversalDragDropUploader
        accept={accept}
        multiple={multiple}
        onFiles={add}
        note={hint}
      />
      <button
        className="btn btn-ghost btn-sm mt-2"
        onClick={async () => {
          try {
            const items = await navigator.clipboard.read();
            const picked: File[] = [];
            for (const item of items) {
              const type = item.types.find((t) => t.startsWith('image/') || t === 'application/pdf');
              if (!type) continue;
              const blob = await item.getType(type);
              const ext = type.split('/')[1]?.replace('jpeg', 'jpg') ?? 'png';
              picked.push(new File([blob], `pasted-${Date.now()}.${ext}`, { type }));
            }
            const ok = picked.filter((f) => matchesAccept(f, accept));
            if (ok.length === 0) return;
            add(ok);
          } catch {
            /* clipboard permission denied or no file content */
          }
        }}
      >
        <Icon name="copy" size={14} /> Paste from Clipboard
      </button>
      {files.length > 0 && (
        <div className="file-list">
          {files.map((f, i) => (
            <div key={`${f.name}-${i}`} className="file-item">
              <Icon name="file-text" size={16} />
              <span className="file-name">{f.name}</span>
              <span className="file-size">{formatBytes(f.size)}</span>
              <button className="file-remove" onClick={() => onFiles(files.filter((_, j) => j !== i))} aria-label={`Remove ${f.name}`}>
                <Icon name="x" size={14} />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ─────────── Processing / Result / Error views ─────────── */

export function Processing({ label, progress }: { label?: string; progress?: number }) {
  return (
    <div className="processing-box">
      <div className="spinner" />
      <b>{label || 'Processing your file...'}</b>
      <div className="progress-track">
        <div
          className={`progress-fill ${progress === undefined ? 'indeterminate' : ''}`}
          style={{ width: progress === undefined ? undefined : `${Math.round(progress * 100)}%` }}
        />
      </div>
      {progress !== undefined && <span className="muted mono">{Math.round(progress * 100)}%</span>}
    </div>
  );
}

export function ErrorBox({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="error-box">
      ⚠️ {message}
      {onRetry && (
        <div className="mt-2">
          <button className="btn btn-ghost btn-sm" onClick={onRetry}>Try Again</button>
        </div>
      )}
    </div>
  );
}

export interface ResultFile {
  name: string;
  blob: Blob;
}

export function ResultView({
  files,
  before,
  after,
  previewUrl,
  onReset,
  children,
}: {
  files: ResultFile[];
  before?: number;
  after?: number;
  previewUrl?: string;
  onReset: () => void;
  children?: React.ReactNode;
}) {
  const download = (f: ResultFile) => {
    const url = URL.createObjectURL(f.blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = f.name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 30_000);
  };

  return (
    <div className="result-box">
      <span className="result-badge"><Icon name="check-circle" size={16} /> Done! Your file is ready</span>
      {before !== undefined && after !== undefined && (
        <span className="size-compare">
          {formatBytes(before)} → <b>{formatBytes(after)}</b>{' '}
          {before > after && `(−${Math.round((1 - after / before) * 100)}%)`}
        </span>
      )}
      {previewUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={previewUrl} alt="Result preview" className="result-preview" />
      )}
      {children}
      <div className="result-actions">
        {files.map((f) => (
          <button key={f.name} className="btn btn-primary" onClick={() => download(f)}>
            <Icon name="download" size={16} /> Download {files.length > 1 ? f.name : ''}
          </button>
        ))}
        {files.length > 0 && <ShareButton file={files[0]} />}
        <button className="btn btn-ghost" onClick={onReset}><Icon name="refresh" size={15} /> Process Another File</button>
      </div>
    </div>
  );
}

/* ─────────── Copyable output block ─────────── */

export function OutputBlock({ text, filename }: { text: string; filename?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="w-full">
      <div className="output-area">{text}</div>
      <div className="mt-2" style={{ display: 'flex', gap: 10 }}>
        <button
          className="btn btn-ghost btn-sm"
          onClick={() => {
            void navigator.clipboard.writeText(text);
            setCopied(true);
            setTimeout(() => setCopied(false), 1500);
          }}
        >
          <Icon name="copy" size={14} /> {copied ? 'Copied!' : 'Copy'}
        </button>
        {filename && (
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => {
              const a = document.createElement('a');
              a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
              a.download = filename;
              a.click();
            }}
          >
            <Icon name="download" size={14} /> Download
          </button>
        )}
      </div>
    </div>
  );
}

/* ─────────── Simple state machine hook ─────────── */

export type ToolPhase = 'idle' | 'working' | 'done' | 'error';

export function useToolPhase() {
  const [phase, setPhase] = useState<ToolPhase>('idle');
  const [error, setError] = useState('');
  const [progress, setProgress] = useState<number | undefined>(undefined);
  const fail = (e: unknown) => {
    setError(e instanceof Error ? e.message : String(e));
    setPhase('error');
  };
  const reset = () => { setPhase('idle'); setError(''); setProgress(undefined); };
  return { phase, setPhase, error, fail, reset, progress, setProgress };
}
