'use client';

import { useState } from 'react';
import { ErrorBox, Processing, useToolPhase } from '../shared';
import { aiComplete } from '@/lib/ai';
import Icon from '../../Icon';

interface Slide { title: string; bullets: string[] }

export default function PresentationRunner() {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [topic, setTopic] = useState('');
  const [slideCount, setSlideCount] = useState(8);
  const [status, setStatus] = useState('');

  const run = async () => {
    if (!topic.trim()) return;
    setPhase('working');
    try {
      setStatus('Asking AI to outline your deck...');
      const raw = await aiComplete(
        [{ role: 'user', content: `Create a ${slideCount}-slide presentation about: ${topic}` }],
        `You are a presentation expert. Return ONLY valid JSON (no markdown fences): {"title":"...","slides":[{"title":"...","bullets":["...","..."]}]} with exactly ${slideCount} slides, 3-5 concise bullets each.`,
      );
      let deck: { title: string; slides: Slide[] };
      try {
        deck = JSON.parse(raw.replace(/```json|```/g, '').trim()) as { title: string; slides: Slide[] };
      } catch {
        throw new Error('AI returned an unexpected format — please try again.');
      }

      setStatus('Building PPTX file...');
      const PptxGenJS = (await import('pptxgenjs')).default;
      const pptx = new PptxGenJS();
      pptx.defineLayout({ name: 'WIDE', width: 13.33, height: 7.5 });
      pptx.layout = 'WIDE';

      // Title slide
      const title = pptx.addSlide();
      title.background = { color: '0A0A12' };
      title.addText(deck.title || topic, { x: 0.8, y: 2.6, w: 11.7, h: 1.4, fontSize: 40, bold: true, color: 'F5F5FA', fontFace: 'Arial' });
      title.addText('Generated with ToolNest AI ✦', { x: 0.8, y: 4.2, w: 10, h: 0.5, fontSize: 16, color: '8B5CF6' });
      title.addShape('rect', { x: 0.8, y: 4.0, w: 2.4, h: 0.06, fill: { color: '7C3AED' } });

      for (const s of deck.slides || []) {
        const slide = pptx.addSlide();
        slide.background = { color: '12121C' };
        slide.addShape('rect', { x: 0, y: 0, w: 0.25, h: 7.5, fill: { color: '7C3AED' } });
        slide.addText(s.title, { x: 0.8, y: 0.5, w: 11.7, h: 1, fontSize: 30, bold: true, color: 'F5F5FA' });
        slide.addText(
          (s.bullets || []).map((b) => ({ text: b, options: { bullet: { code: '2022' }, color: 'A0A0B8', fontSize: 17, breakLine: true, paraSpaceAfter: 10 } })),
          { x: 0.9, y: 1.8, w: 11.4, h: 5.2 },
        );
      }

      await pptx.writeFile({ fileName: `${topic.slice(0, 40).replace(/[^a-z0-9]+/gi, '-')}.pptx` });
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  if (phase === 'working') return <Processing label={status || 'Working...'} />;

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        <div className="field">
          <label>Presentation topic / outline</label>
          <textarea value={topic} placeholder="e.g. Digital Marketing Strategy 2026 for a SaaS startup" onChange={(e) => setTopic(e.target.value)} />
        </div>
        <div className="field">
          <label>Number of slides</label>
          <select value={slideCount} onChange={(e) => setSlideCount(+e.target.value)}>
            {[5, 8, 10, 12, 15].map((n) => <option key={n} value={n}>{n} slides</option>)}
          </select>
        </div>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={!topic.trim()} onClick={() => void run()}>
          <Icon name="sparkles" size={15} /> Generate PPTX
        </button>
        {phase === 'done' && <p className="muted" style={{ fontSize: 13 }}>✓ Your deck was downloaded! Generate another anytime.</p>}
      </div>
      <div className="output-area" style={{ minHeight: 240, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-muted)', textAlign: 'center' }}>
        AI writes your outline → ToolNest builds a dark-themed, branded PowerPoint file → it downloads automatically.
      </div>
    </div>
  );
}
