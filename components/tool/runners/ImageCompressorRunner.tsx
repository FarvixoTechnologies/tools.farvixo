'use client';

import { useState, useCallback, useRef, useEffect } from 'react';
import { FileDrop, Processing, ErrorBox, useToolPhase } from '../shared';
import dynamic from 'next/dynamic';
import Icon from '@/components/Icon';
import { formatBytes } from '@/lib/download';
import {
  compressImage,
  compressToTargetSize,
  compareCodecs,
  analyzeImage,
  getAutoSettings,
  generateFilename,
  getFormatExtension,
  type CompressionOptions,
  type CompressionResult,
  type OutputFormat,
  type CompressionMode,
  type ImageAnalysis,
} from '@/lib/engines/image-compression-engine';
import { socialPresets, govPresets, responsiveSizes, getPresetsByPlatform } from '@/lib/engines/image-presets';
import { analyzeImageWithAI, getSmartCompressionSettings, type AIAnalysisResult } from '@/lib/engines/image-analysis-engine';

const FabRail = dynamic(() => import('../FabRail'), { ssr: false });

interface BatchItem {
  file: File;
  status: 'pending' | 'processing' | 'done' | 'error';
  result?: CompressionResult;
  error?: string;
  preview?: string;
}

interface CodecComparison {
  format: string;
  blob: Blob;
  size: number;
  timeMs: number;
}

