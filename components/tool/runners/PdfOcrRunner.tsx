'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, Processing, ErrorBox, OutputBlock, useToolPhase } from '../shared';
import { renderPdfPages } from '@/lib/pdf';
import { runOcrOnCanvas, analyzeDocument, applyEnhancements, DEFAULT_OCR_OPTIONS, type OcrRunOptions } from '@/lib/engines/ocr-engine';
import Icon from '../../Icon';

export default function PdfOcrRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset, progress, setProgress } = useToolPhase();
  const [files, setFiles] = useState<File[]>([]);
  const [text, setText] = useState('');
  const [options, setOptions] = useState<OcrRunOptions>(DEFAULT_OCR_OPTIONS);
  const [status, setStatus] = useState('Recognizing text...');

  const run = async () => {
    const file = files[0];
    if (!file) return;
    setPhase('working');
    try {
      setStatus('Rendering PDF pages...');
      const pages = await renderPdfPages(file, 2);
      const detection = await analyzeDocument(file);
      let result = '';

      for (let i = 0; i < pages.length; i++) {
        setStatus(`OCR page ${i + 1} of ${pages.length}...`);
        const enhanced = applyEnhancements(pages[i].canvas, options.enhancement);
        const pageResult = await runOcrOnCanvas(
          enhanced,
          `${file.name} page ${i + 1}`,
          detection,
          options,
          (p) => setProgress((i + p) / pages.length),
        );
        result += `--- Page ${i + 1} ---\n${pageResult.text}\n\n`;
      }

      setText(result.trim() || '(No text detected)');
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => { reset(); setFiles([]); setText(''); };

  if (phase === 'working') return <Processing label={status} progress={progress} />;
  if (phase === 'done') {
    return (
      <div className="result-box">
        <span className="result-badge"><Icon name="check-circle" size={16} /> Text extracted</span>
        <OutputBlock text={text} filename="extracted-text.txt" />
        <button className="btn btn-ghost" onClick={resetAll}><Icon name="refresh" size={15} /> Process Another File</button>
      </div>
    );
  }

  return (
    <div className="workspace-grid">
      <div><FileDrop accept={tool.accept} files={files} onFiles={setFiles} /></div>
      <div className="options-panel">
        <h3>PDF OCR Options</h3>
        <div className="field">
          <label>Language</label>
          <select value={options.lang} onChange={(e) => setOptions((o) => ({ ...o, lang: e.target.value }))}>
            <option value="eng">English</option>
            <option value="hin">Hindi</option>
            <option value="ben">Bengali</option>
            <option value="spa">Spanish</option>
            <option value="fra">French</option>
            <option value="deu">German</option>
            <option value="ara">Arabic</option>
            <option value="chi_sim">Chinese (Simplified)</option>
          </select>
        </div>
        <label className="checkbox-row">
          <input type="checkbox" checked={options.aiRepair} onChange={(e) => setOptions((o) => ({ ...o, aiRepair: e.target.checked }))} />
          AI Indic text repair
        </label>
        <label className="checkbox-row">
          <input type="checkbox" checked={options.enhancement.autoCrop} onChange={(e) => setOptions((o) => ({ ...o, enhancement: { ...o.enhancement, autoCrop: e.target.checked } }))} />
          Auto enhance pages
        </label>
        <p className="muted" style={{ fontSize: 13 }}>OCR runs 100% in your browser — files never leave your device.</p>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void run()}>Extract Text</button>
      </div>
    </div>
  );
}
