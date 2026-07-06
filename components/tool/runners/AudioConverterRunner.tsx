'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import type { Tool } from '@/data/tools';
import Icon from '@/components/Icon';
import UniversalDragDropUploader from '../UniversalDragDropUploader';
import { ErrorBox, ShareButton, useToolPhase, type ResultFile } from '../shared';
import { useUI } from '@/components/GlobalUI';
import { downloadBlob, formatBytes } from '@/lib/download';
import { recordJob } from '@/lib/jobs';
import {
  analyzeAudioFile,
  extractAudioFromZip,
  fetchAudioFromUrl,
  getAudioRecommendation,
  loadAudioSession,
  saveAudioSession,
  type AudioAnalysis,
} from '@/lib/engines/audio-analysis-engine';
import {
  convertAudio,
  generateAudioOutputName,
  mergeAndConvertAudio,
  type AudioConvertReport,
} from '@/lib/engines/audio-converter-engine';
import {
  AUDIO_ACCEPT,
  AUDIO_FORMATS,
  AUDIO_QUALITY_PRESETS,
  BITRATES,
  DEFAULT_AUDIO_SETTINGS,
  SAMPLE_RATES,
  applyAudioPreset,
  syncEditTimestamps,
  type AudioConvertSettings,
  type AudioPresetId,
} from '@/lib/engines/audio-presets';

const ShareModal = dynamic(() => import('../ShareModal'), { ssr: false });

const STEPS = ['Upload', 'Analyze', 'Convert', 'Download'] as const;

interface QueueItem {
  file: File;
  analysis?: AudioAnalysis;
  status: 'pending' | 'analyzing' | 'ready' | 'converting' | 'done' | 'error';
  error?: string;
}

function StepsBar({ current }: { current: number }) {
  return (
    <div className="pdfconv-steps ac-steps" aria-label="Audio conversion progress">
      {STEPS.map((s, i) => (
        <div key={s} className={`pdfconv-step ${i < current ? 'done' : ''} ${i === current ? 'active' : ''}`}>
          <span className="pdfconv-step-dot">{i < current ? <Icon name="check" size={12} /> : i + 1}</span>
          <span className="pdfconv-step-label">{s}</span>
          {i < STEPS.length - 1 && <span className="pdfconv-step-line" aria-hidden />}
        </div>
      ))}
    </div>
  );
}

