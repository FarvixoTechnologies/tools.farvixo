'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { OutputBlock, ErrorBox } from '../shared';

/** Safe expression evaluator for the scientific calculator (no eval). */
function evaluate(expr: string): number {
  const tokens = expr.replace(/\s+/g, '')
    .replace(/π/g, `(${Math.PI})`)
    .replace(/\be\b/g, `(${Math.E})`)
    .match(/(\d+\.?\d*|[+\-*/^()%]|sqrt|sin|cos|tan|log|ln|abs)/g);
  if (!tokens || tokens.join('') !== expr.replace(/\s+/g, '').replace(/π/g, `(${Math.PI})`).replace(/\be\b/g, `(${Math.E})`)) {
    throw new Error('Invalid characters in expression.');
  }
  let pos = 0;
  const peek = () => tokens[pos];
  const next = () => tokens[pos++];

  function parseExpr(): number {
    let v = parseTerm();
    while (peek() === '+' || peek() === '-') {
      const op = next();
      const r = parseTerm();
      v = op === '+' ? v + r : v - r;
    }
    return v;
  }
  function parseTerm(): number {
    let v = parsePow();
    while (peek() === '*' || peek() === '/' || peek() === '%') {
      const op = next();
      const r = parsePow();
      v = op === '*' ? v * r : op === '/' ? v / r : v % r;
    }
    return v;
  }
  function parsePow(): number {
    const base = parseUnary();
    if (peek() === '^') { next(); return Math.pow(base, parsePow()); }
    return base;
  }
  function parseUnary(): number {
    if (peek() === '-') { next(); return -parseUnary(); }
    if (peek() === '+') { next(); return parseUnary(); }
    return parseAtom();
  }
  function parseAtom(): number {
    const t = next();
    if (t === undefined) throw new Error('Unexpected end of expression.');
    if (t === '(') {
      const v = parseExpr();
      if (next() !== ')') throw new Error('Missing closing bracket.');
      return v;
    }
    const fns: Record<string, (x: number) => number> = {
      sqrt: Math.sqrt, sin: (x) => Math.sin(x), cos: (x) => Math.cos(x), tan: (x) => Math.tan(x),
      log: Math.log10, ln: Math.log, abs: Math.abs,
    };
    if (fns[t]) {
      if (next() !== '(') throw new Error(`${t} needs brackets, e.g. ${t}(x)`);
      const v = parseExpr();
      if (next() !== ')') throw new Error('Missing closing bracket.');
      return fns[t](v);
    }
    const n = parseFloat(t);
    if (Number.isNaN(n)) throw new Error(`Unexpected token: ${t}`);
    return n;
  }
  const result = parseExpr();
  if (pos < tokens.length) throw new Error('Could not parse the full expression.');
  return result;
}

