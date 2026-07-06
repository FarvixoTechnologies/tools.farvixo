'use client';

import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import Icon from '@/components/Icon';
import { useUI } from '@/components/GlobalUI';
import { ErrorBox, ShareButton, useToolPhase, type ResultFile } from '../shared';
import UniversalDragDropUploader from '../UniversalDragDropUploader';
import { downloadBlob, formatBytes } from '@/lib/download';
import {
  analyzeVideoFile,
  extractVideosFromZip,
  getAutoRecommendation,
  loadVideoSession,
  saveVideoSession,
  type VideoAnalysis,
} from '@/lib/engines/video-analysis-engine';
import {
  convertVideo,
  applyPlatformPreset,
  fetchVideoFromUrl,
  generateOutputName,
  type ConvertResult,
  type ConvertReport,
} from '@/lib/engines/video-conversion-engine';
import {
  DEFAULT_CONVERT_SETTINGS,
  VIDEO_OUTPUT_FORMATS,
  AUDIO_OUTPUT_FORMATS,
  RESOLUTION_PRESETS,
  PLATFORM_PRESETS,
  ENCODER_PRESETS,
  getPlatformGroups,
  type ConvertSettings,
  type ConvertMode,
} from '@/lib/engines/video-presets';

const STEPS = ['Upload', 'Analyze', 'Convert', 'Download'] as const;

interface QueueItem {
  file: File;
  analysis?: VideoAnalysis;
  status: 'pending' | 'analyzing' | 'ready' | 'converting' | 'done' | 'error';
  result?: ConvertResult;
  error?: string;
}