function formatDuration(sec: number): string {
  if (!sec || !Number.isFinite(sec)) return '—';
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${String(s).padStart(2, '0')}`;
}

function Spectrum({ bands }: { bands: number[] }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !bands.length) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    const barW = w / bands.length;
    const accent = getComputedStyle(canvas).getPropertyValue('--accent-audio').trim() || '#F97316';
    bands.forEach((b, i) => {
      const bh = Math.max(2, b * (h - 4));
      const grad = ctx.createLinearGradient(0, h, 0, 0);
      grad.addColorStop(0, accent);
      grad.addColorStop(1, '#C026D3');
      ctx.fillStyle = grad;
      ctx.fillRect(i * barW + 1, h - bh, Math.max(1, barW - 2), bh);
    });
  }, [bands]);

  return (
    <canvas
      ref={canvasRef}
      className="ac-spectrum"
      width={480}
      height={72}
      role="img"
      aria-label="Frequency spectrum analyzer"
    />
  );
}

function TimelineWaveform({
  peaks,
  duration,
  trimStart,
  trimEnd,
  onTrimChange,
}: {
  peaks: number[];
  duration: number;
  trimStart: number;
  trimEnd: number;
  onTrimChange: (start: number, end: number) => void;
}) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [dragging, setDragging] = useState<'start' | 'end' | null>(null);
  const end = trimEnd > 0 ? trimEnd : duration;

  const pct = (sec: number) => (duration > 0 ? (sec / duration) * 100 : 0);

  const secFromEvent = (clientX: number) => {
    const rect = trackRef.current?.getBoundingClientRect();
    if (!rect || !duration) return 0;
    const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    return Math.round(ratio * duration * 10) / 10;
  };

  useEffect(() => {
    if (!dragging) return;
    const onMove = (e: MouseEvent) => {
      const sec = secFromEvent(e.clientX);
      if (dragging === 'start') {
        onTrimChange(Math.min(sec, end - 0.5), trimEnd);
      } else {
        onTrimChange(trimStart, Math.max(sec, trimStart + 0.5));
      }
    };
    const onUp = () => setDragging(null);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    };
  }, [dragging, trimStart, trimEnd, end, duration, onTrimChange]);

  return (
    <div className="ac-timeline" ref={trackRef}>
      <div className="ac-timeline-bars">
        {peaks.map((p, i) => (
          <span key={i} style={{ height: `${Math.max(4, p * 100)}%` }} />
        ))}
      </div>
      <div className="ac-timeline-dim" style={{ left: 0, width: `${pct(trimStart)}%` }} />
      <div className="ac-timeline-dim right" style={{ right: 0, width: `${100 - pct(end)}%` }} />
      <div className="ac-timeline-region" style={{ left: `${pct(trimStart)}%`, width: `${pct(end) - pct(trimStart)}%` }} />
      <button
        type="button"
        className="ac-timeline-handle start"
        style={{ left: `${pct(trimStart)}%` }}
        aria-label="Trim start"
        onMouseDown={() => setDragging('start')}
      />
      <button
        type="button"
        className="ac-timeline-handle end"
        style={{ left: `${pct(end)}%` }}
        aria-label="Trim end"
        onMouseDown={() => setDragging('end')}
      />
      <div className="ac-timeline-labels">
        <span>{formatDuration(trimStart)}</span>
        <span>{formatDuration(end)}</span>
      </div>
    </div>
  );
}

function Waveform({ peaks, active }: { peaks: number[]; active?: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !peaks.length) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    const barW = w / peaks.length;
    const accent = getComputedStyle(canvas).getPropertyValue('--accent-audio').trim() || '#F97316';
    ctx.fillStyle = active ? accent : 'rgba(249,115,22,0.55)';
    peaks.forEach((p, i) => {
      const bh = Math.max(2, p * (h - 8));
      ctx.fillRect(i * barW + 1, (h - bh) / 2, Math.max(1, barW - 2), bh);
    });
  }, [peaks, active]);

  return (
    <canvas
      ref={canvasRef}
      className="ac-waveform"
      width={480}
      height={64}
      role="img"
      aria-label="Audio waveform preview"
    />
  );
}

export default function AudioConverterRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset, progress, setProgress } = useToolPhase();
  const { toast, openAI } = useUI();
  const [step, setStep] = useState(0);
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [settings, setSettings] = useState<AudioConvertSettings>(DEFAULT_AUDIO_SETTINGS);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [reports, setReports] = useState<AudioConvertReport[]>([]);
  const [status, setStatus] = useState('');
  const [urlInput, setUrlInput] = useState('');
  const [previewUrl, setPreviewUrl] = useState('');
  const [activeAnalysis, setActiveAnalysis] = useState<AudioAnalysis | null>(null);
  const [activeIdx, setActiveIdx] = useState(0);
  const [shareOpen, setShareOpen] = useState(false);
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [metadataOpen, setMetadataOpen] = useState(false);
  const [coverArt, setCoverArt] = useState<File | null>(null);
  const [coverPreview, setCoverPreview] = useState('');
  const [recording, setRecording] = useState(false);
  const abortRef = useRef(false);
  const mediaRecRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const micRef = useRef<HTMLInputElement>(null);
  const zipRef = useRef<HTMLInputElement>(null);
  const coverRef = useRef<HTMLInputElement>(null);
  const history = loadAudioSession();

  const totalBefore = queue.reduce((s, q) => s + q.file.size, 0);
  const totalAfter = reports.reduce((s, r) => s + r.finalSize, 0);

  const patchSettings = (patch: Partial<AudioConvertSettings>) => {
    setSettings((s) => ({ ...s, ...patch }));
  };

  const addFiles = useCallback((incoming: File[]) => {
    setQueue((prev) => [
      ...prev,
      ...incoming.map((file) => ({ file, status: 'pending' as const })),
    ]);
    setStep(0);
    setPhase('idle');
    setResults([]);
    setReports([]);
    saveAudioSession(incoming.map((f) => f.name));
  }, [setPhase]);

  const addFilesWithZip = async (files: File[]) => {
    const audioFiles: File[] = [];
    for (const f of files) {
      if (f.type === 'application/zip' || f.name.endsWith('.zip')) {
        try {
          audioFiles.push(...await extractAudioFromZip(f));
        } catch {
          toast('Could not read ZIP', 'error');
        }
      } else {
        audioFiles.push(f);
      }
    }
    if (audioFiles.length) addFiles(audioFiles);
  };

  useEffect(() => {
    const onPaste = async (e: ClipboardEvent) => {
      if (step !== 0) return;
      const files: File[] = [];
      for (const item of e.clipboardData?.items ?? []) {
        if (item.kind === 'file' && item.type.startsWith('audio/')) {
          const f = item.getAsFile();
          if (f) files.push(f);
        }
      }
      if (files.length) {
        e.preventDefault();
        void addFilesWithZip(files);
      }
    };
    window.addEventListener('paste', onPaste);
    return () => window.removeEventListener('paste', onPaste);
  }, [step]);

  const analyzeAll = async () => {
    if (!queue.length) return;
    setPhase('working');
    setStatus('Analyzing audio with Web Audio API...');
    setStep(1);
    const updated = [...queue];

    for (let i = 0; i < updated.length; i++) {
      updated[i] = { ...updated[i], status: 'analyzing' };
      setQueue([...updated]);
      try {
        const analysis = await analyzeAudioFile(updated[i].file);
        updated[i] = { ...updated[i], analysis, status: 'ready' };
        if (i === 0) {
          setActiveAnalysis(analysis);
          setActiveIdx(0);
          const rec = getAudioRecommendation(analysis);
          patchSettings({
            preset: rec.preset,
            outputFormat: rec.format,
            bitrate: rec.bitrate,
            ...applyAudioPreset(rec.preset),
            metadata: {
              ...settings.metadata,
              title: settings.metadata.title || updated[i].file.name.replace(/\.[^.]+$/, ''),
            },
            edit: {
              ...settings.edit,
              trimStartSec: 0,
              trimEndSec: analysis.duration,
            },
          });
          setPreviewUrl(URL.createObjectURL(updated[i].file));
        }
      } catch (e) {
        updated[i] = {
          ...updated[i],
          status: 'error',
          error: e instanceof Error ? e.message : 'Analysis failed',
        };
      }
      setQueue([...updated]);
    }
    setPhase('idle');
  };

  const convertAll = async () => {
    if (!queue.length) return;
    setPhase('working');
    setStep(2);
    setStatus('Loading FFmpeg engine (first run ~30MB, cached after)...');
    abortRef.current = false;

    const updated = [...queue];
    const out: ResultFile[] = [];
    const reps: AudioConvertReport[] = [];
    const effectiveSettings = {
      ...settings,
      edit: activeAnalysis
        ? syncEditTimestamps(settings.edit, activeAnalysis.duration)
        : settings.edit,
    };

    if (settings.mergeQueue && queue.length > 1) {
      setStatus(`Merging ${queue.length} files and converting...`);
      try {
        const totalDuration = queue.reduce((s, q) => s + (q.analysis?.duration ?? 0), 0);
        const result = await mergeAndConvertAudio(
          queue.map((q) => q.file),
          effectiveSettings,
          setProgress,
          {
            duration: totalDuration,
            sampleRate: queue[0].analysis?.sampleRate ?? 44100,
            channels: queue[0].analysis?.channels ?? 2,
          },
          coverArt,
        );
        const name = settings.metadata.title
          ? `${settings.metadata.title.replace(/\s+/g, '-').toLowerCase()}.${result.format}`
          : `merged-audio.${result.format}`;
        out.push({ name, blob: result.blob });
        reps.push({
          fileName: `Merged (${queue.length} files)`,
          originalFormat: 'MIXED',
          outputFormat: result.format.toUpperCase(),
          originalSize: result.originalSize,
          finalSize: result.compressedSize,
          reductionPercent: result.reductionPercent,
          processingTimeMs: result.processingTimeMs,
          bitrate: settings.bitrate,
          sampleRate: result.sampleRate,
          channels: result.channels,
          duration: totalDuration,
          qualityScore: Math.round(queue.reduce((s, q) => s + (q.analysis?.qualityScore ?? 75), 0) / queue.length),
        });
        updated.forEach((_, i) => { updated[i] = { ...updated[i], status: 'done' }; });
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'Merge conversion failed';
        fail(new Error(msg.includes('SharedArrayBuffer') ? 'FFmpeg needs cross-origin isolation. Run via npm run dev or production build.' : msg));
        return;
      }
      setQueue([...updated]);
      setResults(out);
      setReports(reps);
      setStep(3);
      setPhase('done');
      recordJob(tool.slug, 'completed');
      return;
    }

    for (let i = 0; i < updated.length; i++) {
      if (abortRef.current) break;
      updated[i] = { ...updated[i], status: 'converting' };
      setQueue([...updated]);
      setStatus(`Converting ${i + 1}/${updated.length}: ${updated[i].file.name}`);

      try {
        const result = await convertAudio(
          updated[i].file,
          effectiveSettings,
          setProgress,
          updated[i].analysis,
          coverArt,
        );
        const name = generateAudioOutputName(updated[i].file.name, result.format);
        updated[i] = { ...updated[i], status: 'done' };
        out.push({ name, blob: result.blob });
        reps.push({
          fileName: updated[i].file.name,
          originalFormat: updated[i].analysis?.format ?? '—',
          outputFormat: result.format.toUpperCase(),
          originalSize: result.originalSize,
          finalSize: result.compressedSize,
          reductionPercent: result.reductionPercent,
          processingTimeMs: result.processingTimeMs,
          bitrate: settings.bitrate,
          sampleRate: result.sampleRate,
          channels: result.channels,
          duration: result.duration || updated[i].analysis?.duration || 0,
          qualityScore: updated[i].analysis?.qualityScore ?? 75,
        });
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'Conversion failed';
        const friendly = msg.includes('SharedArrayBuffer')
          ? 'FFmpeg needs cross-origin isolation. Run via npm run dev or production build.'
          : msg;
        updated[i] = { ...updated[i], status: 'error', error: friendly };
        fail(new Error(friendly));
        setQueue([...updated]);
        return;
      }
      setQueue([...updated]);
    }

    setResults(out);
    setReports(reps);
    setStep(3);
    setPhase('done');
    recordJob(tool.slug, 'completed');
  };

  const downloadAllZip = async () => {
    const JSZip = (await import('jszip')).default;
    const zip = new JSZip();
    for (const r of results) zip.file(r.name, r.blob);
    const blob = await zip.generateAsync({ type: 'blob' });
    downloadBlob(blob, 'converted-audio.zip');
  };

  const importUrl = async () => {
    if (!urlInput.trim()) return;
    try {
      setStatus('Fetching audio from URL...');
      const file = await fetchAudioFromUrl(urlInput.trim());
      addFiles([file]);
      setUrlInput('');
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Import failed', 'error');
    }
  };

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const rec = new MediaRecorder(stream);
      chunksRef.current = [];
      rec.ondataavailable = (e) => { if (e.data.size) chunksRef.current.push(e.data); };
      rec.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
        addFiles([new File([blob], `recording-${Date.now()}.webm`, { type: 'audio/webm' })]);
        setRecording(false);
      };
      mediaRecRef.current = rec;
      rec.start();
      setRecording(true);
      toast('Recording… click Stop when done', 'success');
    } catch {
      toast('Microphone access denied', 'error');
    }
  };

  const stopRecording = () => {
    mediaRecRef.current?.stop();
  };

  const resetAll = () => {
    reset();
    setQueue([]);
    setResults([]);
    setReports([]);
    setStep(0);
    setActiveAnalysis(null);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl('');
    if (coverPreview) URL.revokeObjectURL(coverPreview);
    setCoverPreview('');
    setCoverArt(null);
    setSettings(DEFAULT_AUDIO_SETTINGS);
  };

  const removeItem = (idx: number) => {
    setQueue((q) => q.filter((_, i) => i !== idx));
  };

  const selectQueueItem = (idx: number) => {
    const item = queue[idx];
    if (!item?.analysis) return;
    setActiveIdx(idx);
    setActiveAnalysis(item.analysis);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(URL.createObjectURL(item.file));
  };

  const applyPreset = (id: AudioPresetId) => {
    patchSettings({ preset: id, ...applyAudioPreset(id) });
  };

  if (phase === 'working') {
    return (
      <div className="ac-processing">
        <StepsBar current={step} />
        <div className="processing-box mt-4">
          <div className="spinner" />
          <b>{status || 'Processing...'}</b>
          <div className="progress-track">
            <div
              className={`progress-fill ${progress === undefined ? 'indeterminate' : ''}`}
              style={{ width: progress !== undefined ? `${Math.round(progress * 100)}%` : undefined }}
            />
          </div>
          {progress !== undefined && <span className="muted mono">{Math.round(progress * 100)}%</span>}
        </div>
        <button type="button" className="btn btn-ghost btn-sm mt-4" onClick={() => { abortRef.current = true; reset(); }}>
          Cancel
        </button>
      </div>
    );
  }

  if (phase === 'done' && step === 3) {
    return (
      <div className="ac-results">
        <StepsBar current={3} />
        <div className="ic-stats-bar mt-4">
          <div className="ic-stat">
            <span className="ic-stat-value">{formatBytes(totalBefore)}</span>
            <span className="ic-stat-label">Original</span>
          </div>
          <div className="ic-stat"><Icon name="arrow-right" size={20} /></div>
          <div className="ic-stat">
            <span className="ic-stat-value ic-stat-green">{formatBytes(totalAfter)}</span>
            <span className="ic-stat-label">Converted</span>
          </div>
          <div className="ic-stat">
            <span className="ic-stat-value ic-stat-green">
              {totalBefore > 0 ? `${totalAfter < totalBefore ? '-' : '+'}${Math.abs(Math.round((1 - totalAfter / totalBefore) * 100))}%` : '0%'}
            </span>
            <span className="ic-stat-label">Size change</span>
          </div>
        </div>

        {reports.length > 0 && (
          <div className="ac-report glass mt-4">
            <h3><Icon name="database" size={16} /> Audio Report</h3>
            <div className="ac-report-grid">
              {reports.map((r) => (
                <div key={r.fileName} className="ac-report-row">
                  <span className="ac-report-name">{r.fileName}</span>
                  <span>{r.originalFormat} → {r.outputFormat}</span>
                  <span>{formatBytes(r.originalSize)} → {formatBytes(r.finalSize)}</span>
                  <span className="muted">{r.bitrate} · {r.sampleRate}Hz · {r.channels}ch</span>
                  <span className="muted">{formatDuration(r.duration)} · {(r.processingTimeMs / 1000).toFixed(1)}s</span>
                  <span className="ic-stat-green">Score {r.qualityScore}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="ic-actions mt-4">
          {results.length === 1 && (
            <button type="button" className="btn btn-primary" onClick={() => downloadBlob(results[0].blob, results[0].name)}>
              <Icon name="download" size={16} /> Download ({formatBytes(results[0].blob.size)})
            </button>
          )}
          {results.length > 1 && (
            <button type="button" className="btn btn-primary" onClick={() => void downloadAllZip()}>
              <Icon name="download" size={16} /> Download All as ZIP
            </button>
          )}
          {results[0] && <ShareButton file={results[0]} toolSlug={tool.slug} />}
          <button type="button" className="btn btn-ghost" onClick={resetAll}>
            <Icon name="refresh" size={15} /> Convert More
          </button>
        </div>

        <div className="mergepdf-fab-rail" aria-label="Quick actions">
          <button type="button" className="mergepdf-fab mergepdf-fab-ai" title="AI Assistant" onClick={openAI}>
            <Icon name="sparkles" size={18} />
          </button>
          {results[0] && (
            <button type="button" className="mergepdf-fab" title="Share" onClick={() => setShareOpen(true)}>
              <Icon name="link" size={18} />
            </button>
          )}
        </div>
        {shareOpen && results[0] && (
          <ShareModal open={shareOpen} onClose={() => setShareOpen(false)} file={results[0]} toolSlug={tool.slug} />
        )}
      </div>
    );
  }

  return (
    <div className="ac-workspace pdfconv-layout">
      <StepsBar current={step} />

      <div className="ac-privacy-badge">
        <Icon name="shield" size={14} /> 100% browser processing with FFmpeg WASM — audio never leaves your device
      </div>

      <div className="workspace-grid">
        <div>
          <UniversalDragDropUploader
            accept={tool.accept ?? AUDIO_ACCEPT}
            multiple
            maxSizeMB={200}
            onFiles={(f) => void addFilesWithZip(f)}
            title="Drop audio files here"
            note="MP3, WAV, FLAC, AAC, OGG, OPUS, M4A & 15+ formats · Batch · ZIP · Best under ~100MB per file"
            accent="var(--accent-audio)"
          />

          <div className="ac-upload-actions mt-3">
            <button type="button" className="btn btn-outline btn-sm" onClick={() => recording ? stopRecording() : void startRecording()}>
              <Icon name="mic" size={15} /> {recording ? 'Stop Recording' : 'Record Mic'}
            </button>
            <button type="button" className="btn btn-outline btn-sm" onClick={() => zipRef.current?.click()}>
              <Icon name="folder" size={15} /> ZIP Upload
            </button>
            <button type="button" className="btn btn-outline btn-sm" onClick={() => micRef.current?.click()}>
              <Icon name="folder" size={15} /> Choose Files
            </button>
            <span className="muted ac-hint"><Icon name="copy" size={13} /> Ctrl+V to paste audio</span>
          </div>

          <div className="ac-url-row mt-3">
            <input
              type="url"
              placeholder="Import from URL (direct audio link)"
              value={urlInput}
              onChange={(e) => setUrlInput(e.target.value)}
              aria-label="Audio URL"
            />
            <button type="button" className="btn btn-ghost btn-sm" disabled={!urlInput.trim()} onClick={() => void importUrl()}>
              Import
            </button>
          </div>

          {history.length > 0 && (
            <p className="muted ac-history mt-2">
              <Icon name="clock" size={13} /> Recent: {history.slice(0, 4).join(', ')}
            </p>
          )}

          {previewUrl && (
            <div className="ac-preview mt-4 glass">
              {activeAnalysis && step >= 1 ? (
                <>
                  <TimelineWaveform
                    peaks={activeAnalysis.waveformPeaks}
                    duration={activeAnalysis.duration}
                    trimStart={settings.edit.trimStartSec}
                    trimEnd={settings.edit.trimEndSec || activeAnalysis.duration}
                    onTrimChange={(start, end) => {
                      patchSettings({
                        edit: {
                          ...settings.edit,
                          trimStartSec: start,
                          trimEndSec: end,
                        },
                      });
                    }}
                  />
                  {activeAnalysis.spectrumBands.length > 0 && (
                    <div className="ac-spectrum-wrap">
                      <span className="muted ac-spectrum-label"><Icon name="music" size={12} /> Spectrum</span>
                      <Spectrum bands={activeAnalysis.spectrumBands} />
                    </div>
                  )}
                </>
              ) : (
                activeAnalysis && <Waveform peaks={activeAnalysis.waveformPeaks} active />
              )}
              <audio src={previewUrl} controls className="ac-preview-audio" />
            </div>
          )}

          {queue.length > 0 && (
            <div className="ac-queue mt-4">
              <h4>Upload Queue ({queue.length})</h4>
              {queue.map((item, i) => (
                <div
                  key={`${item.file.name}-${i}`}
                  className={`ic-batch-item ${item.status} ${i === activeIdx ? 'active' : ''}`}
                  onClick={() => selectQueueItem(i)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && selectQueueItem(i)}
                >
                  <Icon name="music" size={14} />
                  <span className="ic-batch-name">{item.file.name}</span>
                  <span className="ic-batch-size">{formatBytes(item.file.size)}</span>
                  {item.analysis && (
                    <span className="muted">{formatDuration(item.analysis.duration)}</span>
                  )}
                  <span className={`ac-status-pill ${item.status}`}>{item.status}</span>
                  <button type="button" className="file-remove" onClick={(e) => { e.stopPropagation(); removeItem(i); }} aria-label="Remove">
                    <Icon name="x" size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}

          {activeAnalysis && step >= 1 && (
            <div className="ic-analysis glass mt-4">
              <h4><Icon name="sparkles" size={14} /> AI Smart Analysis</h4>
              <div className="ic-analysis-grid">
                <span>Format: <b>{activeAnalysis.format}</b></span>
                <span>Duration: <b>{formatDuration(activeAnalysis.duration)}</b></span>
                <span>Bitrate: <b>~{activeAnalysis.estimatedBitrateKbps} kbps</b></span>
                <span>Sample rate: <b>{activeAnalysis.sampleRate} Hz</b></span>
                <span>Channels: <b>{activeAnalysis.channels}</b></span>
                <span>Loudness: <b>{activeAnalysis.loudnessDb} dB</b></span>
                <span>Peak: <b>{activeAnalysis.peakDb} dB</b></span>
                <span>Silence: <b>{activeAnalysis.silencePercent}%</b></span>
                <span>Clipping: <b>{activeAnalysis.clippingPercent}%</b></span>
                <span>Noise: <b>{activeAnalysis.noiseLevel}/100</b></span>
                {activeAnalysis.estimatedBpm > 0 && <span>BPM: <b>{activeAnalysis.estimatedBpm}</b></span>}
                <span>Type: <b>{activeAnalysis.isVoice ? 'Voice' : activeAnalysis.isMusic ? 'Music' : 'Mixed'}</b></span>
                <span>Quality: <b>{activeAnalysis.qualityScore}/100</b></span>
              </div>
              <ul className="ac-suggestions mt-2">
                {activeAnalysis.suggestions.map((s) => (
                  <li key={s}><Icon name="sparkles" size={11} /> {s}</li>
                ))}
              </ul>
            </div>
          )}
        </div>

        <div className="options-panel ac-options">
          <h3>Conversion Settings</h3>

          <div className="field">
            <label>Quality preset</label>
            <div className="ac-preset-grid">
              {AUDIO_QUALITY_PRESETS.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  className={`ac-preset-chip ${settings.preset === p.id ? 'active' : ''}`}
                  onClick={() => applyPreset(p.id)}
                  title={p.desc}
                >
                  {p.label}
                </button>
              ))}
            </div>
          </div>

          <div className="field">
            <label>Output format</label>
            <select
              value={settings.outputFormat}
              onChange={(e) => patchSettings({ outputFormat: e.target.value as AudioConvertSettings['outputFormat'], preset: 'custom' })}
            >
              {AUDIO_FORMATS.map((f) => (
                <option key={f.id} value={f.id}>{f.label}{f.lossless ? ' (lossless)' : ''}</option>
              ))}
            </select>
          </div>

          <div className="field-row">
            <div className="field">
              <label>Bitrate</label>
              <select value={settings.bitrate} onChange={(e) => patchSettings({ bitrate: e.target.value, preset: 'custom' })}>
                {BITRATES.map((b) => <option key={b} value={b}>{b}</option>)}
              </select>
            </div>
            <div className="field">
              <label>Sample rate</label>
              <select value={settings.sampleRate} onChange={(e) => patchSettings({ sampleRate: +e.target.value, preset: 'custom' })}>
                {SAMPLE_RATES.map((r) => <option key={r} value={r}>{r} Hz</option>)}
              </select>
            </div>
          </div>

          <div className="field">
            <label>Channels</label>
            <select value={settings.channels} onChange={(e) => patchSettings({ channels: +e.target.value as 0 | 1 | 2, preset: 'custom' })}>
              <option value={0}>Auto (keep original)</option>
              <option value={1}>Mono</option>
              <option value={2}>Stereo</option>
            </select>
          </div>

          {queue.length > 1 && (
            <label className="pdfconv-toggle">
              <input
                type="checkbox"
                checked={settings.mergeQueue}
                onChange={(e) => patchSettings({ mergeQueue: e.target.checked })}
              />
              Merge all files into one audio track
            </label>
          )}

          <button type="button" className="btn btn-ghost btn-sm mt-2" onClick={() => setMetadataOpen((v) => !v)}>
            {metadataOpen ? 'Hide' : 'Show'} Metadata & Album Art
          </button>

          {metadataOpen && (
            <div className="ac-metadata mt-2">
              {(['title', 'artist', 'album', 'year', 'genre'] as const).map((key) => (
                <div key={key} className="field">
                  <label>{key.charAt(0).toUpperCase() + key.slice(1)}</label>
                  <input
                    type="text"
                    value={settings.metadata[key]}
                    onChange={(e) => patchSettings({ metadata: { ...settings.metadata, [key]: e.target.value } })}
                    placeholder={key === 'title' ? 'Track title' : ''}
                  />
                </div>
              ))}
              <div className="field">
                <label>Comment</label>
                <input
                  type="text"
                  value={settings.metadata.comment}
                  onChange={(e) => patchSettings({ metadata: { ...settings.metadata, comment: e.target.value } })}
                />
              </div>
              <div className="ac-cover-row">
                {coverPreview ? (
                  <img src={coverPreview} alt="" className="ac-cover-thumb" />
                ) : (
                  <div className="ac-cover-placeholder"><Icon name="image" size={20} /></div>
                )}
                <button type="button" className="btn btn-outline btn-sm" onClick={() => coverRef.current?.click()}>
                  <Icon name="image" size={14} /> {coverArt ? 'Change cover' : 'Add album art'}
                </button>
                {coverArt && (
                  <button type="button" className="btn btn-ghost btn-sm" onClick={() => {
                    if (coverPreview) URL.revokeObjectURL(coverPreview);
                    setCoverPreview('');
                    setCoverArt(null);
                  }}>
                    Remove
                  </button>
                )}
              </div>
              <label className="pdfconv-toggle">
                <input
                  type="checkbox"
                  checked={settings.stripMetadata}
                  onChange={(e) => patchSettings({ stripMetadata: e.target.checked })}
                />
                Strip all metadata
              </label>
            </div>
          )}

          <h4 className="ac-section-title">AI Enhancement</h4>
          {([
            ['noiseRemoval', 'AI Noise Removal'],
            ['voiceEnhance', 'Voice Enhancement'],
            ['musicEnhance', 'Music Enhancement'],
            ['bassBoost', 'Bass Boost'],
            ['vocalBoost', 'Vocal Boost'],
            ['normalize', 'Normalize Volume'],
            ['loudnessOptimize', 'Loudness Optimization'],
            ['silenceRemoval', 'Silence Removal'],
            ['clarityEnhance', 'Clarity Enhancement'],
            ['stereoEnhance', 'Stereo Enhancement'],
          ] as const).map(([key, label]) => (
            <label key={key} className="pdfconv-toggle">
              <input
                type="checkbox"
                checked={settings.enhance[key]}
                onChange={(e) => patchSettings({ enhance: { ...settings.enhance, [key]: e.target.checked } })}
              />
              {label}
            </label>
          ))}

          <button type="button" className="btn btn-ghost btn-sm mt-2" onClick={() => setAdvancedOpen((v) => !v)}>
            {advancedOpen ? 'Hide' : 'Show'} Advanced Editing
          </button>

          {advancedOpen && (
            <div className="ac-advanced mt-2">
              <div className="field-row">
                <div className="field">
                  <label>Trim start</label>
                  <input type="text" placeholder="00:00:00" value={settings.edit.trimStart} onChange={(e) => patchSettings({ edit: { ...settings.edit, trimStart: e.target.value } })} />
                </div>
                <div className="field">
                  <label>Trim end</label>
                  <input type="text" placeholder="00:01:30" value={settings.edit.trimEnd} onChange={(e) => patchSettings({ edit: { ...settings.edit, trimEnd: e.target.value } })} />
                </div>
              </div>
              <label>Fade in (sec)
                <input type="range" min={0} max={5} step={0.5} value={settings.edit.fadeIn} onChange={(e) => patchSettings({ edit: { ...settings.edit, fadeIn: +e.target.value } })} />
              </label>
              <label>Fade out (sec)
                <input type="range" min={0} max={5} step={0.5} value={settings.edit.fadeOut} onChange={(e) => patchSettings({ edit: { ...settings.edit, fadeOut: +e.target.value } })} />
              </label>
              <label>Volume ({Math.round(settings.edit.volume * 100)}%)
                <input type="range" min={0.1} max={2} step={0.1} value={settings.edit.volume} onChange={(e) => patchSettings({ edit: { ...settings.edit, volume: +e.target.value } })} />
              </label>
              <label>Speed ({settings.edit.speed}x)
                <input type="range" min={0.5} max={2} step={0.1} value={settings.edit.speed} onChange={(e) => patchSettings({ edit: { ...settings.edit, speed: +e.target.value } })} />
              </label>
              <label className="pdfconv-toggle">
                <input type="checkbox" checked={settings.edit.reverse} onChange={(e) => patchSettings({ edit: { ...settings.edit, reverse: e.target.checked } })} />
                Reverse audio
              </label>
            </div>
          )}

          <div className="ac-action-row mt-4">
            {step === 0 && queue.length > 0 && (
              <button type="button" className="btn btn-primary" onClick={() => void analyzeAll()}>
                <Icon name="sparkles" size={16} /> Analyze →
              </button>
            )}
            {step === 1 && (
              <button type="button" className="btn btn-primary" onClick={() => void convertAll()}>
                <Icon name="music" size={16} /> Convert Now
              </button>
            )}
            {step === 0 && !queue.length && (
              <span className="muted">Upload audio to begin</span>
            )}
          </div>
        </div>
      </div>

      <div className="mergepdf-fab-rail" aria-label="Quick actions">
        <button type="button" className="mergepdf-fab mergepdf-fab-ai" title="AI Assistant" onClick={openAI}>
          <Icon name="sparkles" size={18} />
        </button>
      </div>

      <input ref={micRef} type="file" accept={AUDIO_ACCEPT} multiple hidden onChange={(e) => { const f = e.target.files; if (f?.length) void addFilesWithZip([...f]); e.target.value = ''; }} />
      <input ref={zipRef} type="file" accept=".zip,application/zip" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) void addFilesWithZip([f]); e.target.value = ''; }} />
      <input ref={coverRef} type="file" accept="image/*" hidden onChange={(e) => {
        const f = e.target.files?.[0];
        if (!f) return;
        if (coverPreview) URL.revokeObjectURL(coverPreview);
        setCoverArt(f);
        setCoverPreview(URL.createObjectURL(f));
        e.target.value = '';
      }} />
      {error && <ErrorBox message={error} />}
    </div>
  );
}
