'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import Icon from '@/components/Icon';
import { formatBytes } from '@/lib/download';
import {
  PAN_SPECS,
  DEFAULT_EDIT,
  autoEditFromFace,
  complianceScore,
  downloadZip,
  generatePrintSheet,
  prepareSourceCanvas,
  processPanFile,
  renderToSpec,
  validateCompliance,
  type ComplianceItem,
  type EditState,
  type FaceAnalysis,
  type PanFileType,
  type PanPortal,
} from '@/lib/gov-photo';
import { ErrorBox, Processing, useToolPhase } from '../shared';

type Step = 'portal' | 'type' | 'upload' | 'edit' | 'result';

interface BatchItem {
  id: string;
  file: File;
  name: string;
  blob: Blob;
  preview: string;
  compliance: ComplianceItem[];
  ready: boolean;
}

const LABELS = {
  en: {
    portal: 'Select PAN Portal',
    portalSub: 'Choose where you are applying — specs differ between NSDL and UTI',
    nsdl: 'NSDL (Protean)',
    nsdlSub: 'onlineservices.protean.co.in',
    uti: 'UTI (UTIITSL)',
    utiSub: 'utiitsl.com / pan.utiitsl.com',
    fileType: 'What are you resizing?',
    photo: 'Photo',
    signature: 'Signature',
    document: 'Document',
    upload: 'Upload your file',
    uploadSub: 'JPG, PNG, WebP, HEIC — processed in your browser only',
    camera: 'Capture from Camera',
    batch: 'Batch Mode (CSC)',
    aiBg: 'AI white background (photo)',
    back: 'Back',
    continue: 'Continue',
    download: 'Download',
    printSheet: 'Print Sheet (A4)',
    processAnother: 'Process Another',
    downloadAll: 'Download All (ZIP)',
    compliance: 'Compliance Checklist',
    ready: 'Portal Ready',
    notReady: 'Review warnings before upload',
    compare: 'Before / After',
    resetAi: 'Reset AI crop',
    step: 'Step',
    of: 'of',
    hindi: 'हिंदी',
    english: 'English',
    editTitle: 'Edit & Preview',
    editSub: 'Drag sliders to fine-tune — compliance updates live',
    panX: 'Horizontal position',
    panY: 'Vertical position',
    zoom: 'Zoom',
    rotation: 'Rotation',
    brightness: 'Brightness',
    contrast: 'Contrast',
    generate: 'Generate File',
    working: 'AI processing your file...',
    workingBg: 'Removing background with AI...',
    workingFace: 'Detecting face & auto-cropping...',
  },
  hi: {
    portal: 'PAN पोर्टल चुनें',
    portalSub: 'जहाँ आवेदन कर रहे हैं वहाँ चुनें — NSDL और UTI के specs अलग हैं',
    nsdl: 'NSDL (Protean)',
    nsdlSub: 'onlineservices.protean.co.in',
    uti: 'UTI (UTIITSL)',
    utiSub: 'utiitsl.com / pan.utiitsl.com',
    fileType: 'क्या resize करना है?',
    photo: 'फ़ोटो',
    signature: 'हस्ताक्षर',
    document: 'दस्तावेज़',
    upload: 'फ़ाइल अपलोड करें',
    uploadSub: 'JPG, PNG, WebP, HEIC — केवल ब्राउज़र में प्रोसेस',
    camera: 'कैमरा से लें',
    batch: 'बैच मोड (CSC)',
    aiBg: 'AI सफेद पृष्ठभूमि (फ़ोटो)',
    back: 'वापस',
    continue: 'आगे',
    download: 'डाउनलोड',
    printSheet: 'प्रिंट शीट (A4)',
    processAnother: 'एक और प्रोसेस करें',
    downloadAll: 'सभी डाउनलोड (ZIP)',
    compliance: 'अनुपालन जाँच',
    ready: 'पोर्टल के लिए तैयार',
    notReady: 'अपलोड से पहले चेतावनियाँ देखें',
    compare: 'पहले / बाद',
    resetAi: 'AI crop रीसेट',
    step: 'चरण',
    of: '/',
    hindi: 'हिंदी',
    english: 'English',
    editTitle: 'संपादन और पूर्वावलोकन',
    editSub: 'स्लाइडर से fine-tune करें — compliance live अपडेट',
    panX: 'क्षैतिज स्थिति',
    panY: 'लंबवत स्थिति',
    zoom: 'ज़ूम',
    rotation: 'घुमाव',
    brightness: 'चमक',
    contrast: 'कंट्रास्ट',
    generate: 'फ़ाइल बनाएँ',
    working: 'AI आपकी फ़ाइल प्रोसेस कर रहा है...',
    workingBg: 'AI से पृष्ठभूमि हटा रहे हैं...',
    workingFace: 'चेहरा पहचान और auto-crop...',
  },
};

