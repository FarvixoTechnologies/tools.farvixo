'use client';

/**
 * UniversalDragDropUploader — THE one upload zone for every Farvixo tool.
 * Identical layout/animations/accessibility everywhere; only icon, accent,
 * accepted formats and texts change via props (config-driven, no redesigns).
 *
 * Real features: type validation (accept spec), size cap, folder drag & drop
 * (recursive), drag "Release to Upload" state, inline error cards, floating
 * particle backdrop (GPU-cheap, reduced-motion aware), keyboard + SR support.
 */

import { useCallback, useRef, useState } from 'react';
import Icon from '../Icon';

/** Does a file match an HTML accept string (.ext, type/*, exact mime)? */
export function fileMatchesAccept(file: File, accept?: string): boolean {
  if (!accept?.trim()) return true;
  const ext = `.${file.name.split('.').pop()?.toLowerCase() ?? ''}`;
  const mime = file.type.toLowerCase();
  return accept.split(',').some((raw) => {
    const t = raw.trim().toLowerCase();
    if (!t) return false;
    if (t.endsWith('/*')) return mime.startsWith(t.slice(0, -1));
    if (t.startsWith('.')) return ext === t;
    return mime === t;
  });
}

/** Human label + icon + accent for an accept string — "PDF", "Images", ... */
export function acceptKind(accept?: string): { label: string; icon: string; accent: string } {
  const a = (accept ?? '').toLowerCase();
  if (!a) return { label: 'Files', icon: 'upload', accent: 'var(--brand-primary)' };
  const kinds: string[] = [];
  if (a.includes('pdf')) kinds.push('PDF');
  if (a.includes('image')) kinds.push('Images');
  if (a.includes('video')) kinds.push('Video');
  if (a.includes('audio')) kinds.push('Audio');
  if (/\.docx?|\.xlsx?|\.csv|\.txt|\.md|\.html/.test(a)) kinds.push('Documents');
  const label = kinds.length ? kinds.join(' · ') : accept!.toUpperCase();
  const primary = kinds[0] ?? '';
  const icon =
    primary === 'PDF' ? 'file-text' :
    primary === 'Images' ? 'image' :
    primary === 'Video' ? 'video' :
    primary === 'Audio' ? 'music' : 'file-text';
  const accent =
    primary === 'PDF' ? 'var(--accent-pdf, #ef4444)' :
    primary === 'Images' ? 'var(--accent-image, #22c55e)' :
    primary === 'Video' ? 'var(--accent-video, #a855f7)' :
    primary === 'Audio' ? 'var(--accent-audio, #f97316)' :
    'var(--brand-primary)';
  return { label, icon, accent };
}

export interface UniversalDragDropUploaderProps {
  accept?: string;
  multiple?: boolean;
  /** Receives ONLY validated files. */
  onFiles: (files: File[]) => void;
  title?: string;
  note?: string;
  buttonLabel?: string;
  /** CSS color override; defaults to the accept-kind accent. */
  accent?: string;
  /** Reject files larger than this (MB). */
  maxSizeMB?: number;
  className?: string;
}

/** Recursively read files from a dropped folder (webkitGetAsEntry). */
async function readDropped(items: DataTransferItemList): Promise<File[]> {
  interface Entry {
    isFile: boolean;
    isDirectory: boolean;
    file: (cb: (f: File) => void, err?: () => void) => void;
    createReader: () => { readEntries: (cb: (es: Entry[]) => void, err?: () => void) => void };
  }
  const walk = async (entry: Entry): Promise<File[]> => {
    if (entry.isFile) {
      return new Promise((res) => entry.file((f) => res([f]), () => res([])));
    }
    if (entry.isDirectory) {
      const reader = entry.createReader();
      const out: File[] = [];
      // readEntries returns batches of ≤100 — loop until empty.
      for (;;) {
        const batch: Entry[] = await new Promise((res) => reader.readEntries((es) => res(es), () => res([])));
        if (!batch.length) break;
        for (const e of batch) out.push(...await walk(e));
      }
      return out;
    }
    return [];
  };

  const entries: Entry[] = [];
  for (let i = 0; i < items.length; i++) {
    const entry = (items[i] as unknown as { webkitGetAsEntry?: () => Entry | null }).webkitGetAsEntry?.();
    if (entry) entries.push(entry);
  }
  if (!entries.length) return [];
  const nested = await Promise.all(entries.map(walk));
  return nested.flat();
}

