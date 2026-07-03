'use client';

import { useState } from 'react';
import type { Tool } from '@/data/tools';
import { OutputBlock, ErrorBox } from '../shared';
import { downloadBlob } from '@/lib/download';
import Icon from '../../Icon';

interface LineItem { desc: string; qty: string; price: string }

async function buildDocPdf(kind: 'INVOICE' | 'RECEIPT' | 'QUOTATION', data: {
  from: string; to: string; number: string; items: LineItem[]; taxPct: number; currency: string; notes: string;
}): Promise<Blob> {
  const { PDFDocument, StandardFonts, rgb } = await import('@cantoo/pdf-lib');
  const doc = await PDFDocument.create();
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const page = doc.addPage([595.28, 841.89]);
  const violet = rgb(0.486, 0.227, 0.929);
  const dark = rgb(0.08, 0.08, 0.12);
  const gray = rgb(0.45, 0.45, 0.55);
  const ascii = (s: string) => s.replace(/[^\x20-\x7E\n]/g, '');
  const m = 50;
  let y = 780;

  page.drawRectangle({ x: 0, y: 810, width: 595.28, height: 32, color: violet });
  page.drawText('ToolNest', { x: m, y: 820, size: 13, font: bold, color: rgb(1, 1, 1) });
  page.drawText(kind, { x: m, y, size: 30, font: bold, color: dark });
  page.drawText(`# ${ascii(data.number)}`, { x: 420, y: y + 8, size: 12, font, color: gray });
  page.drawText(`Date: ${new Date().toLocaleDateString()}`, { x: 420, y: y - 8, size: 10, font, color: gray });
  y -= 50;

  page.drawText('FROM', { x: m, y, size: 9, font: bold, color: violet });
  page.drawText('TO', { x: 320, y, size: 9, font: bold, color: violet });
  y -= 14;
  const fromLines = ascii(data.from).split('\n');
  const toLines = ascii(data.to).split('\n');
  for (let i = 0; i < Math.max(fromLines.length, toLines.length); i++) {
    if (fromLines[i]) page.drawText(fromLines[i], { x: m, y, size: 10, font, color: dark });
    if (toLines[i]) page.drawText(toLines[i], { x: 320, y, size: 10, font, color: dark });
    y -= 13;
  }
  y -= 20;

  // Table header
  page.drawRectangle({ x: m, y: y - 4, width: 495, height: 22, color: rgb(0.95, 0.94, 0.99) });
  page.drawText('DESCRIPTION', { x: m + 8, y, size: 9, font: bold, color: violet });
  page.drawText('QTY', { x: 360, y, size: 9, font: bold, color: violet });
  page.drawText('PRICE', { x: 410, y, size: 9, font: bold, color: violet });
  page.drawText('TOTAL', { x: 480, y, size: 9, font: bold, color: violet });
  y -= 24;

  let subtotal = 0;
  for (const it of data.items) {
    if (!it.desc.trim()) continue;
    const qty = parseFloat(it.qty) || 1;
    const price = parseFloat(it.price) || 0;
    const total = qty * price;
    subtotal += total;
    page.drawText(ascii(it.desc).slice(0, 52), { x: m + 8, y, size: 10, font, color: dark });
    page.drawText(String(qty), { x: 360, y, size: 10, font, color: dark });
    page.drawText(price.toFixed(2), { x: 410, y, size: 10, font, color: dark });
    page.drawText(total.toFixed(2), { x: 480, y, size: 10, font, color: dark });
    y -= 18;
  }
  y -= 10;
  page.drawLine({ start: { x: 360, y }, end: { x: 545, y }, thickness: 0.7, color: gray });
  y -= 18;
  const tax = subtotal * (data.taxPct / 100);
  page.drawText(`Subtotal: ${data.currency} ${subtotal.toFixed(2)}`, { x: 360, y, size: 10, font, color: dark });
  y -= 16;
  page.drawText(`Tax (${data.taxPct}%): ${data.currency} ${tax.toFixed(2)}`, { x: 360, y, size: 10, font, color: dark });
  y -= 20;
  page.drawText(`TOTAL: ${data.currency} ${(subtotal + tax).toFixed(2)}`, { x: 360, y, size: 14, font: bold, color: violet });
  y -= 40;
  if (data.notes) {
    page.drawText('Notes:', { x: m, y, size: 9, font: bold, color: gray });
    y -= 13;
    page.drawText(ascii(data.notes).slice(0, 100), { x: m, y, size: 9, font, color: gray });
  }
  page.drawText('Generated with ToolNest - toolnestfm.com', { x: m, y: 30, size: 8, font, color: gray });
  return new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' });
}

