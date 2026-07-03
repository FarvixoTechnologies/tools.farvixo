'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, Processing, ErrorBox, ResultView, OutputBlock, useToolPhase, type ResultFile } from '../shared';
import { replaceExt } from '@/lib/download';

export default function FileConvertRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [files, setFiles] = useState<File[]>([]);
  const [results, setResults] = useState<ResultFile[]>([]);
  const [textIn, setTextIn] = useState('');
  const [textOut, setTextOut] = useState('');

  const mode = tool.mode;
  const isTextMode = mode === 'xml2json' || mode === 'json2xml';

  const run = async () => {
    setPhase('working');
    try {
      const out: ResultFile[] = [];

      if (mode === 'zip-create') {
        if (files.length === 0) throw new Error('Add at least one file.');
        const JSZip = (await import('jszip')).default;
        const zip = new JSZip();
        for (const f of files) zip.file(f.name, f);
        out.push({ name: 'archive.zip', blob: await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' }) });
      } else if (mode === 'zip-extract') {
        if (!files[0]) throw new Error('Add a ZIP file.');
        const JSZip = (await import('jszip')).default;
        const zip = await JSZip.loadAsync(await files[0].arrayBuffer());
        const entries = Object.values(zip.files).filter((f) => !f.dir);
        if (entries.length === 0) throw new Error('This ZIP appears to be empty.');
        for (const entry of entries.slice(0, 50)) {
          const blob = await entry.async('blob');
          out.push({ name: entry.name.split('/').pop() || entry.name, blob });
        }
      } else if (mode === 'csv2xlsx') {
        if (!files[0]) throw new Error('Add a CSV file.');
        const XLSX = await import('xlsx');
        const text = await files[0].text();
        const wb = XLSX.read(text, { type: 'string' });
        const buf = XLSX.write(wb, { bookType: 'xlsx', type: 'array' }) as ArrayBuffer;
        out.push({ name: replaceExt(files[0].name, 'xlsx'), blob: new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }) });
      } else if (mode === 'xlsx2csv') {
        if (!files[0]) throw new Error('Add an Excel file.');
        const XLSX = await import('xlsx');
        const wb = XLSX.read(await files[0].arrayBuffer(), { type: 'array' });
        for (const name of wb.SheetNames) {
          const csv = XLSX.utils.sheet_to_csv(wb.Sheets[name]);
          out.push({ name: `${files[0].name.replace(/\.[^.]+$/, '')}-${name}.csv`, blob: new Blob([csv], { type: 'text/csv' }) });
        }
      } else if (mode === 'xml2json') {
        const { XMLParser } = await import('fast-xml-parser');
        const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_' });
        const src = textIn || (files[0] ? await files[0].text() : '');
        if (!src.trim()) throw new Error('Paste XML or upload a file.');
        setTextOut(JSON.stringify(parser.parse(src), null, 2));
        setPhase('done');
        return;
      } else if (mode === 'json2xml') {
        const { XMLBuilder } = await import('fast-xml-parser');
        const builder = new XMLBuilder({ ignoreAttributes: false, attributeNamePrefix: '@_', format: true });
        const src = textIn || (files[0] ? await files[0].text() : '');
        if (!src.trim()) throw new Error('Paste JSON or upload a file.');
        const parsed = JSON.parse(src) as unknown;
        const wrapped = typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed) ? parsed : { root: parsed };
        setTextOut(`<?xml version="1.0" encoding="UTF-8"?>\n${builder.build(wrapped)}`);
        setPhase('done');
        return;
      }

      setResults(out);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  const resetAll = () => { reset(); setFiles([]); setResults([]); setTextOut(''); };

  if (phase === 'working') return <Processing />;

  if (isTextMode) {
    return (
      <div className="workspace-grid">
        <div className="options-panel">
          <div className="field">
            <label>{mode === 'xml2json' ? 'XML input' : 'JSON input'}</label>
            <textarea value={textIn} className="mono" style={{ minHeight: 220 }} placeholder={mode === 'xml2json' ? '<root><item>value</item></root>' : '{"root": {"item": "value"}}'} onChange={(e) => setTextIn(e.target.value)} />
          </div>
          {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
          <button className="btn btn-primary" onClick={() => void run()}>Convert Now</button>
        </div>
        <div>{textOut ? <OutputBlock text={textOut} filename={mode === 'xml2json' ? 'converted.json' : 'converted.xml'} /> : <div className="output-area" style={{ minHeight: 260, color: 'var(--text-muted)' }}>Output will appear here.</div>}</div>
      </div>
    );
  }

  if (phase === 'done') return <ResultView files={results} onReset={resetAll} />;

  return (
    <div className="workspace-grid">
      <div><FileDrop accept={tool.accept === '*/*' ? undefined : tool.accept} multiple={tool.multiple} files={files} onFiles={setFiles} /></div>
      <div className="options-panel">
        <h3>Options</h3>
        <p className="muted" style={{ fontSize: 13 }}>
          {mode === 'zip-create' && 'All selected files are packed into one compressed ZIP archive — entirely in your browser.'}
          {mode === 'zip-extract' && 'Extract up to 50 files from a ZIP archive. Each file downloads individually.'}
          {mode === 'csv2xlsx' && 'Your CSV becomes a proper Excel workbook (.xlsx).'}
          {mode === 'xlsx2csv' && 'Every sheet in the workbook is exported as a separate CSV file.'}
        </p>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={files.length === 0} onClick={() => void run()}>Convert Now</button>
      </div>
    </div>
  );
}