export default function CalculatorRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [output, setOutput] = useState('');
  const [error, setError] = useState('');

  const [heightCm, setHeightCm] = useState('170');
  const [weightKg, setWeightKg] = useState('65');
  const [pctA, setPctA] = useState('25');
  const [pctB, setPctB] = useState('200');
  const [pctMode, setPctMode] = useState('of');
  const [principal, setPrincipal] = useState('500000');
  const [ratePa, setRatePa] = useState('9.5');
  const [years, setYears] = useState('5');
  const [price, setPrice] = useState('1999');
  const [discount, setDiscount] = useState('20');
  const [expr, setExpr] = useState('');

  const run = () => {
    setError('');
    try {
      if (mode === 'bmi') {
        const h = parseFloat(heightCm) / 100;
        const w = parseFloat(weightKg);
        if (!h || !w) throw new Error('Enter valid height and weight.');
        const bmi = w / (h * h);
        const cat = bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Normal weight ✓' : bmi < 30 ? 'Overweight' : 'Obese';
        const idealMin = (18.5 * h * h).toFixed(1);
        const idealMax = (24.9 * h * h).toFixed(1);
        setOutput(`BMI: ${bmi.toFixed(1)}\nCategory: ${cat}\n\nHealthy weight range for your height: ${idealMin}–${idealMax} kg`);
      } else if (mode === 'percentage') {
        const a = parseFloat(pctA);
        const b = parseFloat(pctB);
        if (Number.isNaN(a) || Number.isNaN(b)) throw new Error('Enter valid numbers.');
        if (pctMode === 'of') setOutput(`${a}% of ${b} = ${((a / 100) * b).toLocaleString()}`);
        else if (pctMode === 'what') setOutput(`${a} is ${((a / b) * 100).toFixed(2)}% of ${b}`);
        else {
          const change = ((b - a) / Math.abs(a)) * 100;
          setOutput(`From ${a} to ${b}: ${change >= 0 ? '+' : ''}${change.toFixed(2)}% ${change >= 0 ? 'increase' : 'decrease'}`);
        }
      } else if (mode === 'emi') {
        const P = parseFloat(principal);
        const r = parseFloat(ratePa) / 12 / 100;
        const n = parseFloat(years) * 12;
        if (!P || !n) throw new Error('Enter valid loan details.');
        const emi = r === 0 ? P / n : (P * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1);
        const total = emi * n;
        let schedule = '';
        let bal = P;
        for (let yy = 1; yy <= Math.min(parseFloat(years), 30); yy++) {
          for (let mm = 0; mm < 12 && bal > 0; mm++) {
            const interest = bal * r;
            bal -= emi - interest;
          }
          schedule += `After year ${yy}: balance ₹${Math.max(0, Math.round(bal)).toLocaleString()}\n`;
        }
        setOutput(`Monthly EMI: ₹${Math.round(emi).toLocaleString()}\nTotal payment: ₹${Math.round(total).toLocaleString()}\nTotal interest: ₹${Math.round(total - P).toLocaleString()}\n\n${schedule}`);
      } else if (mode === 'discount') {
        const p = parseFloat(price);
        const d = parseFloat(discount);
        if (Number.isNaN(p) || Number.isNaN(d)) throw new Error('Enter valid numbers.');
        const final = p * (1 - d / 100);
        setOutput(`Original price: ₹${p.toLocaleString()}\nDiscount: ${d}%\n\nFinal price: ₹${final.toFixed(2)}\nYou save: ₹${(p - final).toFixed(2)}`);
      } else if (mode === 'scientific') {
        const v = evaluate(expr);
        setOutput(`${expr} = ${Number.isInteger(v) ? v : v.toPrecision(12).replace(/\.?0+$/, '')}`);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {mode === 'bmi' && (
          <div className="field-row">
            <div className="field"><label>Height (cm)</label><input type="number" value={heightCm} onChange={(e) => setHeightCm(e.target.value)} /></div>
            <div className="field"><label>Weight (kg)</label><input type="number" value={weightKg} onChange={(e) => setWeightKg(e.target.value)} /></div>
          </div>
        )}
        {mode === 'percentage' && (
          <>
            <div className="field"><label>Calculation</label>
              <select value={pctMode} onChange={(e) => setPctMode(e.target.value)}>
                <option value="of">X% of Y</option>
                <option value="what">X is what % of Y</option>
                <option value="change">% change from X to Y</option>
              </select></div>
            <div className="field-row">
              <div className="field"><label>X</label><input type="number" value={pctA} onChange={(e) => setPctA(e.target.value)} /></div>
              <div className="field"><label>Y</label><input type="number" value={pctB} onChange={(e) => setPctB(e.target.value)} /></div>
            </div>
          </>
        )}
        {mode === 'emi' && (
          <>
            <div className="field"><label>Loan amount (₹)</label><input type="number" value={principal} onChange={(e) => setPrincipal(e.target.value)} /></div>
            <div className="field-row">
              <div className="field"><label>Interest % p.a.</label><input type="number" step="0.1" value={ratePa} onChange={(e) => setRatePa(e.target.value)} /></div>
              <div className="field"><label>Tenure (years)</label><input type="number" value={years} onChange={(e) => setYears(e.target.value)} /></div>
            </div>
          </>
        )}
        {mode === 'discount' && (
          <div className="field-row">
            <div className="field"><label>Price (₹)</label><input type="number" value={price} onChange={(e) => setPrice(e.target.value)} /></div>
            <div className="field"><label>Discount %</label><input type="number" value={discount} onChange={(e) => setDiscount(e.target.value)} /></div>
          </div>
        )}
        {mode === 'scientific' && (
          <div className="field">
            <label>Expression</label>
            <input value={expr} className="mono" placeholder="e.g. sqrt(144) + 2^10 * sin(0.5)" onChange={(e) => setExpr(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && run()} />
            <span className="muted" style={{ fontSize: 12 }}>Supports + − × ÷ ^ % ( ) sqrt sin cos tan log ln abs π e</span>
          </div>
        )}
        {error && <ErrorBox message={error} />}
        <button className="btn btn-primary" onClick={run}>Calculate Now</button>
      </div>
      <div>{output ? <OutputBlock text={output} /> : <div className="output-area" style={{ minHeight: 200, color: 'var(--text-muted)' }}>Result will appear here.</div>}</div>
    </div>
  );
}