export default function UniversalDragDropUploader({
  accept,
  multiple,
  onFiles,
  title,
  note,
  buttonLabel,
  accent,
  maxSizeMB,
  className,
}: UniversalDragDropUploaderProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [drag, setDrag] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);
  const kind = acceptKind(accept);
  const color = accent ?? kind.accent;

  const ingest = useCallback((incoming: File[]) => {
    if (!incoming.length) return;
    const errs: string[] = [];
    const ok: File[] = [];
    for (const f of incoming) {
      if (!fileMatchesAccept(f, accept)) {
        errs.push(`${f.name} — ye tool sirf ${kind.label} leta hai`);
      } else if (maxSizeMB && f.size > maxSizeMB * 1024 * 1024) {
        errs.push(`${f.name} — max ${maxSizeMB}MB allowed`);
      } else {
        ok.push(f);
      }
    }
    setErrors(errs.slice(0, 2));
    if (errs.length) setTimeout(() => setErrors([]), 4500);
    if (ok.length) onFiles(multiple ? ok : ok.slice(0, 1));
  }, [accept, kind.label, maxSizeMB, multiple, onFiles]);

  const onDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault();
    setDrag(false);
    // Folder support: prefer entries traversal when a directory is present.
    const viaEntries = await readDropped(e.dataTransfer.items);
    ingest(viaEntries.length ? viaEntries : Array.from(e.dataTransfer.files));
  }, [ingest]);

  return (
    <div className={className}>
      <div
        className={`dropzone dz-hero ${drag ? 'drag-over' : ''} ${errors.length ? 'drop-rejected' : ''}`}
        style={{ '--dz-accent': color } as React.CSSProperties}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
        onDragLeave={(e) => { if (!e.currentTarget.contains(e.relatedTarget as Node)) setDrag(false); }}
        onDrop={(e) => void onDrop(e)}
        role="button"
        tabIndex={0}
        aria-label={`Upload ${kind.label}`}
        onKeyDown={(e) => e.key === 'Enter' && inputRef.current?.click()}
      >
        <span className="dz-particles" aria-hidden>
          {Array.from({ length: 8 }).map((_, i) => <i key={i} style={{ ['--i' as string]: i }} />)}
        </span>
        <span className="dz-icon"><Icon name={kind.icon} size={22} /></span>
        <b className="dz-title">
          {drag ? 'Release to Upload' : (title ?? `Drag & Drop ${kind.label} Here`)}
        </b>
        <span className="dz-sub">or click to browse files</span>
        <span className="btn btn-primary dz-btn">
          {buttonLabel ?? `Choose ${kind.label === 'Files' ? 'File' : `${kind.label.split(' · ')[0]} File${multiple ? 's' : ''}`}`}
        </span>
        <span className="dz-note">
          {note ?? `${kind.label}${multiple ? ' · multiple files · folders' : ''}${maxSizeMB ? ` · max ${maxSizeMB}MB` : ''} · 100% private — browser me hi process`}
        </span>
      </div>
      {errors.map((err) => (
        <p key={err} className="dropzone-error" role="alert">
          <Icon name="alert-triangle" size={13} /> {err}
        </p>
      ))}
      <input
        ref={inputRef}
        type="file"
        hidden
        accept={accept}
        multiple={multiple}
        onChange={(e) => { ingest(Array.from(e.target.files ?? [])); e.target.value = ''; }}
      />
    </div>
  );
}
