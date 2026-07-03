'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { OutputBlock, ErrorBox } from '../shared';
import { downloadDataUrl } from '@/lib/download';
import Icon from '../../Icon';

const unitTable: Record<string, Record<string, number>> = {
  Length: { meter: 1, kilometer: 1000, centimeter: 0.01, millimeter: 0.001, mile: 1609.344, yard: 0.9144, foot: 0.3048, inch: 0.0254 },
  Weight: { kilogram: 1, gram: 0.001, tonne: 1000, pound: 0.453592, ounce: 0.0283495 },
  Data: { byte: 1, KB: 1024, MB: 1024 ** 2, GB: 1024 ** 3, TB: 1024 ** 4 },
  Speed: { 'km/h': 1, 'm/s': 3.6, mph: 1.60934, knot: 1.852 },
  Time: { second: 1, minute: 60, hour: 3600, day: 86400, week: 604800 },
};

const currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'SGD', 'AED', 'BDT'];

export default function UtilityRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [output, setOutput] = useState('');
  const [error, setError] = useState('');
  const [imgUrl, setImgUrl] = useState('');

  // qr
  const [qrText, setQrText] = useState('https://toolnestfm.com');
  // barcode
  const [bcText, setBcText] = useState('123456789012');
  const [bcFormat, setBcFormat] = useState('CODE128');
  const bcRef = useRef<SVGSVGElement>(null);
  // password
  const [pwLen, setPwLen] = useState(16);
  const [pwUpper, setPwUpper] = useState(true);
  const [pwNums, setPwNums] = useState(true);
  const [pwSyms, setPwSyms] = useState(true);
  // strength
  const [pwTest, setPwTest] = useState('');
  // unit
  const [unitCat, setUnitCat] = useState('Length');
  const [fromU, setFromU] = useState('meter');
  const [toU, setToU] = useState('foot');
  const [unitVal, setUnitVal] = useState('1');
  // currency
  const [amount, setAmount] = useState('100');
  const [fromC, setFromC] = useState('USD');
  const [toC, setToC] = useState('INR');
  const [busy, setBusy] = useState(false);
  // timestamp
  const [ts, setTs] = useState(String(Math.floor(Date.now() / 1000)));
  const [dateStr, setDateStr] = useState('');
  // random
  const [rMin, setRMin] = useState('1');
  const [rMax, setRMax] = useState('100');
  const [rCount, setRCount] = useState(1);

  useEffect(() => {
    if (mode === 'unit') {
      const units = Object.keys(unitTable[unitCat]);
      setFromU(units[0]);
      setToU(units[1] || units[0]);
    }
  }, [unitCat, mode]);

  const strength = (pw: string) => {
    let score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (/[a-z]/.test(pw) && /[A-Z]/.test(pw)) score++;
    if (/\d/.test(pw)) score++;
    if (/[^a-zA-Z0-9]/.test(pw)) score++;
    const labels = ['Very weak 🔴', 'Weak 🔴', 'Fair 🟡', 'Good 🟢', 'Strong 🟢', 'Very strong 💪'];
    const pool = (/[a-z]/.test(pw) ? 26 : 0) + (/[A-Z]/.test(pw) ? 26 : 0) + (/\d/.test(pw) ? 10 : 0) + (/[^a-zA-Z0-9]/.test(pw) ? 32 : 0);
    const entropy = pw.length * Math.log2(Math.max(2, pool));
    const seconds = 2 ** entropy / 1e10;
    const human = seconds < 60 ? 'seconds' : seconds < 3600 ? `${Math.round(seconds / 60)} minutes` : seconds < 86400 ? `${Math.round(seconds / 3600)} hours` : seconds < 31536000 ? `${Math.round(seconds / 86400)} days` : `${(seconds / 31536000).toExponential(1)} years`;
    return `Strength: ${labels[score]}\nEntropy: ~${Math.round(entropy)} bits\nEstimated brute-force time: ${human}`;
  };

  const run = async () => {
    setError('');
    try {
      if (mode === 'qr') {
        const QRCode = await import('qrcode');
        const url = await QRCode.toDataURL(qrText, { width: 480, margin: 2, color: { dark: '#0A0A12', light: '#ffffff' } });
        setImgUrl(url);
      } else if (mode === 'barcode') {
        const JsBarcode = (await import('jsbarcode')).default;
        if (bcRef.current) {
          JsBarcode(bcRef.current, bcText, { format: bcFormat, background: '#ffffff', lineColor: '#0A0A12', displayValue: true });
          const svg = new XMLSerializer().serializeToString(bcRef.current);
          setImgUrl(`data:image/svg+xml;base64,${btoa(svg)}`);
        }
      } else if (mode === 'password') {
        let pool = 'abcdefghijkmnopqrstuvwxyz';
        if (pwUpper) pool += 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        if (pwNums) pool += '23456789';
        if (pwSyms) pool += '!@#$%^&*_-+=?';
        const arr = new Uint32Array(pwLen);
        crypto.getRandomValues(arr);
        const pw = Array.from(arr, (n) => pool[n % pool.length]).join('');
        setOutput(`${pw}\n\n${strength(pw)}`);
      } else if (mode === 'password-strength') {
        setOutput(strength(pwTest));
      } else if (mode === 'unit') {
        const v = parseFloat(unitVal);
        if (Number.isNaN(v)) throw new Error('Enter a valid number.');
        const result = (v * unitTable[unitCat][fromU]) / unitTable[unitCat][toU];
        setOutput(`${v} ${fromU} = ${result.toLocaleString(undefined, { maximumFractionDigits: 6 })} ${toU}`);
      } else if (mode === 'currency') {
        setBusy(true);
        const res = await fetch(`https://api.frankfurter.app/latest?amount=${amount}&from=${fromC}&to=${toC}`);
        if (!res.ok) throw new Error('Live rates unavailable right now. Try again shortly.');
        const json = await res.json();
        const rate = json.rates?.[toC];
        setBusy(false);
        if (rate === undefined) throw new Error('This currency pair is not supported.');
        setOutput(`${amount} ${fromC} = ${Number(rate).toLocaleString()} ${toC}\n\nRate date: ${json.date}\nSource: European Central Bank (frankfurter.app)`);
      } else if (mode === 'timestamp') {
        const lines: string[] = [];
        if (ts.trim()) {
          const n = parseInt(ts.trim());
          const ms = ts.trim().length > 11 ? n : n * 1000;
          const d = new Date(ms);
          lines.push(`Unix ${ts} →`, `  Local: ${d.toLocaleString()}`, `  UTC:   ${d.toUTCString()}`, `  ISO:   ${d.toISOString()}`, '');
        }
        if (dateStr.trim()) {
          const d = new Date(dateStr);
          if (!Number.isNaN(d.getTime())) lines.push(`"${dateStr}" →`, `  Unix (s):  ${Math.floor(d.getTime() / 1000)}`, `  Unix (ms): ${d.getTime()}`);
        }
        lines.push('', `Current Unix time: ${Math.floor(Date.now() / 1000)}`);
        setOutput(lines.join('\n'));
      } else if (mode === 'random') {
        const min = parseInt(rMin);
        const max = parseInt(rMax);
        if (Number.isNaN(min) || Number.isNaN(max) || min > max) throw new Error('Enter a valid range.');
        const nums = Array.from({ length: Math.min(1000, Math.max(1, rCount)) }, () => Math.floor(Math.random() * (max - min + 1)) + min);
        setOutput(nums.join(', '));
      }
    } catch (e) {
      setBusy(false);
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  const units = mode === 'unit' ? Object.keys(unitTable[unitCat]) : [];

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {mode === 'qr' && (
          <div className="field"><label>Text / URL</label><textarea value={qrText} style={{ minHeight: 90 }} onChange={(e) => setQrText(e.target.value)} /></div>
        )}
        {mode === 'barcode' && (
          <>
            <div className="field"><label>Data</label><input value={bcText} onChange={(e) => setBcText(e.target.value)} /></div>
            <div className="field"><label>Format</label>
              <select value={bcFormat} onChange={(e) => setBcFormat(e.target.value)}>
                {['CODE128', 'EAN13', 'UPC', 'CODE39', 'ITF14'].map((f) => <option key={f}>{f}</option>)}
              </select></div>
            <svg ref={bcRef} style={{ display: 'none' }} />
          </>
        )}
        {mode === 'password' && (
          <>
            <div className="field"><label>Length <span className="range-value">{pwLen}</span></label>
              <input type="range" min={8} max={64} value={pwLen} onChange={(e) => setPwLen(+e.target.value)} /></div>
            <label className="checkbox-row"><input type="checkbox" checked={pwUpper} onChange={(e) => setPwUpper(e.target.checked)} /> Uppercase letters</label>
            <label className="checkbox-row"><input type="checkbox" checked={pwNums} onChange={(e) => setPwNums(e.target.checked)} /> Numbers</label>
            <label className="checkbox-row"><input type="checkbox" checked={pwSyms} onChange={(e) => setPwSyms(e.target.checked)} /> Symbols</label>
          </>
        )}
        {mode === 'password-strength' && (
          <div className="field"><label>Password to test</label><input type="text" value={pwTest} onChange={(e) => { setPwTest(e.target.value); setOutput(strength(e.target.value)); }} /></div>
        )}
        {mode === 'unit' && (
          <>
            <div className="field"><label>Category</label>
              <select value={unitCat} onChange={(e) => setUnitCat(e.target.value)}>
                {Object.keys(unitTable).map((c) => <option key={c}>{c}</option>)}
              </select></div>
            <div className="field"><label>Value</label><input type="number" value={unitVal} onChange={(e) => setUnitVal(e.target.value)} /></div>
            <div className="field-row">
              <div className="field"><label>From</label><select value={fromU} onChange={(e) => setFromU(e.target.value)}>{units.map((u) => <option key={u}>{u}</option>)}</select></div>
              <div className="field"><label>To</label><select value={toU} onChange={(e) => setToU(e.target.value)}>{units.map((u) => <option key={u}>{u}</option>)}</select></div>
            </div>
          </>
        )}
        {mode === 'currency' && (
          <>
            <div className="field"><label>Amount</label><input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} /></div>
            <div className="field-row">
              <div className="field"><label>From</label><select value={fromC} onChange={(e) => setFromC(e.target.value)}>{currencies.map((c) => <option key={c}>{c}</option>)}</select></div>
              <div className="field"><label>To</label><select value={toC} onChange={(e) => setToC(e.target.value)}>{currencies.map((c) => <option key={c}>{c}</option>)}</select></div>
            </div>
          </>
        )}
        {mode === 'timestamp' && (
          <>
            <div className="field"><label>Unix timestamp</label><input value={ts} onChange={(e) => setTs(e.target.value)} /></div>
            <div className="field"><label>…or a date string</label><input value={dateStr} placeholder="2026-07-03 14:30" onChange={(e) => setDateStr(e.target.value)} /></div>
          </>
        )}
        {mode === 'random' && (
          <>
            <div className="field-row">
              <div className="field"><label>Min</label><input type="number" value={rMin} onChange={(e) => setRMin(e.target.value)} /></div>
              <div className="field"><label>Max</label><input type="number" value={rMax} onChange={(e) => setRMax(e.target.value)} /></div>
            </div>
            <div className="field"><label>How many?</label><input type="number" min={1} max={1000} value={rCount} onChange={(e) => setRCount(+e.target.value)} /></div>
          </>
        )}
        {error && <ErrorBox message={error} />}
        {mode !== 'password-strength' && (
          <button className="btn btn-primary" disabled={busy} onClick={() => void run()}>{busy ? 'Working...' : 'Generate Now'}</button>
        )}
      </div>
      <div>
        {imgUrl ? (
          <div className="result-box">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={imgUrl} alt="Generated code" className="result-preview" style={{ background: '#fff', padding: 12 }} />
            <button className="btn btn-primary" onClick={() => downloadDataUrl(imgUrl, mode === 'qr' ? 'qrcode.png' : 'barcode.svg')}>
              <Icon name="download" size={15} /> Download
            </button>
          </div>
        ) : output ? (
          <OutputBlock text={output} filename={`${tool.slug}.txt`} />
        ) : (
          <div className="output-area" style={{ minHeight: 220, color: 'var(--text-muted)' }}>Result will appear here.</div>
        )}
      </div>
    </div>
  );
}