export default function BusinessRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode;
  const [error, setError] = useState('');
  const [output, setOutput] = useState('');
  const [done, setDone] = useState(false);

  // doc generators
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [number, setNumber] = useState(`${new Date().getFullYear()}-001`);
  const [items, setItems] = useState<LineItem[]>([{ desc: '', qty: '1', price: '' }]);
  const [taxPct, setTaxPct] = useState(18);
  const [currency, setCurrency] = useState('₹');
  const [notes, setNotes] = useState('');

  // calculators
  const [amount, setAmount] = useState('1000');
  const [rate, setRate] = useState('18');
  const [gstDir, setGstDir] = useState<'exclusive' | 'inclusive'>('exclusive');
  const [cost, setCost] = useState('100');
  const [sell, setSell] = useState('150');
  const [ctc, setCtc] = useState('1200000');
  const [basicPct, setBasicPct] = useState('40');

  // business card
  const [card, setCard] = useState({ name: 'Faruk Mondal', title: 'Founder', company: 'Fam Cloud Pvt. Ltd.', phone: '', email: '', website: 'toolnestfm.com' });

  const isDocMode = ['invoice', 'receipt', 'quotation'].includes(mode);

  const run = async () => {
    setError('');
    setDone(false);
    try {
      if (isDocMode) {
        const kind = mode === 'invoice' ? 'INVOICE' : mode === 'receipt' ? 'RECEIPT' : 'QUOTATION';
        const blob = await buildDocPdf(kind, { from, to, number, items, taxPct, currency: currency === '₹' ? 'INR' : currency, notes });
        downloadBlob(blob, `${mode}-${number}.pdf`);
        setDone(true);
      } else if (mode === 'gst') {
        const a = parseFloat(amount);
        const r = parseFloat(rate);
        if (Number.isNaN(a) || Number.isNaN(r)) throw new Error('Enter valid numbers.');
        if (gstDir === 'exclusive') {
          const gst = a * (r / 100);
          setOutput(`Base amount:  ₹${a.toFixed(2)}\nGST @ ${r}%:    ₹${gst.toFixed(2)}\n  CGST ${r / 2}%:  ₹${(gst / 2).toFixed(2)}\n  SGST ${r / 2}%:  ₹${(gst / 2).toFixed(2)}\n───────────────────\nTotal:        ₹${(a + gst).toFixed(2)}`);
        } else {
          const base = a / (1 + r / 100);
          const gst = a - base;
          setOutput(`Total (incl.): ₹${a.toFixed(2)}\nBase amount:   ₹${base.toFixed(2)}\nGST @ ${r}%:     ₹${gst.toFixed(2)}\n  CGST ${r / 2}%:   ₹${(gst / 2).toFixed(2)}\n  SGST ${r / 2}%:   ₹${(gst / 2).toFixed(2)}`);
        }
      } else if (mode === 'margin') {
        const c = parseFloat(cost);
        const s = parseFloat(sell);
        if (Number.isNaN(c) || Number.isNaN(s) || c <= 0) throw new Error('Enter valid numbers.');
        const profit = s - c;
        setOutput(`Cost:    ₹${c.toFixed(2)}\nRevenue: ₹${s.toFixed(2)}\nProfit:  ₹${profit.toFixed(2)}\n\nMargin:  ${((profit / s) * 100).toFixed(2)}%\nMarkup:  ${((profit / c) * 100).toFixed(2)}%`);
      } else if (mode === 'salary') {
        const c = parseFloat(ctc);
        const bp = parseFloat(basicPct) / 100;
        if (Number.isNaN(c)) throw new Error('Enter a valid CTC.');
        const basic = c * bp;
        const hra = basic * 0.5;
        const epfEmployer = Math.min(basic * 0.12, 21600);
        const gratuity = basic * 0.0481;
        const special = c - basic - hra - epfEmployer - gratuity;
        const epfEmployee = epfEmployer;
        const profTax = 2400;
        const grossMonthly = (basic + hra + special) / 12;
        const monthlyInHand = grossMonthly - epfEmployee / 12 - profTax / 12;
        setOutput(
          `Annual CTC:        ₹${c.toLocaleString()}\n\nBasic (${basicPct}%):     ₹${Math.round(basic).toLocaleString()}\nHRA (50% of basic): ₹${Math.round(hra).toLocaleString()}\nSpecial allowance: ₹${Math.round(special).toLocaleString()}\nEmployer EPF:      ₹${Math.round(epfEmployer).toLocaleString()}\nGratuity:          ₹${Math.round(gratuity).toLocaleString()}\n\nDeductions/yr: EPF ₹${Math.round(epfEmployee).toLocaleString()} + Prof. tax ₹${profTax}\n───────────────────────────\n≈ Monthly in-hand (pre-income-tax): ₹${Math.round(monthlyInHand).toLocaleString()}\n\nNote: income tax depends on your regime & declarations.`,
        );
      } else if (mode === 'card') {
        const { PDFDocument, StandardFonts, rgb } = await import('@cantoo/pdf-lib');
        const doc = await PDFDocument.create();
        const bold = await doc.embedFont(StandardFonts.HelveticaBold);
        const font = await doc.embedFont(StandardFonts.Helvetica);
        // Standard card 3.5in x 2in = 252 x 144 pt
        const page = doc.addPage([252, 144]);
        page.drawRectangle({ x: 0, y: 0, width: 252, height: 144, color: rgb(0.04, 0.04, 0.07) });
        page.drawRectangle({ x: 0, y: 0, width: 8, height: 144, color: rgb(0.486, 0.227, 0.929) });
        const ascii = (s: string) => s.replace(/[^\x20-\x7E]/g, '');
        page.drawText(ascii(card.name), { x: 24, y: 100, size: 16, font: bold, color: rgb(0.96, 0.96, 0.98) });
        page.drawText(ascii(card.title), { x: 24, y: 84, size: 9, font, color: rgb(0.55, 0.36, 0.93) });
        page.drawText(ascii(card.company), { x: 24, y: 70, size: 9, font, color: rgb(0.63, 0.63, 0.72) });
        let cy = 44;
        for (const line of [card.phone, card.email, card.website].filter(Boolean)) {
          page.drawText(ascii(line), { x: 24, y: cy, size: 8, font, color: rgb(0.63, 0.63, 0.72) });
          cy -= 12;
        }
        downloadBlob(new Blob([new Uint8Array(await doc.save())], { type: 'application/pdf' }), 'business-card.pdf');
        setDone(true);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  };

  if (isDocMode) {
    return (
      <div className="workspace-grid">
        <div className="options-panel">
          <div className="field-row">
            <div className="field"><label>{mode === 'quotation' ? 'Quote' : mode === 'receipt' ? 'Receipt' : 'Invoice'} #</label><input value={number} onChange={(e) => setNumber(e.target.value)} /></div>
            <div className="field"><label>Currency</label>
              <select value={currency} onChange={(e) => setCurrency(e.target.value)}>
                {['₹', 'USD', 'EUR', 'GBP', 'AED'].map((c) => <option key={c}>{c}</option>)}
              </select></div>
          </div>
          <div className="field"><label>From (your business)</label><textarea value={from} style={{ minHeight: 70 }} placeholder={'Fam Cloud Pvt. Ltd.\nKolkata, India'} onChange={(e) => setFrom(e.target.value)} /></div>
          <div className="field"><label>Bill to (client)</label><textarea value={to} style={{ minHeight: 70 }} onChange={(e) => setTo(e.target.value)} /></div>
          <div className="field"><label>Tax % </label><input type="number" value={taxPct} onChange={(e) => setTaxPct(+e.target.value)} /></div>
          <div className="field"><label>Notes</label><input value={notes} placeholder="Payment due in 15 days" onChange={(e) => setNotes(e.target.value)} /></div>
        </div>
        <div className="options-panel">
          <h3>Line items</h3>
          {items.map((it, i) => (
            <div className="field-row" key={i}>
              <div className="field" style={{ flex: 3 }}><input value={it.desc} placeholder="Description" onChange={(e) => setItems(items.map((x, j) => j === i ? { ...x, desc: e.target.value } : x))} /></div>
              <div className="field"><input value={it.qty} placeholder="Qty" onChange={(e) => setItems(items.map((x, j) => j === i ? { ...x, qty: e.target.value } : x))} /></div>
              <div className="field"><input value={it.price} placeholder="Price" onChange={(e) => setItems(items.map((x, j) => j === i ? { ...x, price: e.target.value } : x))} /></div>
            </div>
          ))}
          <button className="btn btn-ghost btn-sm" onClick={() => setItems([...items, { desc: '', qty: '1', price: '' }])}>+ Add item</button>
          {error && <ErrorBox message={error} />}
          <button className="btn btn-primary" onClick={() => void run()}><Icon name="download" size={15} /> Generate PDF</button>
          {done && <p className="muted" style={{ fontSize: 13 }}>✓ PDF downloaded!</p>}
        </div>
      </div>
    );
  }

  return (
    <div className="workspace-grid">
      <div className="options-panel">
        {mode === 'gst' && (
          <>
            <div className="field"><label>Amount (₹)</label><input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} /></div>
            <div className="field"><label>GST rate</label>
              <select value={rate} onChange={(e) => setRate(e.target.value)}>
                {['5', '12', '18', '28'].map((r) => <option key={r} value={r}>{r}%</option>)}
              </select></div>
            <div className="field"><label>Amount is</label>
              <select value={gstDir} onChange={(e) => setGstDir(e.target.value as 'exclusive' | 'inclusive')}>
                <option value="exclusive">Excluding GST (add GST)</option>
                <option value="inclusive">Including GST (extract GST)</option>
              </select></div>
          </>
        )}
        {mode === 'margin' && (
          <>
            <div className="field"><label>Cost price (₹)</label><input type="number" value={cost} onChange={(e) => setCost(e.target.value)} /></div>
            <div className="field"><label>Selling price (₹)</label><input type="number" value={sell} onChange={(e) => setSell(e.target.value)} /></div>
          </>
        )}
        {mode === 'salary' && (
          <>
            <div className="field"><label>Annual CTC (₹)</label><input type="number" value={ctc} onChange={(e) => setCtc(e.target.value)} /></div>
            <div className="field"><label>Basic salary % of CTC</label><input type="number" value={basicPct} onChange={(e) => setBasicPct(e.target.value)} /></div>
          </>
        )}
        {mode === 'card' && (
          <>
            {(['name', 'title', 'company', 'phone', 'email', 'website'] as const).map((k) => (
              <div className="field" key={k}><label style={{ textTransform: 'capitalize' }}>{k}</label>
                <input value={card[k]} onChange={(e) => setCard({ ...card, [k]: e.target.value })} /></div>
            ))}
          </>
        )}
        {error && <ErrorBox message={error} />}
        <button className="btn btn-primary" onClick={() => void run()}>{mode === 'card' ? 'Download Card PDF' : 'Calculate Now'}</button>
        {done && <p className="muted" style={{ fontSize: 13 }}>✓ Downloaded!</p>}
      </div>
      <div>{output ? <OutputBlock text={output} /> : <div className="output-area" style={{ minHeight: 200, color: 'var(--text-muted)' }}>Result will appear here.</div>}</div>
    </div>
  );
}