export default function GovPhotoRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset: resetPhase } = useToolPhase();
  const [step, setStep] = useState<Step>('portal');
  const [portal, setPortal] = useState<PanPortal | null>(null);
  const [fileType, setFileType] = useState<PanFileType | null>(null);
  const [lang, setLang] = useState<'en' | 'hi'>('en');
  const [batchMode, setBatchMode] = useState(false);
  const [removeBg, setRemoveBg] = useState(true);
  const [status, setStatus] = useState('');

  const [sourceFile, setSourceFile] = useState<File | null>(null);
  const [sourceCanvas, setSourceCanvas] = useState<HTMLCanvasElement | null>(null);
  const [face, setFace] = useState<FaceAnalysis | null>(null);
  const [edit, setEdit] = useState<EditState>(DEFAULT_EDIT);
  const [originalPreview, setOriginalPreview] = useState('');
  const [comparePos, setComparePos] = useState(50);

  const [resultBlob, setResultBlob] = useState<Blob | null>(null);
  const [resultName, setResultName] = useState('');
  const [resultPreview, setResultPreview] = useState('');
  const [resultCanvas, setResultCanvas] = useState<HTMLCanvasElement | null>(null);
  const [compliance, setCompliance] = useState<ComplianceItem[]>([]);
  const [beforeSize, setBeforeSize] = useState(0);
  const [batchItems, setBatchItems] = useState<BatchItem[]>([]);

  const previewRef = useRef<HTMLCanvasElement>(null);
  const liveComplianceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [cameraOpen, setCameraOpen] = useState(false);
  const streamRef = useRef<MediaStream | null>(null);

  const t = LABELS[lang];
  const spec = portal && fileType ? PAN_SPECS[portal][fileType] : null;
  const score = complianceScore(compliance);

  const stepNum = step === 'portal' ? 1 : step === 'type' ? 2 : step === 'upload' ? 3 : step === 'edit' ? 3 : 4;

  const stopCamera = useCallback(() => {
    streamRef.current?.getTracks().forEach((tr) => tr.stop());
    streamRef.current = null;
    setCameraOpen(false);
  }, []);

  useEffect(() => () => stopCamera(), [stopCamera]);

  const updateLivePreview = useCallback(async () => {
    if (!sourceCanvas || !spec || fileType === 'document') return;
    const rendered = renderToSpec(sourceCanvas, spec, edit);
    const prev = previewRef.current;
    if (prev) {
      prev.width = rendered.width;
      prev.height = rendered.height;
      prev.getContext('2d')!.drawImage(rendered, 0, 0);
    }
    if (liveComplianceTimer.current) clearTimeout(liveComplianceTimer.current);
    liveComplianceTimer.current = setTimeout(async () => {
      const blob = await new Promise<Blob>((res) =>
        rendered.toBlob((b) => res(b!), 'image/jpeg', 0.85),
      );
      const items = await validateCompliance(rendered, blob, spec, fileType!, face, {
        edit,
        sourceW: sourceCanvas.width,
        sourceH: sourceCanvas.height,
      });
      setCompliance(items);
    }, 200);
  }, [sourceCanvas, spec, edit, fileType, face]);

  useEffect(() => {
    if (step === 'edit') void updateLivePreview();
  }, [step, edit, updateLivePreview]);

  const ingestFile = async (file: File) => {
    if (!portal || !fileType) return;
    setPhase('working');
    setSourceFile(file);
    setBeforeSize(file.size);
    setOriginalPreview(URL.createObjectURL(file));
    try {
      setStatus(t.working);
      if (fileType === 'document') {
        const { canvas } = await prepareSourceCanvas(file, fileType, false);
        setSourceCanvas(canvas);
        setFace(null);
        setEdit(DEFAULT_EDIT);
        setStep('edit');
        setPhase('idle');
        return;
      }
      setStatus(t.workingFace);
      const { canvas, face: f } = await prepareSourceCanvas(file, fileType, removeBg && fileType === 'photo');
      setSourceCanvas(canvas);
      setFace(f);
      if (f && fileType === 'photo') {
        setEdit(autoEditFromFace(f, canvas.width, canvas.height, PAN_SPECS[portal][fileType]));
      } else {
        setEdit(DEFAULT_EDIT);
      }
      setStep('edit');
      setPhase('idle');
    } catch (e) {
      fail(e);
    }
  };

  const runGenerate = async () => {
    if (!portal || !fileType || !sourceFile || !sourceCanvas) return;
    setPhase('working');
    setStatus(t.generate);
    try {
      const out = await processPanFile({
        file: sourceFile,
        portal,
        fileType,
        edit,
        removeBackground: removeBg,
        face,
        sourceCanvas,
      });
      setResultBlob(out.blob);
      setResultName(out.name);
      setResultPreview(URL.createObjectURL(out.blob));
      setResultCanvas(out.canvas);
      setCompliance(out.compliance);

      if (batchMode) {
        setBatchItems((prev) => [
          ...prev,
          {
            id: `${Date.now()}-${Math.random()}`,
            file: sourceFile,
            name: out.name,
            blob: out.blob,
            preview: URL.createObjectURL(out.blob),
            compliance: out.compliance,
            ready: complianceScore(out.compliance).ready,
          },
        ]);
      }
      setStep('result');
      setPhase('idle');
    } catch (e) {
      fail(e);
    }
  };

  const runBatchFiles = async (files: File[]) => {
    if (!portal || !fileType) return;
    setPhase('working');
    const results: BatchItem[] = [];
    try {
      for (let i = 0; i < files.length; i++) {
        setStatus(`${t.working} (${i + 1}/${files.length})`);
        const file = files[i]!;
        const { canvas, face: f } = await prepareSourceCanvas(file, fileType, removeBg && fileType === 'photo');
        const eState =
          f && fileType === 'photo'
            ? autoEditFromFace(f, canvas.width, canvas.height, PAN_SPECS[portal][fileType])
            : DEFAULT_EDIT;
        const out = await processPanFile({
          file,
          portal,
          fileType,
          edit: eState,
          removeBackground: removeBg,
          face: f,
          sourceCanvas: canvas,
        });
        results.push({
          id: `${Date.now()}-${i}`,
          file,
          name: out.name.replace('.jpg', `-${i + 1}.jpg`),
          blob: out.blob,
          preview: URL.createObjectURL(out.blob),
          compliance: out.compliance,
          ready: complianceScore(out.compliance).ready,
        });
      }
      setBatchItems(results);
      if (results[0]) {
        setResultBlob(results[0].blob);
        setResultName(results[0].name);
        setResultPreview(results[0].preview);
        setCompliance(results[0].compliance);
      }
      setStep('result');
      setPhase('idle');
    } catch (e) {
      fail(e);
    }
  };

  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 960 } },
        audio: false,
      });
      streamRef.current = stream;
      setCameraOpen(true);
      requestAnimationFrame(() => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          void videoRef.current.play();
        }
      });
    } catch {
      fail(new Error('Camera access denied. Please upload a photo instead.'));
    }
  };

  const snapCamera = () => {
    const video = videoRef.current;
    if (!video) return;
    const [c, ctx] = (() => {
      const canvas = document.createElement('canvas');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      return [canvas, canvas.getContext('2d')!] as const;
    })();
    ctx.drawImage(video, 0, 0);
    c.toBlob((b: Blob | null) => {
      if (!b) return;
      stopCamera();
      void ingestFile(new File([b], 'camera-capture.jpg', { type: 'image/jpeg' }));
    }, 'image/jpeg', 0.92);
  };

  const download = (blob: Blob, name: string) => {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 30_000);
  };

  const downloadPrintSheet = async () => {
    if (!resultCanvas) return;
    const sheet = await generatePrintSheet(resultCanvas, 8);
    download(sheet, `pan-print-sheet-${portal}.jpg`);
  };

  const downloadAllZip = async () => {
    const files = batchItems.map((b) => ({ name: b.name, blob: b.blob }));
    if (files.length === 0 && resultBlob) files.push({ name: resultName, blob: resultBlob });
    const zip = await downloadZip(files);
    download(zip, `pan-batch-${portal}.zip`);
  };

  const resetAll = () => {
    resetPhase();
    setStep('portal');
    setPortal(null);
    setFileType(null);
    setSourceFile(null);
    setSourceCanvas(null);
    setFace(null);
    setEdit(DEFAULT_EDIT);
    setResultBlob(null);
    setResultPreview('');
    setCompliance([]);
    setBatchItems([]);
    stopCamera();
  };

  if (phase === 'working') return <Processing label={status} />;

  return (
    <div className="gov-photo-tool">
      <div className="gov-photo-toolbar">
        <div className="gov-photo-steps">
          <span className="muted">{t.step} {stepNum} {t.of} 4</span>
        </div>
        <div className="gov-photo-toolbar-actions">
          <label className="checkbox-row gov-batch-toggle">
            <input type="checkbox" checked={batchMode} onChange={(e) => setBatchMode(e.target.checked)} />
            {t.batch}
          </label>
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setLang(lang === 'en' ? 'hi' : 'en')}>
            <Icon name="globe" size={14} /> {lang === 'en' ? t.hindi : t.english}
          </button>
        </div>
      </div>

      {phase === 'error' && <ErrorBox message={error} onRetry={resetPhase} />}

      {step === 'portal' && (
        <section className="gov-step">
          <h3>{t.portal}</h3>
          <p className="muted">{t.portalSub}</p>
          <div className="gov-portal-grid">
            {(['nsdl', 'uti'] as PanPortal[]).map((p) => (
              <button
                key={p}
                type="button"
                className={`gov-choice-card glass ${portal === p ? 'active' : ''}`}
                onClick={() => setPortal(p)}
              >
                <Icon name="landmark" size={28} />
                <b>{p === 'nsdl' ? t.nsdl : t.uti}</b>
                <span>{p === 'nsdl' ? t.nsdlSub : t.utiSub}</span>
              </button>
            ))}
          </div>
          <button type="button" className="btn btn-primary mt-4" disabled={!portal} onClick={() => setStep('type')}>
            {t.continue} <Icon name="arrow-right" size={16} />
          </button>
        </section>
      )}

      {step === 'type' && portal && (
        <section className="gov-step">
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setStep('portal')}>← {t.back}</button>
          <h3>{t.fileType}</h3>
          <div className="gov-type-grid">
            {(['photo', 'signature', 'document'] as PanFileType[]).map((ft) => {
              const s = PAN_SPECS[portal][ft];
              return (
                <button
                  key={ft}
                  type="button"
                  className={`gov-choice-card glass ${fileType === ft ? 'active' : ''}`}
                  onClick={() => setFileType(ft)}
                >
                  <Icon name={ft === 'signature' ? 'pen' : ft === 'document' ? 'file-text' : 'user-square'} size={26} />
                  <b>{ft === 'photo' ? t.photo : ft === 'signature' ? t.signature : t.document}</b>
                  <span>{s.w}×{s.h}px · {s.minKB}–{s.maxKB} KB · {s.dpi} DPI</span>
                  <span className="muted">{s.cmLabel}</span>
                </button>
              );
            })}
          </div>
          <button type="button" className="btn btn-primary mt-4" disabled={!fileType} onClick={() => setStep('upload')}>
            {t.continue} <Icon name="arrow-right" size={16} />
          </button>
        </section>
      )}

      {step === 'upload' && portal && fileType && (
        <section className="gov-step">
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setStep('type')}>← {t.back}</button>
          <h3>{t.upload}</h3>
          <p className="muted">{t.uploadSub}</p>

          {fileType === 'photo' && (
            <label className="checkbox-row mt-2">
              <input type="checkbox" checked={removeBg} onChange={(e) => setRemoveBg(e.target.checked)} />
              {t.aiBg}
            </label>
          )}

          <div
            className="dropzone mt-4"
            onClick={() => document.getElementById('gov-file-input')?.click()}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const f = e.dataTransfer.files;
              if (!f.length) return;
              if (batchMode) void runBatchFiles(Array.from(f));
              else void ingestFile(f[0]!);
            }}
            role="button"
            tabIndex={0}
          >
            <span className="dropzone-icon"><Icon name="upload" size={26} /></span>
            <b>{batchMode ? 'Drop multiple files' : 'Drag & drop or click to upload'}</b>
            <span>{fileType === 'document' ? 'PDF, JPG, PNG' : 'JPG, PNG, WebP, HEIC'}</span>
          </div>
          <input
            id="gov-file-input"
            type="file"
            hidden
            accept={fileType === 'document' ? 'application/pdf,image/*' : 'image/*'}
            multiple={batchMode}
            onChange={(e) => {
              const f = e.target.files;
              if (!f?.length) return;
              if (batchMode) void runBatchFiles(Array.from(f));
              else void ingestFile(f[0]!);
              e.target.value = '';
            }}
          />

          {fileType !== 'document' && !batchMode && (
            <button type="button" className="btn btn-ghost mt-3" onClick={() => void startCamera()}>
              <Icon name="user-square" size={16} /> {t.camera}
            </button>
          )}

          {cameraOpen && (
            <div className="gov-camera-box glass mt-4">
              <video ref={videoRef} className="gov-camera-video" playsInline muted />
              <div className="gov-camera-guide" aria-hidden />
              <div className="gov-camera-actions">
                <button type="button" className="btn btn-primary" onClick={snapCamera}>Snap Photo</button>
                <button type="button" className="btn btn-ghost" onClick={stopCamera}>Cancel</button>
              </div>
            </div>
          )}
        </section>
      )}

      {step === 'edit' && portal && fileType && spec && sourceCanvas && (
        <section className="gov-step">
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setStep('upload')}>← {t.back}</button>
          <h3>{t.editTitle}</h3>
          <p className="muted">{t.editSub}</p>

          <div className="gov-edit-layout">
            <div className="gov-preview-panel glass">
              {fileType !== 'document' ? (
                <canvas ref={previewRef} className="gov-preview-canvas" />
              ) : (
                <div className="gov-doc-preview">
                  <Icon name="file-text" size={48} />
                  <p>{sourceFile?.name}</p>
                  <p className="muted">{formatBytes(sourceFile?.size || 0)}</p>
                </div>
              )}
              {originalPreview && fileType !== 'document' && (
                <div className="gov-compare mt-3">
                  <span className="muted">{t.compare}</span>
                  <input type="range" min={0} max={100} value={comparePos} onChange={(e) => setComparePos(+e.target.value)} />
                  <div className="gov-compare-view">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={originalPreview} alt="Before" style={{ clipPath: `inset(0 ${100 - comparePos}% 0 0)` }} />
                    <canvas
                      className="gov-compare-after"
                      ref={(el) => {
                        if (!el || !previewRef.current) return;
                        el.width = previewRef.current.width;
                        el.height = previewRef.current.height;
                        el.getContext('2d')?.drawImage(previewRef.current, 0, 0);
                      }}
                    />
                  </div>
                </div>
              )}
            </div>

            <div className="gov-controls-panel">
              {fileType !== 'document' && (
                <>
                  <div className="field">
                    <label>{t.panX}</label>
                    <input type="range" min={0} max={100} value={Math.round(edit.panX * 100)} onChange={(e) => setEdit({ ...edit, panX: +e.target.value / 100 })} />
                  </div>
                  <div className="field">
                    <label>{t.panY}</label>
                    <input type="range" min={0} max={100} value={Math.round(edit.panY * 100)} onChange={(e) => setEdit({ ...edit, panY: +e.target.value / 100 })} />
                  </div>
                  <div className="field">
                    <label>{t.zoom} <span className="range-value">{edit.zoom.toFixed(2)}×</span></label>
                    <input type="range" min={100} max={200} value={Math.round(edit.zoom * 100)} onChange={(e) => setEdit({ ...edit, zoom: +e.target.value / 100 })} />
                  </div>
                  <div className="field">
                    <label>{t.rotation}</label>
                    <select value={edit.rotation} onChange={(e) => setEdit({ ...edit, rotation: +e.target.value })}>
                      <option value={0}>0°</option>
                      <option value={90}>90°</option>
                      <option value={180}>180°</option>
                      <option value={270}>270°</option>
                    </select>
                  </div>
                  <div className="field">
                    <label>{t.brightness} <span className="range-value">{edit.brightness}%</span></label>
                    <input type="range" min={50} max={150} value={edit.brightness} onChange={(e) => setEdit({ ...edit, brightness: +e.target.value })} />
                  </div>
                  <div className="field">
                    <label>{t.contrast} <span className="range-value">{edit.contrast}%</span></label>
                    <input type="range" min={50} max={150} value={edit.contrast} onChange={(e) => setEdit({ ...edit, contrast: +e.target.value })} />
                  </div>
                  {face && (
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => setEdit(autoEditFromFace(face, sourceCanvas.width, sourceCanvas.height, spec))}>
                      <Icon name="refresh" size={14} /> {t.resetAi}
                    </button>
                  )}
                </>
              )}

              <div className="gov-compliance glass mt-3">
                <b>{t.compliance}</b>
                <ul className="gov-compliance-list">
                  {compliance.map((c) => (
                    <li key={c.id} className={`gov-check gov-check-${c.status}`}>
                      <span>{lang === 'hi' ? c.labelHi : c.label}</span>
                      {c.message && <small>{lang === 'hi' && c.messageHi ? c.messageHi : c.message}</small>}
                    </li>
                  ))}
                </ul>
                <span className={`gov-ready-badge ${score.ready ? 'pass' : 'warn'}`}>
                  {score.ready ? t.ready : t.notReady} ({score.pass}/{score.total})
                </span>
              </div>

              <button type="button" className="btn btn-primary mt-3" onClick={() => void runGenerate()}>
                {t.generate} <Icon name="download" size={16} />
              </button>
            </div>
          </div>
        </section>
      )}

      {step === 'result' && resultBlob && (
        <section className="gov-step gov-result">
          <span className={`gov-ready-badge ${score.ready ? 'pass' : 'warn'}`}>
            <Icon name={score.ready ? 'check-circle' : 'shield'} size={16} />
            {score.ready ? t.ready : t.notReady}
          </span>

          {resultPreview && fileType !== 'document' && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={resultPreview} alt="Result" className="result-preview" />
          )}

          {beforeSize > 0 && (
            <span className="size-compare">
              {formatBytes(beforeSize)} → <b>{formatBytes(resultBlob.size)}</b>
              {spec && ` · ${spec.w}×${spec.h}px · ${spec.dpi} DPI`}
            </span>
          )}

          <div className="result-actions">
            <button type="button" className="btn btn-primary" onClick={() => download(resultBlob, resultName)}>
              <Icon name="download" size={16} /> {t.download}
            </button>
            {fileType === 'photo' && resultCanvas && (
              <button type="button" className="btn btn-ghost" onClick={() => void downloadPrintSheet()}>
                <Icon name="copy" size={16} /> {t.printSheet}
              </button>
            )}
            {(batchItems.length > 1 || batchMode) && (
              <button type="button" className="btn btn-ghost" onClick={() => void downloadAllZip()}>
                <Icon name="download" size={16} /> {t.downloadAll}
              </button>
            )}
            <button type="button" className="btn btn-ghost" onClick={() => { setStep('upload'); setPhase('idle'); }}>
              <Icon name="refresh" size={15} /> {t.processAnother}
            </button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={resetAll}>Start Over</button>
          </div>

          {batchItems.length > 0 && (
            <div className="gov-batch-table glass mt-4">
              <table>
                <thead>
                  <tr><th>Preview</th><th>File</th><th>Status</th><th /></tr>
                </thead>
                <tbody>
                  {batchItems.map((b) => (
                    <tr key={b.id}>
                      <td>{/* eslint-disable-next-line @next/next/no-img-element */}<img src={b.preview} alt="" className="gov-batch-thumb" /></td>
                      <td>{b.name}<br /><span className="muted">{formatBytes(b.blob.size)}</span></td>
                      <td><span className={`gov-ready-badge ${b.ready ? 'pass' : 'warn'}`}>{b.ready ? 'Ready' : 'Review'}</span></td>
                      <td><button type="button" className="btn btn-ghost btn-sm" onClick={() => download(b.blob, b.name)}>↓</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <ul className="gov-compliance-list mt-4">
            {compliance.filter((c) => c.status !== 'skip').map((c) => (
              <li key={c.id} className={`gov-check gov-check-${c.status}`}>
                {lang === 'hi' ? c.labelHi : c.label}
                {c.message ? ` — ${c.message}` : ''}
              </li>
            ))}
          </ul>
        </section>
      )}

      <p className="muted mt-4" style={{ fontSize: 12 }}>
        {tool.name} · 100% browser-based · Files never uploaded to ToolNest servers
      </p>
    </div>
  );
}