function StepsBar({ current }: { current: number }) {
  return (
    <div className="pdfconv-steps vc-steps" aria-label="Video conversion progress">
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
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

export default function VideoConverterRunner() {
  const { toast } = useUI();
  const { phase, setPhase, error, fail, reset, progress, setProgress } = useToolPhase();
  const [step, setStep] = useState(0);
  const [queue, setQueue] = useState<QueueItem[]>([]);
  const [settings, setSettings] = useState<ConvertSettings>(DEFAULT_CONVERT_SETTINGS);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [reports, setReports] = useState<ConvertReport[]>([]);
  const [status, setStatus] = useState('');
  const [urlInput, setUrlInput] = useState('');
  const [previewUrl, setPreviewUrl] = useState('');
  const [resultPreviewUrl, setResultPreviewUrl] = useState('');
  const [activeAnalysis, setActiveAnalysis] = useState<VideoAnalysis | null>(null);
  const [activeIdx, setActiveIdx] = useState(0);
  const [recording, setRecording] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);
  const abortRef = useRef(false);
  const mediaRecRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const cameraRef = useRef<HTMLInputElement>(null);
  const zipRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const history = loadVideoSession();

  const totalBefore = queue.reduce((s, q) => s + q.file.size, 0);
  const totalAfter = reports.reduce((s, r) => s + r.finalSize, 0);

  const patchSettings = (patch: Partial<ConvertSettings>) => {
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
    saveVideoSession(incoming.map((f) => f.name));
  }, [setPhase]);

  const addFilesWithZip = async (files: File[]) => {
    const videoFiles: File[] = [];
    for (const f of files) {
      if (f.type === 'application/zip' || f.name.endsWith('.zip')) {
        try {
          const extracted = await extractVideosFromZip(f);
          if (!extracted.length) toast('No videos found in ZIP', 'error');
          videoFiles.push(...extracted);
        } catch {
          toast('Could not read ZIP', 'error');
        }
      } else {
        videoFiles.push(f);
      }
    }
    if (videoFiles.length) addFiles(videoFiles);
  };

  useEffect(() => {
    const onPaste = (e: ClipboardEvent) => {
      if (step !== 0) return;
      const files: File[] = [];
      for (const item of e.clipboardData?.items ?? []) {
        if (item.kind === 'file' && item.type.startsWith('video/')) {
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

  const stopRecording = useCallback(() => {
    mediaRecRef.current?.stop();
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    setRecording(false);
  }, []);

  useEffect(() => () => stopRecording(), [stopRecording]);

  const startScreenRecord = async () => {
    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: true });
      streamRef.current = stream;
      const mime = MediaRecorder.isTypeSupported('video/webm;codecs=vp9')
        ? 'video/webm;codecs=vp9' : 'video/webm';
      const recorder = new MediaRecorder(stream, { mimeType: mime });
      chunksRef.current = [];
      recorder.ondataavailable = (e) => { if (e.data.size) chunksRef.current.push(e.data); };
      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: mime });
        addFiles([new File([blob], `screen-recording-${Date.now()}.webm`, { type: mime })]);
      };
      stream.getVideoTracks()[0]?.addEventListener('ended', () => stopRecording());
      mediaRecRef.current = recorder;
      recorder.start(1000);
      setRecording(true);
    } catch {
      toast('Screen recording cancelled or denied', 'error');
    }
  };

  const selectQueueItem = async (idx: number) => {
    setActiveIdx(idx);
    const item = queue[idx];
    if (!item) return;
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(URL.createObjectURL(item.file));
    if (item.analysis) {
      setActiveAnalysis(item.analysis);
      return;
    }
    try {
      const analysis = await analyzeVideoFile(item.file);
      setQueue((q) => q.map((x, i) => (i === idx ? { ...x, analysis, status: 'ready' } : x)));
      setActiveAnalysis(analysis);
    } catch { /* preview still works */ }
  };

  const analyzeAll = async () => {
    if (queue.length === 0) return;
    setPhase('working');
    setStatus('Analyzing video metadata...');
    setStep(1);
    const updated = [...queue];

    for (let i = 0; i < updated.length; i++) {
      updated[i] = { ...updated[i], status: 'analyzing' };
      setQueue([...updated]);
      try {
        const analysis = await analyzeVideoFile(updated[i].file);
        updated[i] = { ...updated[i], analysis, status: 'ready' };
        if (i === 0) {
          setActiveAnalysis(analysis);
          const rec = getAutoRecommendation(analysis);
          patchSettings({
            outputFormat: rec.recommendedFormat,
            resolution: rec.recommendedResolution,
            mode: rec.recommendedMode,
            crf: rec.crf,
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
    setStep(1);
  };

  const convertAll = async () => {
    if (queue.length === 0) return;
    setPhase('working');
    setStep(2);
    setStatus('Loading FFmpeg engine (first run ~30MB, cached after)...');
    abortRef.current = false;

    const updated = [...queue];
    const out: ResultFile[] = [];
    const reps: ConvertReport[] = [];

    for (let i = 0; i < updated.length; i++) {
      if (abortRef.current) break;
      updated[i] = { ...updated[i], status: 'converting' };
      setQueue([...updated]);
      setStatus(`Converting ${i + 1}/${updated.length}: ${updated[i].file.name}`);

      try {
        const result = await convertVideo(
          updated[i].file,
          settings,
          setProgress,
          updated[i].analysis?.width ?? 0,
          updated[i].analysis?.height ?? 0,
        );
        const name = generateOutputName(updated[i].file.name, result.format);
        updated[i] = { ...updated[i], status: 'done', result };
        out.push({ name, blob: result.blob });
        reps.push({
          fileName: updated[i].file.name,
          originalSize: result.originalSize,
          finalSize: result.compressedSize,
          reductionPercent: result.reductionPercent,
          processingTimeMs: result.processingTimeMs,
          format: result.format,
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
    if (out[0]?.blob.type.startsWith('video/') || out[0]?.blob.type === 'image/gif') {
      setResultPreviewUrl(URL.createObjectURL(out[0].blob));
    }
    setStep(3);
    setPhase('done');
  };

  const downloadAllZip = async () => {
    const JSZip = (await import('jszip')).default;
    const zip = new JSZip();
    for (const r of results) zip.file(r.name, r.blob);
    const blob = await zip.generateAsync({ type: 'blob' });
    downloadBlob(blob, 'converted-videos.zip');
  };

  const importUrl = async () => {
    if (!urlInput.trim()) return;
    try {
      setStatus('Fetching video from URL...');
      const file = await fetchVideoFromUrl(urlInput.trim());
      addFiles([file]);
      setUrlInput('');
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => {
    reset();
    setQueue([]);
    setResults([]);
    setReports([]);
    setStep(0);
    setActiveAnalysis(null);
    setActiveIdx(0);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    if (resultPreviewUrl) URL.revokeObjectURL(resultPreviewUrl);
    setPreviewUrl('');
    setResultPreviewUrl('');
  };

  const removeItem = (idx: number) => {
    setQueue((q) => q.filter((_, i) => i !== idx));
  };

  if (phase === 'working') {
    return (
      <div className="vc-processing">
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
        <button className="btn btn-ghost btn-sm mt-4" onClick={() => { abortRef.current = true; reset(); }}>
          Cancel
        </button>
      </div>
    );
  }

  if (phase === 'done' && step === 3) {
    return (
      <div className="vc-results">
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
              {totalBefore > 0 ? `-${Math.round((1 - totalAfter / totalBefore) * 100)}%` : '0%'}
            </span>
            <span className="ic-stat-label">Saved</span>
          </div>
        </div>

        {reports.length > 0 && (
          <div className="vc-report glass mt-4">
            <h3><Icon name="database" size={16} /> Performance Report</h3>
            <div className="vc-report-grid">
              {reports.map((r) => (
                <div key={r.fileName} className="vc-report-row">
                  <span className="vc-report-name">{r.fileName}</span>
                  <span>{formatBytes(r.originalSize)} → {formatBytes(r.finalSize)}</span>
                  <span className="ic-stat-green">-{r.reductionPercent}%</span>
                  <span className="muted">{(r.processingTimeMs / 1000).toFixed(1)}s</span>
                  <span className="muted">Score {r.qualityScore}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        {resultPreviewUrl && (
          <div className="vc-preview mt-4">
            <h4 className="vc-preview-label"><Icon name="play" size={14} /> Converted Preview</h4>
            <video src={resultPreviewUrl} controls className="vc-preview-video" />
          </div>
        )}

        {results.length > 1 && (
          <div className="vc-download-list mt-4">
            <h4>Individual Downloads</h4>
            {results.map((r) => (
              <button
                key={r.name}
                type="button"
                className="btn btn-ghost btn-sm vc-download-item"
                onClick={() => downloadBlob(r.blob, r.name)}
              >
                <Icon name="download" size={14} /> {r.name} ({formatBytes(r.blob.size)})
              </button>
            ))}
          </div>
        )}

        <div className="ic-actions mt-4">
          {results.length === 1 && (
            <button className="btn btn-primary" onClick={() => downloadBlob(results[0].blob, results[0].name)}>
              <Icon name="download" size={16} /> Download ({formatBytes(results[0].blob.size)})
            </button>
          )}
          {results.length > 1 && (
            <button className="btn btn-primary" onClick={() => void downloadAllZip()}>
              <Icon name="download" size={16} /> Download All as ZIP
            </button>
          )}
          {results[0] && <ShareButton file={results[0]} toolSlug="video-converter" />}
          <button className="btn btn-ghost" onClick={resetAll}>
            <Icon name="refresh" size={15} /> Convert More
          </button>
        </div>

        <div className="mergepdf-fab-rail" aria-label="Quick actions">
          <Link href="/dashboard/history" className="mergepdf-fab" title="History">
            <Icon name="clock" size={18} />
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="vc-workspace pdfconv-layout">
      <StepsBar current={step} />

      <div className="vc-privacy-badge">
        <Icon name="shield" size={14} /> 100% browser processing with FFmpeg WASM — videos never leave your device
      </div>

      <div className="workspace-grid">
        <div>
          <UniversalDragDropUploader
            accept="video/*,.mp4,.mkv,.mov,.avi,.wmv,.flv,.webm,.mpeg,.mpg,.3gp,.m4v,.ts,.mts,.gif"
            multiple
            maxSizeMB={500}
            onFiles={(f) => void addFilesWithZip(f)}
            title="Drop videos here"
            note="MP4, MKV, MOV, AVI, WebM, GIF & 15+ formats · Batch · ZIP · Best under ~200MB per file"
            accent="var(--accent-video)"
          />

          <div className="ac-upload-actions mt-3">
            <button type="button" className="btn btn-outline btn-sm" onClick={() => recording ? stopRecording() : void startScreenRecord()}>
              <Icon name="film" size={15} /> {recording ? 'Stop Recording' : 'Screen Record'}
            </button>
            <button type="button" className="btn btn-outline btn-sm" onClick={() => cameraRef.current?.click()}>
              <Icon name="video" size={15} /> Camera
            </button>
            <button type="button" className="btn btn-outline btn-sm" onClick={() => zipRef.current?.click()}>
              <Icon name="folder" size={15} /> ZIP Upload
            </button>
            <button type="button" className="btn btn-outline btn-sm" onClick={() => fileRef.current?.click()}>
              <Icon name="folder" size={15} /> Choose Files
            </button>
            <span className="muted ac-hint"><Icon name="copy" size={13} /> Ctrl+V to paste video</span>
          </div>

          <div className="vc-url-row mt-3">
            <input
              type="url"
              placeholder="Import from URL (direct video link)"
              value={urlInput}
              onChange={(e) => setUrlInput(e.target.value)}
              aria-label="Video URL"
            />
            <button className="btn btn-ghost btn-sm" disabled={!urlInput.trim()} onClick={() => void importUrl()}>
              Import
            </button>
          </div>

          {history.length > 0 && (
            <p className="muted ac-history mt-2">
              <Icon name="clock" size={13} /> Recent: {history.slice(0, 4).join(', ')}
            </p>
          )}

          {previewUrl && (
            <div className="vc-preview mt-4">
              <video ref={videoRef} src={previewUrl} controls className="vc-preview-video" />
            </div>
          )}

          {queue.length > 0 && (
            <div className="vc-queue mt-4">
              <h4>Upload Queue ({queue.length})</h4>
              {queue.map((item, i) => (
                <div
                  key={`${item.file.name}-${i}`}
                  className={`ic-batch-item ${item.status} ${i === activeIdx ? 'active' : ''}`}
                  onClick={() => void selectQueueItem(i)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => e.key === 'Enter' && void selectQueueItem(i)}
                >
                  <Icon name="video" size={14} />
                  <span className="ic-batch-name">{item.file.name}</span>
                  <span className="ic-batch-size">{formatBytes(item.file.size)}</span>
                  {item.analysis && (
                    <span className="muted">{item.analysis.width}×{item.analysis.height}</span>
                  )}
                  <span className={`vc-status-pill ${item.status}`}>{item.status}</span>
                  <button className="file-remove" onClick={() => removeItem(i)} aria-label="Remove">
                    <Icon name="x" size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}

          {activeAnalysis && step >= 1 && (
            <div className="ic-analysis glass mt-4">
              <h4><Icon name="info" size={14} /> AI Smart Analysis</h4>
              <div className="ic-analysis-grid">
                <span>Resolution: <b>{activeAnalysis.width}×{activeAnalysis.height}</b></span>
                <span>Duration: <b>{formatDuration(activeAnalysis.duration)}</b></span>
                <span>Bitrate: <b>~{activeAnalysis.estimatedBitrateKbps} kbps</b></span>
                <span>Format: <b>{activeAnalysis.format}</b></span>
                <span>Aspect: <b>{activeAnalysis.aspectRatio}</b></span>
                <span>Orientation: <b>{activeAnalysis.orientation}</b></span>
                <span>HDR: <b>{activeAnalysis.isHdr ? 'Yes' : 'No'}</b></span>
                <span>Audio: <b>{activeAnalysis.hasAudio ? 'Yes' : 'No'}</b></span>
                <span>Quality: <b>{activeAnalysis.qualityScore}/100</b></span>
              </div>
              <ul className="vc-suggestions mt-2">
                {activeAnalysis.suggestions.map((s) => (
                  <li key={s}><Icon name="sparkles" size={11} /> {s}</li>
                ))}
              </ul>
            </div>
          )}
        </div>

        <div className="options-panel vc-options">
          <h3>Conversion Settings</h3>

          <div className="field">
            <label>Output type</label>
            <select
              value={settings.outputKind}
              onChange={(e) => {
                const kind = e.target.value as ConvertSettings['outputKind'];
                const fmt = kind === 'audio' ? 'mp3' : kind === 'gif' ? 'gif' : 'mp4';
                patchSettings({ outputKind: kind, outputFormat: fmt });
              }}
            >
              <option value="video">Video</option>
              <option value="audio">Audio only</option>
              <option value="gif">GIF</option>
            </select>
          </div>

          <div className="field">
            <label>Format</label>
            <select
              value={settings.outputFormat}
              onChange={(e) => patchSettings({ outputFormat: e.target.value })}
            >
              {(settings.outputKind === 'audio' ? AUDIO_OUTPUT_FORMATS : VIDEO_OUTPUT_FORMATS).map((f) => (
                <option key={f.id} value={f.ext}>{f.label}</option>
              ))}
            </select>
          </div>

          <div className="field">
            <label>Mode</label>
            <div className="ic-mode-grid">
              {(['balanced', 'quality', 'compress', 'custom'] as ConvertMode[]).map((m) => (
                <button
                  key={m}
                  type="button"
                  className={`ic-mode-btn ${settings.mode === m ? 'active' : ''}`}
                  onClick={() => patchSettings({ mode: m })}
                >
                  {m.charAt(0).toUpperCase() + m.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {settings.outputKind === 'video' && (
            <>
              <div className="field">
                <label>Resolution</label>
                <select
                  value={settings.resolution}
                  onChange={(e) => patchSettings({ resolution: e.target.value, width: 0, height: 0 })}
                >
                  {RESOLUTION_PRESETS.map((r) => (
                    <option key={r.id} value={r.id}>{r.label}</option>
                  ))}
                </select>
              </div>

              <div className="field">
                <label>Video codec</label>
                <select
                  value={settings.videoCodec}
                  onChange={(e) => patchSettings({ videoCodec: e.target.value as ConvertSettings['videoCodec'] })}
                >
                  <option value="h264">H.264 (universal)</option>
                  <option value="vp9">VP9 (WebM)</option>
                </select>
              </div>

              <div className="field">
                <label>Quality (CRF) <span className="range-value">{settings.crf}</span></label>
                <input
                  type="range" min={18} max={32} value={settings.crf}
                  onChange={(e) => patchSettings({ crf: +e.target.value })}
                />
                <div className="ic-quality-labels"><span>Smaller</span><span>Better quality</span></div>
              </div>

              <div className="field">
                <label>Encoder preset</label>
                <select value={settings.preset} onChange={(e) => patchSettings({ preset: e.target.value })}>
                  {ENCODER_PRESETS.map((p) => <option key={p} value={p}>{p}</option>)}
                </select>
              </div>

              <div className="field">
                <label>Frame rate</label>
                <select
                  value={settings.fps}
                  onChange={(e) => patchSettings({ fps: +e.target.value })}
                >
                  <option value={0}>Original</option>
                  <option value={24}>24 fps (Cinema)</option>
                  <option value={25}>25 fps (PAL)</option>
                  <option value={30}>30 fps</option>
                  <option value={60}>60 fps</option>
                </select>
              </div>
            </>
          )}

          <details className="ic-advanced-section">
            <summary><Icon name="sparkles" size={14} /> AI Optimization</summary>
            <label className="checkbox-row mt-2">
              <input type="checkbox" checked={settings.aiDenoise} onChange={(e) => patchSettings({ aiDenoise: e.target.checked })} />
              AI noise removal (hqdn3d)
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={settings.aiStabilize} onChange={(e) => patchSettings({ aiStabilize: e.target.checked })} />
              AI stabilization (deshake)
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={settings.aiUpscale} onChange={(e) => patchSettings({ aiUpscale: e.target.checked })} />
              AI upscale (1.5× for SD sources)
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={settings.aiHdr} onChange={(e) => patchSettings({ aiHdr: e.target.checked })} />
              HDR / color enhancement
            </label>
          </details>

          <details className="ic-advanced-section">
            <summary><Icon name="music" size={14} /> Audio</summary>
            <label className="checkbox-row mt-2">
              <input type="checkbox" checked={settings.removeAudio} onChange={(e) => patchSettings({ removeAudio: e.target.checked })} />
              Remove audio track
            </label>
            <label className="checkbox-row">
              <input type="checkbox" checked={settings.normalizeAudio} onChange={(e) => patchSettings({ normalizeAudio: e.target.checked })} />
              Loudness normalization
            </label>
            <div className="field mt-2">
              <label>Audio bitrate</label>
              <select value={settings.audioBitrate} onChange={(e) => patchSettings({ audioBitrate: e.target.value })}>
                {['64k', '96k', '128k', '192k', '256k', '320k'].map((b) => (
                  <option key={b} value={b}>{b}</option>
                ))}
              </select>
            </div>
          </details>

          <details className="ic-advanced-section">
            <summary><Icon name="scissors" size={14} /> Trim &amp; Edit</summary>
            <div className="field-row mt-2">
              <div className="field">
                <label>Start (hh:mm:ss)</label>
                <input value={settings.trimStart} onChange={(e) => patchSettings({ trimStart: e.target.value })} placeholder="00:00:00" />
              </div>
              <div className="field">
                <label>End (hh:mm:ss)</label>
                <input value={settings.trimEnd} onChange={(e) => patchSettings({ trimEnd: e.target.value })} placeholder="00:01:00" />
              </div>
            </div>
            <div className="field">
              <label>Rotate</label>
              <select
                value={settings.rotate}
                onChange={(e) => patchSettings({ rotate: +e.target.value as ConvertSettings['rotate'] })}
              >
                <option value={0}>None</option>
                <option value={90}>90° CW</option>
                <option value={180}>180°</option>
                <option value={270}>90° CCW</option>
              </select>
            </div>
            <div className="field">
              <label>Speed <span className="range-value">{settings.speed.toFixed(2)}×</span></label>
              <input
                type="range" min={0.5} max={2} step={0.05} value={settings.speed}
                onChange={(e) => patchSettings({ speed: +e.target.value })}
              />
            </div>
            <div className="field-row">
              <label className="checkbox-row">
                <input type="checkbox" checked={settings.flipH} onChange={(e) => patchSettings({ flipH: e.target.checked })} />
                Flip horizontal
              </label>
              <label className="checkbox-row">
                <input type="checkbox" checked={settings.flipV} onChange={(e) => patchSettings({ flipV: e.target.checked })} />
                Flip vertical
              </label>
            </div>
          </details>

          <details className="ic-advanced-section">
            <summary><Icon name="smartphone" size={14} /> Social / Platform Presets</summary>
            <div className="field mt-2">
              <select
                defaultValue=""
                onChange={(e) => {
                  const p = PLATFORM_PRESETS.find((x) => x.id === e.target.value);
                  if (p) setSettings(applyPlatformPreset(settings, p));
                }}
              >
                <option value="">Select platform preset...</option>
                {Array.from(getPlatformGroups().entries()).map(([platform, presets]) => (
                  <optgroup key={platform} label={platform}>
                    {presets.map((p) => (
                      <option key={p.id} value={p.id}>{p.label} ({p.width}×{p.height})</option>
                    ))}
                  </optgroup>
                ))}
              </select>
            </div>
          </details>

          <label className="checkbox-row mt-2">
            <input type="checkbox" checked={settings.stripMetadata} onChange={(e) => patchSettings({ stripMetadata: e.target.checked })} />
            Strip metadata (privacy)
          </label>

          {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}

          <div className="vc-action-row mt-3">
            {step < 1 && queue.length > 0 && (
              <button className="btn btn-primary" onClick={() => void analyzeAll()}>
                <Icon name="search" size={16} /> Analyze {queue.length > 1 ? `${queue.length} Videos` : 'Video'}
              </button>
            )}
            {step >= 1 && (
              <button className="btn btn-primary" disabled={queue.length === 0} onClick={() => void convertAll()}>
                <Icon name="zap" size={16} /> Convert Now
              </button>
            )}
            {queue.length > 0 && step < 1 && (
              <button className="btn btn-ghost" onClick={() => void convertAll()}>
                Skip analysis
              </button>
            )}
          </div>

          <p className="muted mt-2" style={{ fontSize: 12 }}>
            Powered by FFmpeg WebAssembly · GPU encoding when browser supports it · Best for files under ~200MB
          </p>
        </div>
      </div>

      <input
        ref={cameraRef}
        type="file"
        accept="video/*"
        capture="environment"
        hidden
        onChange={(e) => { const f = e.target.files; if (f?.length) void addFilesWithZip([...f]); e.target.value = ''; }}
      />
      <input
        ref={zipRef}
        type="file"
        accept=".zip,application/zip"
        hidden
        onChange={(e) => { const f = e.target.files; if (f?.length) void addFilesWithZip([...f]); e.target.value = ''; }}
      />
      <input
        ref={fileRef}
        type="file"
        accept="video/*,.mp4,.mkv,.mov,.avi,.webm,.gif"
        multiple
        hidden
        onChange={(e) => { const f = e.target.files; if (f?.length) void addFilesWithZip([...f]); e.target.value = ''; }}
      />
    </div>
  );
}
