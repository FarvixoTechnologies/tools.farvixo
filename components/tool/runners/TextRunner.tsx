'use client';

import { useMemo, useState } from 'react';
import type { Tool } from '@/data/tools';
import { OutputBlock } from '../shared';

const LOREM_WORDS = 'lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua enim ad minim veniam quis nostrud exercitation ullamco laboris nisi aliquip ex ea commodo consequat duis aute irure in reprehenderit voluptate velit esse cillum eu fugiat nulla pariatur excepteur sint occaecat cupidatat non proident sunt culpa qui officia deserunt mollit anim id est laborum'.split(' ');

function lorem(paragraphs: number, wordsPer = 60): string {
  const out: string[] = [];
  for (let p = 0; p < paragraphs; p++) {
    const words: string[] = [];
    for (let i = 0; i < wordsPer; i++) words.push(LOREM_WORDS[Math.floor(Math.random() * LOREM_WORDS.length)]);
    let s = words.join(' ');
    s = s.charAt(0).toUpperCase() + s.slice(1) + '.';
    out.push(s);
  }
  return out.join('\n\n');
}

function diffLines(a: string, b: string): string {
  const al = a.split('\n');
  const bl = b.split('\n');
  const max = Math.max(al.length, bl.length);
  const out: string[] = [];
  for (let i = 0; i < max; i++) {
    const x = al[i] ?? '';
    const y = bl[i] ?? '';
    if (x === y) out.push(`  ${x}`);
    else {
      if (al[i] !== undefined) out.push(`− ${x}`);
      if (bl[i] !== undefined) out.push(`+ ${y}`);
    }
  }
  return out.join('\n');
}

export default function TextRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [input, setInput] = useState('');
  const [input2, setInput2] = useState('');
  const [output, setOutput] = useState('');
  const [caseType, setCaseType] = useState('upper');
  const [sortType, setSortType] = useState('az');
  const [reverseType, setReverseType] = useState('chars');
  const [paras, setParas] = useState(3);

  const stats = useMemo(() => {
    const words = input.trim() ? input.trim().split(/\s+/).length : 0;
    const chars = input.length;
    const charsNoSpace = input.replace(/\s/g, '').length;
    const sentences = (input.match(/[.!?]+(\s|$)/g) || []).length;
    const paragraphs = input.trim() ? input.trim().split(/\n\s*\n/).length : 0;
    const readMin = Math.max(1, Math.ceil(words / 200));
    return { words, chars, charsNoSpace, sentences, paragraphs, readMin };
  }, [input]);

  const run = () => {
    if (mode === 'case') {
      const map: Record<string, (s: string) => string> = {
        upper: (s) => s.toUpperCase(),
        lower: (s) => s.toLowerCase(),
        title: (s) => s.replace(/\w\S*/g, (w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()),
        sentence: (s) => s.toLowerCase().replace(/(^\s*\w|[.!?]\s+\w)/g, (c) => c.toUpperCase()),
        camel: (s) => s.toLowerCase().replace(/[^a-zA-Z0-9]+(.)/g, (_, c: string) => c.toUpperCase()),
        snake: (s) => s.trim().toLowerCase().replace(/[^a-zA-Z0-9]+/g, '_'),
        kebab: (s) => s.trim().toLowerCase().replace(/[^a-zA-Z0-9]+/g, '-'),
        alternating: (s) => s.split('').map((c, i) => (i % 2 ? c.toUpperCase() : c.toLowerCase())).join(''),
      };
      setOutput(map[caseType](input));
    } else if (mode === 'compare') {
      setOutput(diffLines(input, input2));
    } else if (mode === 'dedupe') {
      const seen = new Set<string>();
      const out = input.split('\n').filter((l) => { if (seen.has(l)) return false; seen.add(l); return true; });
      setOutput(out.join('\n'));
    } else if (mode === 'reverse') {
      if (reverseType === 'chars') setOutput(input.split('').reverse().join(''));
      else if (reverseType === 'words') setOutput(input.split(/\s+/).reverse().join(' '));
      else setOutput(input.split('\n').reverse().join('\n'));
    } else if (mode === 'sort') {
      const lines = input.split('\n');
      if (sortType === 'az') lines.sort((a, b) => a.localeCompare(b));
      else if (sortType === 'za') lines.sort((a, b) => b.localeCompare(a));
      else if (sortType === 'length') lines.sort((a, b) => a.length - b.length);
      else lines.sort(() => Math.random() - 0.5);
      setOutput(lines.join('\n'));
    } else if (mode === 'lorem') {
      setOutput(lorem(paras));
    }
  };

  if (mode === 'count') {
    return (
      <div className="workspace-grid">
        <div className="field">
          <label>Your text</label>
          <textarea value={input} style={{ minHeight: 260 }} placeholder="Type or paste text — stats update live..." onChange={(e) => setInput(e.target.value)} />
        </div>
        <div className="options-panel">
          <h3>Statistics</h3>
          <div className="grid-2">
            {[
              ['Words', stats.words], ['Characters', stats.chars],
              ['Chars (no spaces)', stats.charsNoSpace], ['Sentences', stats.sentences],
              ['Paragraphs', stats.paragraphs], ['Reading time', `${stats.readMin} min`],
            ].map(([label, val]) => (
              <div key={String(label)} className="glass" style={{ padding: 14, textAlign: 'center' }}>
                <div className="stat-value" style={{ fontSize: 22 }}>{val}</div>
                <div className="stat-label">{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {mode !== 'lorem' && (
          <div className="field">
            <label>{mode === 'compare' ? 'Original text' : 'Input'}</label>
            <textarea value={input} style={{ minHeight: 160 }} onChange={(e) => setInput(e.target.value)} />
          </div>
        )}
        {mode === 'compare' && (
          <div className="field"><label>Changed text</label><textarea value={input2} style={{ minHeight: 160 }} onChange={(e) => setInput2(e.target.value)} /></div>
        )}
        {mode === 'case' && (
          <div className="field"><label>Convert to</label>
            <select value={caseType} onChange={(e) => setCaseType(e.target.value)}>
              <option value="upper">UPPERCASE</option>
              <option value="lower">lowercase</option>
              <option value="title">Title Case</option>
              <option value="sentence">Sentence case</option>
              <option value="camel">camelCase</option>
              <option value="snake">snake_case</option>
              <option value="kebab">kebab-case</option>
              <option value="alternating">aLtErNaTiNg</option>
            </select></div>
        )}
        {mode === 'sort' && (
          <div className="field"><label>Sort order</label>
            <select value={sortType} onChange={(e) => setSortType(e.target.value)}>
              <option value="az">A → Z</option>
              <option value="za">Z → A</option>
              <option value="length">By length</option>
              <option value="random">Shuffle</option>
            </select></div>
        )}
        {mode === 'reverse' && (
          <div className="field"><label>Reverse</label>
            <select value={reverseType} onChange={(e) => setReverseType(e.target.value)}>
              <option value="chars">Characters</option>
              <option value="words">Words</option>
              <option value="lines">Lines</option>
            </select></div>
        )}
        {mode === 'lorem' && (
          <div className="field"><label>Paragraphs</label><input type="number" min={1} max={20} value={paras} onChange={(e) => setParas(+e.target.value)} /></div>
        )}
        <button className="btn btn-primary" onClick={run}>Process Now</button>
      </div>
      <div>{output ? <OutputBlock text={output} filename={`${tool.slug}.txt`} /> : <div className="output-area" style={{ minHeight: 220, color: 'var(--text-muted)' }}>Output will appear here.</div>}</div>
    </div>
  );
}
