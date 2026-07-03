'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { OutputBlock, ErrorBox } from '../shared';
import Icon from '../../Icon';

export default function DevRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [input, setInput] = useState('');
  const [output, setOutput] = useState('');
  const [error, setError] = useState('');

  // base64/url direction
  const [dir, setDir] = useState<'encode' | 'decode'>('encode');
  // uuid
  const [count, setCount] = useState(5);
  // api tester
  const [method, setMethod] = useState('GET');
  const [url, setUrl] = useState('https://api.github.com/repos/vercel/next.js');
  const [reqHeaders, setReqHeaders] = useState('');
  const [reqBody, setReqBody] = useState('');
  const [busy, setBusy] = useState(false);

  const run = async () => {
    setError('');
    try {
      if (mode === 'json-format') {
        setOutput(JSON.stringify(JSON.parse(input), null, 2));
      } else if (mode === 'json-validate') {
        try {
          JSON.parse(input);
          setOutput('✓ Valid JSON — no syntax errors found.');
        } catch (e) {
          setOutput(`✗ Invalid JSON:\n${e instanceof Error ? e.message : String(e)}`);
        }
      } else if (mode === 'base64') {
        if (dir === 'encode') {
          setOutput(btoa(unescape(encodeURIComponent(input))));
        } else {
          setOutput(decodeURIComponent(escape(atob(input.trim()))));
        }
      } else if (mode === 'url') {
        setOutput(dir === 'encode' ? encodeURIComponent(input) : decodeURIComponent(input));
      } else if (mode === 'jwt') {
        const parts = input.trim().split('.');
        if (parts.length < 2) throw new Error('Not a valid JWT (expected header.payload.signature).');
        const decode = (s: string) => JSON.parse(decodeURIComponent(escape(atob(s.replace(/-/g, '+').replace(/_/g, '/')))));
        const header = decode(parts[0]);
        const payload = decode(parts[1]);
        let extra = '';
        if (payload.exp) {
          const exp = new Date(payload.exp * 1000);
          extra = `\n\n⏰ Expires: ${exp.toLocaleString()} (${exp.getTime() < Date.now() ? 'EXPIRED' : 'valid'})`;
        }
        setOutput(`HEADER:\n${JSON.stringify(header, null, 2)}\n\nPAYLOAD:\n${JSON.stringify(payload, null, 2)}${extra}`);
      } else if (mode === 'uuid') {
        setOutput(Array.from({ length: Math.min(100, Math.max(1, count)) }, () => crypto.randomUUID()).join('\n'));
      } else if (mode === 'api-test') {
        setBusy(true);
        const headers: Record<string, string> = {};
        for (const line of reqHeaders.split('\n')) {
          const idx = line.indexOf(':');
          if (idx > 0) headers[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
        }
        const t0 = performance.now();
        const res = await fetch(url, {
          method,
          headers,
          body: ['GET', 'HEAD'].includes(method) ? undefined : reqBody || undefined,
        });
        const ms = Math.round(performance.now() - t0);
        const text = await res.text();
        let pretty = text;
        try { pretty = JSON.stringify(JSON.parse(text), null, 2); } catch { /* not JSON */ }
        const headerLines = Array.from(res.headers.entries()).map(([k, v]) => `${k}: ${v}`).join('\n');
        setOutput(`${res.status} ${res.statusText} · ${ms}ms\n\n--- HEADERS ---\n${headerLines}\n\n--- BODY ---\n${pretty.slice(0, 20000)}`);
        setBusy(false);
      }
    } catch (e) {
      setBusy(false);
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  if (mode === 'api-test') {
    return (
      <div className="workspace-grid">
        <div className="options-panel">
          <div className="field-row">
            <div className="field" style={{ maxWidth: 120 }}>
              <label>Method</label>
              <select value={method} onChange={(e) => setMethod(e.target.value)}>
                {['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'].map((m) => <option key={m}>{m}</option>)}
              </select>
            </div>
            <div className="field"><label>URL</label><input value={url} onChange={(e) => setUrl(e.target.value)} /></div>
          </div>
          <div className="field"><label>Headers (one per line: Key: Value)</label><textarea value={reqHeaders} style={{ minHeight: 70 }} placeholder="Authorization: Bearer ..." onChange={(e) => setReqHeaders(e.target.value)} /></div>
          {!['GET', 'HEAD'].includes(method) && (
            <div className="field"><label>Body</label><textarea value={reqBody} placeholder='{"key": "value"}' onChange={(e) => setReqBody(e.target.value)} /></div>
          )}
          {error && <ErrorBox message={error} />}
          <button className="btn btn-primary" disabled={busy} onClick={() => void run()}><Icon name="send" size={15} /> {busy ? 'Sending...' : 'Send Request'}</button>
          <p className="muted" style={{ fontSize: 12 }}>Note: browser CORS rules apply — public APIs work best.</p>
        </div>
        <div>{output ? <OutputBlock text={output} filename="response.txt" /> : <div className="output-area" style={{ minHeight: 260, color: 'var(--text-muted)' }}>Response will appear here.</div>}</div>
      </div>
    );
  }

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {mode !== 'uuid' && (
          <div className="field">
            <label>Input</label>
            <textarea
              value={input}
              style={{ minHeight: 180 }}
              placeholder={mode.startsWith('json') ? '{"paste": "your JSON here"}' : mode === 'jwt' ? 'eyJhbGciOi...' : 'Paste text here...'}
              onChange={(e) => setInput(e.target.value)}
            />
          </div>
        )}
        {(mode === 'base64' || mode === 'url') && (
          <div className="field"><label>Direction</label>
            <select value={dir} onChange={(e) => setDir(e.target.value as 'encode' | 'decode')}>
              <option value="encode">Encode</option>
              <option value="decode">Decode</option>
            </select></div>
        )}
        {mode === 'uuid' && (
          <div className="field"><label>How many UUIDs?</label><input type="number" min={1} max={100} value={count} onChange={(e) => setCount(+e.target.value)} /></div>
        )}
        {error && <ErrorBox message={error} />}
        <button className="btn btn-primary" onClick={() => void run()}>
          {mode === 'json-format' ? 'Format JSON' : mode === 'json-validate' ? 'Validate' : mode === 'uuid' ? 'Generate' : dir === 'encode' ? 'Encode' : 'Decode'}
        </button>
      </div>
      <div>{output ? <OutputBlock text={output} filename={`${tool.slug}.txt`} /> : <div className="output-area" style={{ minHeight: 220, color: 'var(--text-muted)' }}>Output will appear here.</div>}</div>
    </div>
  );
}
