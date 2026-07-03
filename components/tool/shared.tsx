'use client';

import React, { useCallback, useRef, useState } from 'react';
import Icon from '../Icon';
import { formatBytes } from '@/lib/download';

/* ─────────── Universal Upload Engine UI ─────────── */

export interface FileDropProps {
  accept?: string;
  multiple?: boolean;
  files: File[];
  onFiles: (files: File[]) => void;
  hint?: string;
}

export function FileDrop({ accept, multiple, files, onFiles, hint }: FileDropProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [drag, setDrag] = useState(false);

  const add = useCallback(
    (incoming: FileList | null) => {
      if (!incoming) return;
      const arr = Array.from(incoming);
      onFiles(multiple ? [...files, ...arr] : arr.slice(0, 1));
    },
    [files, multiple, onFiles],
  );

  return (
    <div>
      <div
        className={`dropzone ${drag ? 'drag-over' : ''}`}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
        onDragLeave={() => setDrag(false)}
        onDrop={(e) => { e.preventDefault(); setDrag(false); add(e.dataTransfer.files); }}
        role="button"
        tabIndex={0}
        aria-label="Upload files"
        onKeyDown={(e) => e.key === 'Enter' && inputRef.current?.click()}
      >
        <span className="dropzone-icon"><Icon name="upload" size={26} /></span>
        <b>Drag &amp; drop or click to browse</b>
        <span>{hint || `Supported: ${accept || 'all files'} · Processed 100% in your browser`}</span>
      </div>
      <input
        ref={inputRef}
        type="file"
        hidden
        accept={accept}
        multiple={multiple}
        onChange={(e) => { add(e.target.files); e.target.value = ''; }}
      />
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
