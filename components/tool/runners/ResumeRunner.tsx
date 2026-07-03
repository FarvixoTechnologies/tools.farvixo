'use client';

import { useState } from 'react';
import { ErrorBox, Processing, useToolPhase } from '../shared';
import { aiComplete } from '@/lib/ai';
import { downloadBlob } from '@/lib/download';
import Icon from '../../Icon';

export default function ResumeRunner() {
  const { phase, setPhase, error, fail, reset } = useToolPhase();
  const [form, setForm] = useState({
    name: '', title: '', email: '', phone: '', location: '',
    summary: '', experience: '', education: '', skills: '',
  });
  const [polish, setPolish] = useState(true);
  const set = (k: string, v: string) => setForm({ ...form, [k]: v });

  const run = async () => {
    if (!form.name.trim()) return;
    setPhase('working');
    try {
      let summary = form.summary;
      let experience = form.experience;
      if (polish && (summary || experience)) {
        const improved = await aiComplete(
          [{ role: 'user', content: `Polish this resume content professionally. Keep facts, improve wording. Return ONLY valid JSON: {"summary": "...", "experience": "..."}.\nSummary: ${summary}\nExperience: ${experience}` }],
          'You are an expert resume writer. Output only valid JSON, no markdown fences.',
        );
        try {
          const cleaned = improved.replace(/```json|```/g, '').trim();
          const json = JSON.parse(cleaned) as { summary?: string; experience?: string };
          summary = json.summary || summary;
          experience = json.experience || experience;
        } catch { /* keep originals if AI output was not JSON */ }
      }

      const { PDFDocument, StandardFonts, rgb } = await import('@cantoo/pdf-lib');
      const doc = await PDFDocument.create();
      const font = await doc.embedFont(StandardFonts.Helvetica);
      const bold = await doc.embedFont(StandardFonts.HelveticaBold);
      const pageW = 595.28;
      const pageH = 841.89;
      let page = doc.addPage([pageW, pageH]);
      const margin = 50;
      let y = pageH - 60;
      const violet = rgb(0.486, 0.227, 0.929);
      const dark = rgb(0.1, 0.1, 0.15);
      const gray = rgb(0.4, 0.4, 0.5);
      const ascii = (s: string) => s.replace(/[^\x20-\x7E\n]/g, '');

      const writeLines = (text: string, size: number, useFont = font, color = dark) => {
        const maxW = pageW - margin * 2;
        for (const para of ascii(text).split('\n')) {
          let line = '';
          const words = para.split(/\s+/).filter(Boolean);
          if (words.length === 0) { y -= size * 0.8; continue; }
          for (const wd of words) {
            const attempt = line ? `${line} ${wd}` : wd;
            if (useFont.widthOfTextAtSize(attempt, size) > maxW && line) {
              if (y < 60) { page = doc.addPage([pageW, pageH]); y = pageH - 60; }
              page.drawText(line, { x: margin, y, size, font: useFont, color });
              y -= size + 4;
              line = wd;
            } else line = attempt;
          }
          if (line) {
            if (y < 60) { page = doc.addPage([pageW, pageH]); y = pageH - 60; }
            page.drawText(line, { x: margin, y, size, font: useFont, color });
            y -= size + 4;
          }
        }
      };

      const section = (title: string) => {
        y -= 14;
        page.drawText(title.toUpperCase(), { x: margin, y, size: 12, font: bold, color: violet });
        y -= 6;
        page.drawLine({ start: { x: margin, y }, end: { x: pageW - margin, y }, thickness: 1, color: violet });
        y -= 16;
      };

      page.drawText(ascii(form.name), { x: margin, y, size: 26, font: bold, color: dark });
      y -= 22;
      if (form.title) { page.drawText(ascii(form.title), { x: margin, y, size: 13, font, color: violet }); y -= 18; }
      const contact = [form.email, form.phone, form.location].filter(Boolean).join('  ·  ');
      if (contact) { page.drawText(ascii(contact), { x: margin, y, size: 10, font, color: gray }); y -= 10; }

      if (summary) { section('Summary'); writeLines(summary, 10.5); }
      if (experience) { section('Experience'); writeLines(experience, 10.5); }
      if (form.education) { section('Education'); writeLines(form.education, 10.5); }
      if (form.skills) { section('Skills'); writeLines(form.skills, 10.5); }

      downloadBlob(new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }), `${form.name.replace(/\s+/g, '-')}-resume.pdf`);
      setPhase('done');
    } catch (e) {
      fail(e);
    }
  };

  if (phase === 'working') return <Processing label="Building your resume with AI polish..." />;

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        <div className="field-row">
          <div className="field"><label>Full name *</label><input value={form.name} onChange={(e) => set('name', e.target.value)} /></div>
          <div className="field"><label>Job title</label><input value={form.title} placeholder="e.g. Frontend Developer" onChange={(e) => set('title', e.target.value)} /></div>
        </div>
        <div className="field-row">
          <div className="field"><label>Email</label><input value={form.email} onChange={(e) => set('email', e.target.value)} /></div>
          <div className="field"><label>Phone</label><input value={form.phone} onChange={(e) => set('phone', e.target.value)} /></div>
        </div>
        <div className="field"><label>Location</label><input value={form.location} placeholder="e.g. Kolkata, India" onChange={(e) => set('location', e.target.value)} /></div>
        <div className="field"><label>Professional summary</label><textarea value={form.summary} onChange={(e) => set('summary', e.target.value)} /></div>
      </div>
      <div className="options-panel">
        <div className="field"><label>Experience (one role per line)</label><textarea value={form.experience} placeholder={'Frontend Developer - Fam Cloud (2023-now)\nBuilt ToolNest platform...'} onChange={(e) => set('experience', e.target.value)} /></div>
        <div className="field"><label>Education</label><textarea value={form.education} style={{ minHeight: 70 }} onChange={(e) => set('education', e.target.value)} /></div>
        <div className="field"><label>Skills (comma separated)</label><input value={form.skills} placeholder="React, TypeScript, Node.js" onChange={(e) => set('skills', e.target.value)} /></div>
        <label className="checkbox-row"><input type="checkbox" checked={polish} onChange={(e) => setPolish(e.target.checked)} /> ✨ AI-polish my summary &amp; experience</label>
        {phase === 'error' && <ErrorBox message={error} onRetry={reset} />}
        <button className="btn btn-primary" disabled={!form.name.trim()} onClick={() => void run()}>
          <Icon name="download" size={15} /> Build Resume PDF
        </button>
        {phase === 'done' && <p className="muted" style={{ fontSize: 13 }}>✓ Downloaded! Generate again anytime.</p>}
      </div>
    </div>
  );
}