export default function ImageCompressorRunner() {
  const { phase, setPhase, error, fail, reset } = useToolPhase();

  // Files & batch
  const [files, setFiles] = useState<File[]>([]);
  const [batchItems, setBatchItems] = useState<BatchItem[]>([]);
  const [activeTab, setActiveTab] = useState<'compress' | 'compare' | 'responsive'>('compress');

  // Compression options
  const [mode, setMode] = useState<CompressionMode>('balanced');
  const [format, setFormat] = useState<OutputFormat>('original');
  const [quality, setQuality] = useState(75);
  const [effort, setEffort] = useState(6);
  const [targetSize, setTargetSize] = useState(100);
  const [stripMetadata, setStripMetadata] = useState(true);

  // Resize options
  const [enableResize, setEnableResize] = useState(false);
  const [resizeWidth, setResizeWidth] = useState('');
  const [resizeHeight, setResizeHeight] = useState('');

  // Presets
  const [presetType, setPresetType] = useState<'none' | 'social' | 'gov' | 'responsive'>('none');
  const [selectedSocial, setSelectedSocial] = useState('');
  const [selectedGov, setSelectedGov] = useState('');
  const [selectedSizes, setSelectedSizes] = useState<number[]>([640, 1024, 1920]);

  // Results
  const [comparison, setComparison] = useState<CodecComparison[]>([]);
  const [analysis, setAnalysis] = useState<ImageAnalysis | null>(null);
  const [totalBefore, setTotalBefore] = useState(0);
  const [totalAfter, setTotalAfter] = useState(0);

  // AI analysis
  const [aiAnalysis, setAiAnalysis] = useState<AIAnalysisResult | null>(null);
  const [aiLoading, setAiLoading] = useState(false);

  // Comparison slider
  const [showComparison, setShowComparison] = useState(false);
  const [sliderPos, setSliderPos] = useState(50);
  const [originalPreview, setOriginalPreview] = useState('');
  const [compressedPreview, setCompressedPreview] = useState('');
  const sliderRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);

  const abortRef = useRef(false);

  // Register service worker for offline WASM caching
  useEffect(() => {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    }
  }, []);

  const handleFiles = useCallback((newFiles: File[]) => {
    setFiles(newFiles);
    setBatchItems(newFiles.map((f) => ({ file: f, status: 'pending' })));
    setPhase('idle');
    setShowComparison(false);
    setComparison([]);
    setAnalysis(null);
    if (newFiles.length === 1) {
      void analyzeImage(newFiles[0]).then((a) => {
        setAnalysis(a);
        if (mode === 'auto') {
          const settings = getAutoSettings(a);
          setFormat(settings.format);
          setQuality(settings.quality);
        }
      });
    }
  }, [mode, setPhase]);

  const runAIAnalysis = async () => {
    if (files.length === 0) return;
    setAiLoading(true);
    try {
      const result = await analyzeImageWithAI(files[0]);
      setAiAnalysis(result);
      if (analysis) {
        const settings = getSmartCompressionSettings(result, analysis);
        setFormat(settings.format);
        setQuality(settings.quality);
        setEffort(settings.effort);
      }
    } catch {
      // AI analysis failed silently, user continues with manual settings
    }
    setAiLoading(false);
  };

  const getOptions = useCallback((): CompressionOptions => {
    const resize = enableResize && (resizeWidth || resizeHeight)
      ? { width: resizeWidth ? parseInt(resizeWidth) : undefined, height: resizeHeight ? parseInt(resizeHeight) : undefined, fit: 'contain' as const }
      : undefined;
    return { format, mode, quality, effort, metadata: stripMetadata ? 'strip-all' : 'preserve', chromaSubsampling: '4:2:0', stripMetadata, resize };
  }, [format, mode, quality, effort, stripMetadata, enableResize, resizeWidth, resizeHeight]);

  const processAll = async () => {
    if (files.length === 0) return;
    setPhase('working');
    abortRef.current = false;

    const opts = getOptions();
    let before = 0;
    let after = 0;
    const updated = [...batchItems];

    for (let i = 0; i < files.length; i++) {
      if (abortRef.current) break;
      updated[i] = { ...updated[i], status: 'processing' };
      setBatchItems([...updated]);

      try {
        let result: CompressionResult;

        if (presetType === 'social' && selectedSocial) {
          const preset = socialPresets.find((p) => p.id === selectedSocial)!;
          result = await compressImage(files[i], {
            ...opts,
            format: preset.format,
            resize: { width: preset.width, height: preset.height, fit: 'cover' },
          });
          if (preset.maxKB && result.blob.size > preset.maxKB * 1024) {
            result = await compressToTargetSize(files[i], preset.maxKB, {
              ...opts,
              format: preset.format,
              resize: { width: preset.width, height: preset.height, fit: 'cover' },
            });
          }
        } else if (presetType === 'gov' && selectedGov) {
          const preset = govPresets.find((p) => p.id === selectedGov)!;
          result = await compressToTargetSize(files[i], preset.maxKB, {
            ...opts,
            format: 'jpeg',
            resize: { width: preset.width, height: preset.height, fit: 'cover' },
          });
        } else if (mode === 'target-size') {
          result = await compressToTargetSize(files[i], targetSize, opts);
        } else {
          result = await compressImage(files[i], opts);
        }

        const preview = URL.createObjectURL(result.blob);
        before += result.originalSize;
        after += result.compressedSize;
        updated[i] = { ...updated[i], status: 'done', result, preview };
      } catch (e) {
        updated[i] = { ...updated[i], status: 'error', error: e instanceof Error ? e.message : 'Failed' };
      }
      setBatchItems([...updated]);
    }

    setTotalBefore(before);
    setTotalAfter(after);

    if (files.length === 1 && updated[0].result && updated[0].preview) {
      setOriginalPreview(URL.createObjectURL(files[0]));
      setCompressedPreview(updated[0].preview);
      setShowComparison(true);
    }

    setPhase('done');
  };

  const processResponsive = async () => {
    if (files.length === 0 || selectedSizes.length === 0) return;
    setPhase('working');
    const file = files[0];
    const opts = getOptions();
    const results: BatchItem[] = [];

    for (const size of selectedSizes) {
      try {
        const result = await compressImage(file, {
          ...opts,
          resize: { width: size, height: undefined, fit: 'contain' },
        });
        results.push({
          file: new File([result.blob], generateFilename(file.name, result.format, `${size}w`), { type: result.blob.type }),
          status: 'done',
          result,
          preview: URL.createObjectURL(result.blob),
        });
      } catch (e) {
        results.push({ file, status: 'error', error: e instanceof Error ? e.message : 'Failed' });
      }
    }

    setBatchItems(results);
    setPhase('done');
  };

  const runComparison = async () => {
    if (files.length === 0) return;
    setPhase('working');
    try {
      const results = await compareCodecs(files[0], quality);
      setComparison(results);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  const downloadFile = (item: BatchItem) => {
    if (!item.result) return;
    const url = URL.createObjectURL(item.result.blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = generateFilename(item.file.name, item.result.format);
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 30_000);
  };

  const downloadAll = async () => {
    const JSZip = (await import('jszip')).default;
    const zip = new JSZip();
    for (const item of batchItems) {
      if (item.status === 'done' && item.result) {
        const name = generateFilename(item.file.name, item.result.format);
        zip.file(name, item.result.blob);
      }
    }
    const blob = await zip.generateAsync({ type: 'blob' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'compressed-images.zip';
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 30_000);
  };

  const resetAll = () => {
    reset();
    setFiles([]);
    setBatchItems([]);
    setShowComparison(false);
    setComparison([]);
    setAnalysis(null);
    setTotalBefore(0);
    setTotalAfter(0);
    if (originalPreview) URL.revokeObjectURL(originalPreview);
    if (compressedPreview) URL.revokeObjectURL(compressedPreview);
    setOriginalPreview('');
    setCompressedPreview('');
  };

  // Slider drag handling
  const handleSliderMove = useCallback((e: React.MouseEvent | React.TouchEvent) => {
    if (!isDragging.current || !sliderRef.current) return;
    const rect = sliderRef.current.getBoundingClientRect();
    const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX;
    const pos = Math.max(0, Math.min(100, ((clientX - rect.left) / rect.width) * 100));
    setSliderPos(pos);
  }, []);

  const generateCodeSnippet = (): string => {
    if (activeTab !== 'responsive' || batchItems.length === 0) return '';
    const name = files[0]?.name.replace(/\.[^.]+$/, '') || 'image';
    const ext = getFormatExtension(format === 'original' ? 'webp' : format);
    const srcsetParts = selectedSizes.map((s) => `  /images/${name}-${s}w.${ext} ${s}w`);
    return `<img\n  srcset="\n${srcsetParts.join(',\n')}\n  "\n  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 80vw, 1280px"\n  src="/images/${name}-1280w.${ext}"\n  alt="${name}"\n  loading="lazy"\n  decoding="async"\n/>`;
  };

  // Processing view
  if (phase === 'working') {
    const done = batchItems.filter((b) => b.status === 'done').length;
    const total = batchItems.length;
    const label =
      activeTab === 'compare'
        ? 'Comparing codecs...'
        : activeTab === 'responsive'
          ? 'Generating responsive sizes...'
          : `Compressing ${done}/${total} images...`;
    return (
      <div className="ic-processing">
        <Processing label={label} progress={activeTab === 'compress' && total > 0 ? done / total : undefined} />
        {activeTab === 'compress' && (
          <button className="btn btn-ghost btn-sm mt-4" onClick={() => { abortRef.current = true; }}>Cancel</button>
        )}
      </div>
    );
  }

  // Results view
  if (phase === 'done') {
    return (
      <div className="ic-results">
        {/* Comparison Slider */}
        {showComparison && originalPreview && compressedPreview && (
          <div className="ic-comparison-container">
            <h3>Before / After Comparison</h3>
            <div
              ref={sliderRef}
              className="ic-comparison-slider"
              onMouseDown={() => { isDragging.current = true; }}
              onMouseUp={() => { isDragging.current = false; }}
              onMouseLeave={() => { isDragging.current = false; }}
              onMouseMove={handleSliderMove}
              onTouchStart={() => { isDragging.current = true; }}
              onTouchEnd={() => { isDragging.current = false; }}
              onTouchMove={handleSliderMove}
            >
              <div className="ic-comparison-original">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={originalPreview} alt="Original" />
                <span className="ic-comparison-label ic-label-left">Original · {formatBytes(totalBefore)}</span>
              </div>
              <div className="ic-comparison-compressed" style={{ clipPath: `inset(0 0 0 ${sliderPos}%)` }}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={compressedPreview} alt="Compressed" />
                <span className="ic-comparison-label ic-label-right">Compressed · {formatBytes(totalAfter)}</span>
              </div>
              <div className="ic-slider-handle" style={{ left: `${sliderPos}%` }}>
                <div className="ic-slider-line" />
                <div className="ic-slider-grip">⟨ ⟩</div>
              </div>
            </div>
          </div>
        )}

        {/* Stats summary */}
        <div className="ic-stats-bar">
          <div className="ic-stat">
            <span className="ic-stat-value">{formatBytes(totalBefore)}</span>
            <span className="ic-stat-label">Original</span>
          </div>
          <div className="ic-stat">
            <Icon name="arrow-right" size={20} />
          </div>
          <div className="ic-stat">
            <span className="ic-stat-value ic-stat-green">{formatBytes(totalAfter)}</span>
            <span className="ic-stat-label">Compressed</span>
          </div>
          <div className="ic-stat">
            <span className="ic-stat-value ic-stat-green">-{totalBefore > 0 ? Math.round((1 - totalAfter / totalBefore) * 100) : 0}%</span>
            <span className="ic-stat-label">Saved</span>
          </div>
        </div>

        {/* Codec comparison results */}
        {comparison.length > 0 && (
          <div className="ic-codec-compare">
            <h3>Codec Comparison</h3>
            <div className="ic-codec-grid">
              {comparison.map((c) => (
                <div key={c.format} className="ic-codec-card glass">
                  <span className="ic-codec-format">{c.format.toUpperCase()}</span>
                  <span className="ic-codec-size">{formatBytes(c.size)}</span>
                  <span className="ic-codec-reduction">-{Math.round((1 - c.size / files[0].size) * 100)}%</span>
                  <span className="ic-codec-time">{c.timeMs.toFixed(0)}ms</span>
                  <button className="btn btn-ghost btn-sm" onClick={() => {
                    const url = URL.createObjectURL(c.blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = generateFilename(files[0].name, c.format);
                    a.click();
                  }}>
                    <Icon name="download" size={14} /> Download
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Batch results */}
        {batchItems.length > 1 && (
          <div className="ic-batch-results">
            <h3>Batch Results ({batchItems.filter((b) => b.status === 'done').length}/{batchItems.length})</h3>
            <div className="ic-batch-list">
              {batchItems.map((item, i) => (
                <div key={i} className={`ic-batch-item ${item.status}`}>
                  <span className="ic-batch-name">{item.file.name}</span>
                  {item.result && (
                    <>
                      <span className="ic-batch-size">{formatBytes(item.result.originalSize)} → {formatBytes(item.result.compressedSize)}</span>
                      <span className="ic-batch-reduction ic-stat-green">-{item.result.reductionPercent}%</span>
                    </>
                  )}
                  {item.error && <span className="ic-batch-error">{item.error}</span>}
                  {item.status === 'done' && (
                    <button className="btn btn-ghost btn-sm" onClick={() => downloadFile(item)}>
                      <Icon name="download" size={14} />
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Responsive code snippet */}
        {activeTab === 'responsive' && batchItems.length > 0 && (
          <div className="ic-code-snippet">
            <h3>HTML srcset Code</h3>
            <pre className="output-area"><code>{generateCodeSnippet()}</code></pre>
            <button className="btn btn-ghost btn-sm mt-2" onClick={() => { void navigator.clipboard.writeText(generateCodeSnippet()); }}>
              <Icon name="copy" size={14} /> Copy Code
            </button>
          </div>
        )}

        {/* Action buttons */}
        <div className="ic-actions">
          {batchItems.filter((b) => b.status === 'done').length === 1 && batchItems[0].result && (
            <button className="btn btn-primary" onClick={() => downloadFile(batchItems[0])}>
              <Icon name="download" size={16} /> Download ({formatBytes(batchItems[0].result.compressedSize)})
            </button>
          )}
          {batchItems.filter((b) => b.status === 'done').length > 1 && (
            <button className="btn btn-primary" onClick={() => void downloadAll()}>
              <Icon name="download" size={16} /> Download All as ZIP
            </button>
          )}
          <button className="btn btn-ghost" onClick={resetAll}>
            <Icon name="refresh" size={15} /> Compress More
          </button>
        </div>
        {(() => {
          const done = batchItems.find((b) => b.status === 'done' && b.result);
          if (!done?.result) return null;
          return (
            <FabRail
              file={{ name: generateFilename(done.file.name, done.result.format as OutputFormat), blob: done.result.blob }}
              toolSlug="image-compressor"
            />
          );
        })()}
      </div>
    );
  }

  // Main workspace
  return (
    <div className="ic-workspace">
      {/* Tab navigation */}
      <div className="ic-tabs">
        <button className={`ic-tab ${activeTab === 'compress' ? 'active' : ''}`} onClick={() => setActiveTab('compress')}>
          <Icon name="image-down" size={16} /> Compress
        </button>
        <button className={`ic-tab ${activeTab === 'compare' ? 'active' : ''}`} onClick={() => setActiveTab('compare')}>
          <Icon name="columns" size={16} /> Compare Codecs
        </button>
        <button className={`ic-tab ${activeTab === 'responsive' ? 'active' : ''}`} onClick={() => setActiveTab('responsive')}>
          <Icon name="smartphone" size={16} /> Responsive Set
        </button>
      </div>

      <div className="workspace-grid">
        {/* Left: Upload area */}
        <div>
          <FileDrop
            accept="image/*"
            multiple={activeTab === 'compress'}
            files={files}
            onFiles={handleFiles}
            hint="JPG, PNG, WebP, AVIF, GIF, BMP, TIFF · No upload — 100% in your browser"
          />

          {/* Image Analysis Panel */}
          {analysis && files.length === 1 && (
            <div className="ic-analysis glass mt-4">
              <h4><Icon name="info" size={14} /> Image Analysis</h4>
              <div className="ic-analysis-grid">
                <span>Dimensions: <b>{analysis.width}×{analysis.height}px</b></span>
                <span>Colors: <b>~{analysis.estimatedColors.toLocaleString()}</b></span>
                <span>Type: <b>{analysis.isPhotographic ? 'Photographic' : 'Graphic/Illustration'}</b></span>
                <span>Alpha: <b>{analysis.hasAlpha ? 'Yes' : 'No'}</b></span>
                <span>Format: <b>{analysis.fileType.split('/')[1]?.toUpperCase()}</b></span>
                <span>Size: <b>{formatBytes(files[0].size)}</b></span>
              </div>
              {mode === 'auto' && (
                <p className="ic-auto-tip mt-2">
                  <Icon name="sparkles" size={12} /> AI recommends: <b>{getAutoSettings(analysis).format.toUpperCase()}</b> at quality <b>{getAutoSettings(analysis).quality}</b>
                </p>
              )}
            </div>
          )}

          {/* Privacy badge */}
          <div className="ic-privacy-badge mt-3">
            <Icon name="shield" size={14} /> Your images never leave your device — 100% local processing
          </div>
        </div>

        {/* Right: Options panel */}
        <div className="options-panel">
          <h3>Compression Settings</h3>

          {/* Mode selector */}
          <div className="field">
            <label>Mode</label>
            <div className="ic-mode-grid">
              {(['auto', 'lossless', 'balanced', 'aggressive', 'custom', 'target-size'] as CompressionMode[]).map((m) => (
                <button
                  key={m}
                  className={`ic-mode-btn ${mode === m ? 'active' : ''}`}
                  onClick={() => {
                    setMode(m);
                    if (m === 'auto' && analysis) {
                      const s = getAutoSettings(analysis);
                      setFormat(s.format);
                      setQuality(s.quality);
                    }
                  }}
                >
                  {m === 'auto' && <Icon name="sparkles" size={12} />}
                  {m === 'target-size' ? 'Target Size' : m.charAt(0).toUpperCase() + m.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Format selector */}
          <div className="field">
            <label>Output Format</label>
            <select value={format} onChange={(e) => setFormat(e.target.value as OutputFormat)}>
              <option value="original">Keep Original</option>
              <option value="jpeg">JPEG (MozJPEG)</option>
              <option value="png">PNG (OxiPNG)</option>
              <option value="webp">WebP</option>
              <option value="avif">AVIF (Best compression)</option>
            </select>
          </div>

          {/* Quality slider */}
          {mode !== 'lossless' && mode !== 'target-size' && (
            <div className="field">
              <label>Quality <span className="range-value">{quality}%</span></label>
              <input type="range" min={1} max={100} value={quality} onChange={(e) => setQuality(+e.target.value)} />
              <div className="ic-quality-labels">
                <span>Smallest</span>
                <span>Best Quality</span>
              </div>
            </div>
          )}

          {/* Target size */}
          {mode === 'target-size' && (
            <div className="field">
              <label>Target File Size</label>
              <div className="ic-target-row">
                <input type="number" min={5} max={10240} value={targetSize} onChange={(e) => setTargetSize(+e.target.value)} />
                <select defaultValue="KB">
                  <option value="KB">KB</option>
                </select>
              </div>
              <div className="ic-target-presets">
                {[10, 20, 30, 50, 100, 200, 500, 1024].map((s) => (
                  <button key={s} className={`ic-chip ${targetSize === s ? 'active' : ''}`} onClick={() => setTargetSize(s)}>
                    {s >= 1024 ? `${s / 1024}MB` : `${s}KB`}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Effort (AVIF/WebP) */}
          {format === 'avif' && mode === 'custom' && (
            <div className="field">
              <label>Encoding Effort <span className="range-value">{effort}/10</span></label>
              <input type="range" min={1} max={10} value={effort} onChange={(e) => setEffort(+e.target.value)} />
              <div className="ic-quality-labels">
                <span>Faster</span>
                <span>Better compression</span>
              </div>
            </div>
          )}

          {/* Resize */}
          <details className="ic-advanced-section">
            <summary><Icon name="scaling" size={14} /> Resize</summary>
            <label className="checkbox-row mt-2">
              <input type="checkbox" checked={enableResize} onChange={(e) => setEnableResize(e.target.checked)} />
              Enable resize
            </label>
            {enableResize && (
              <div className="field-row mt-2">
                <div className="field"><label>Width (px)</label><input type="number" placeholder="Auto" value={resizeWidth} onChange={(e) => setResizeWidth(e.target.value)} /></div>
                <div className="field"><label>Height (px)</label><input type="number" placeholder="Auto" value={resizeHeight} onChange={(e) => setResizeHeight(e.target.value)} /></div>
              </div>
            )}
          </details>

          {/* Metadata */}
          <details className="ic-advanced-section">
            <summary><Icon name="info" size={14} /> Metadata / EXIF</summary>
            <label className="checkbox-row mt-2">
              <input type="checkbox" checked={stripMetadata} onChange={(e) => setStripMetadata(e.target.checked)} />
              Strip metadata (GPS, camera, timestamps)
            </label>
            <p className="muted" style={{ fontSize: 12, marginTop: 4 }}>Removes EXIF data, reduces size by 5-20%, protects privacy</p>
          </details>

          {/* AI Smart Analysis */}
          <details className="ic-advanced-section">
            <summary><Icon name="sparkles" size={14} /> AI Smart Analysis</summary>
            <div className="mt-2">
              <button
                className="btn btn-ghost btn-sm"
                disabled={files.length === 0 || aiLoading}
                onClick={() => void runAIAnalysis()}
                style={{ width: '100%' }}
              >
                <Icon name="sparkles" size={14} /> {aiLoading ? 'Analyzing...' : 'Analyze & Recommend Settings'}
              </button>
              {aiAnalysis && (
                <div className="ic-ai-result mt-2">
                  <div className="ic-ai-badge">{aiAnalysis.contentType.replace('-', ' ')}</div>
                  <p className="muted" style={{ fontSize: 12, marginTop: 6 }}>{aiAnalysis.explanation}</p>
                  <div className="ic-ai-tags mt-2">
                    {aiAnalysis.hasFaces && <span className="ic-chip active">Faces detected</span>}
                    {aiAnalysis.hasText && <span className="ic-chip active">Text detected</span>}
                    <span className="ic-chip">{aiAnalysis.complexity} complexity</span>
                    <span className="ic-chip active">{aiAnalysis.recommendedFormat.toUpperCase()} @ {aiAnalysis.recommendedQuality}%</span>
                  </div>
                </div>
              )}
            </div>
          </details>

          {/* Presets */}
          <details className="ic-advanced-section">
            <summary><Icon name="bookmark" size={14} /> Presets</summary>
            <div className="field mt-2">
              <label>Preset Type</label>
              <select value={presetType} onChange={(e) => setPresetType(e.target.value as typeof presetType)}>
                <option value="none">None (Custom)</option>
                <option value="social">Social Media</option>
                <option value="gov">Government / Exam</option>
              </select>
            </div>

            {presetType === 'social' && (
              <div className="field">
                <label>Platform & Size</label>
                <select value={selectedSocial} onChange={(e) => setSelectedSocial(e.target.value)}>
                  <option value="">Select preset...</option>
                  {Array.from(getPresetsByPlatform().entries()).map(([platform, presets]) => (
                    <optgroup key={platform} label={platform}>
                      {presets.map((p) => (
                        <option key={p.id} value={p.id}>{p.label}</option>
                      ))}
                    </optgroup>
                  ))}
                </select>
              </div>
            )}

            {presetType === 'gov' && (
              <div className="field">
                <label>Document Type</label>
                <select value={selectedGov} onChange={(e) => setSelectedGov(e.target.value)}>
                  <option value="">Select preset...</option>
                  {govPresets.map((p) => (
                    <option key={p.id} value={p.id}>{p.label} ({p.width}×{p.height}, ≤{p.maxKB}KB)</option>
                  ))}
                </select>
                {selectedGov && (
                  <p className="muted mt-1" style={{ fontSize: 12 }}>
                    {govPresets.find((p) => p.id === selectedGov)?.description}
                  </p>
                )}
              </div>
            )}
          </details>

          {/* Responsive sizes (for responsive tab) */}
          {activeTab === 'responsive' && (
            <div className="field">
              <label>Output Sizes (px width)</label>
              <div className="ic-responsive-sizes">
                {responsiveSizes.map((s) => (
                  <label key={s} className="checkbox-row">
                    <input
                      type="checkbox"
                      checked={selectedSizes.includes(s)}
                      onChange={(e) => {
                        setSelectedSizes(e.target.checked
                          ? [...selectedSizes, s].sort((a, b) => a - b)
                          : selectedSizes.filter((x) => x !== s));
                      }}
                    />
                    {s}px {s <= 640 ? '(mobile)' : s <= 1024 ? '(tablet)' : s <= 1920 ? '(desktop)' : '(retina/4K)'}
                  </label>
                ))}
              </div>
            </div>
          )}

          {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}

          {/* Action button */}
          {activeTab === 'compress' && (
            <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void processAll()}>
              <Icon name="zap" size={16} /> Compress {files.length > 1 ? `${files.length} Images` : 'Now'}
            </button>
          )}
          {activeTab === 'compare' && (
            <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void runComparison()}>
              <Icon name="columns" size={16} /> Compare All Codecs
            </button>
          )}
          {activeTab === 'responsive' && (
            <button className="btn btn-primary" disabled={files.length === 0 || selectedSizes.length === 0} onClick={() => void processResponsive()}>
              <Icon name="smartphone" size={16} /> Generate {selectedSizes.length} Sizes
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
