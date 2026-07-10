'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { ErrorBox, OutputBlock, useToolPhase } from '../shared';
import { aiComplete, getApiKey } from '@/lib/ai';
import { useUI } from '../../GlobalUI';
import Icon from '../../Icon';

interface Field {
  key: string;
  label: string;
  type: 'text' | 'textarea' | 'select';
  placeholder?: string;
  options?: string[];
}

export default function AiTextRunner({ tool }: { tool: Tool }) {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const { openSettings } = useUI();
  const fields = ((tool.config?.fields as Field[]) || []);
  // Master Farvixo identity is force-injected inside aiComplete(); this is only the task hint.
  const system = (tool.config?.system as string) || `You are Farvixo AI helping with the "${tool.name}" tool. Be helpful and precise.`;
  const [values, setValues] = useState<Record<string, string>>(
    Object.fromEntries(fields.map((f) => [f.key, f.type === 'select' ? (f.options?.[0] || '') : ''])),
  );
  const [output, setOutput] = useState('');

  const mainFilled = fields.filter((f) => f.type !== 'select').some((f) => values[f.key]?.trim());

  const run = async () => {
    if (!mainFilled) return;
    setPhase('working');
    setOutput('');
    try {
      const prompt = fields.map((f) => `${f.label}: ${values[f.key] || '(not specified)'}`).join('\n');
      const full = await aiComplete([{ role: 'user', content: prompt }], system, (text) => setOutput(text));
      setOutput(full);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {fields.map((f) => (
          <div className="field" key={f.key}>
            <label>{f.label}</label>
            {f.type === 'textarea' && (
              <textarea value={values[f.key]} placeholder={f.placeholder} onChange={(e) => setValues({ ...values, [f.key]: e.target.value })} />
            )}
            {f.type === 'text' && (
              <input value={values[f.key]} placeholder={f.placeholder} onChange={(e) => setValues({ ...values, [f.key]: e.target.value })} />
            )}
            {f.type === 'select' && (
              <select value={values[f.key]} onChange={(e) => setValues({ ...values, [f.key]: e.target.value })}>
                {f.options?.map((o) => <option key={o} value={o}>{o}</option>)}
              </select>
            )}
          </div>
        ))}
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={!mainFilled || phase === 'working'} onClick={() => void run()}>
          <Icon name="sparkles" size={15} /> {phase === 'working' ? 'Generating...' : 'Generate Now'}
        </button>
        <p className="muted" style={{ fontSize: 12 }}>
          {getApiKey() ? 'Using your Gemini API key.' : <>Free AI mode. <a style={{ color: 'var(--brand-primary-hover)', cursor: 'pointer' }} onClick={openSettings}>Add a Gemini key</a> for best quality.</>}
        </p>
      </div>
      <div>
        <h3 className="mb-4" style={{ fontSize: 15 }}>Output</h3>
        {output
          ? <OutputBlock text={output} filename={`${tool.slug}.md`} />
          : <div className="output-area" style={{ minHeight: 260, color: 'var(--text-muted)' }}>{phase === 'working' ? 'Thinking…' : 'Generated content will appear here.'}</div>}
      </div>
    </div>
  );
}
