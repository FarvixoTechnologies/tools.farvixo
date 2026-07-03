'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop } from '../shared';
import { aiComplete, getApiKey, type ChatMessage } from '@/lib/ai';
import { extractPdfText } from '@/lib/pdf';
import { useUI } from '../../GlobalUI';
import Icon from '../../Icon';

export default function AiChatRunner({ tool }: { tool: Tool }) {
  const isPdf = tool.mode === 'pdf';
  const { openSettings } = useUI();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [files, setFiles] = useState<File[]>([]);
  const [pdfText, setPdfText] = useState('');
  const [pdfStatus, setPdfStatus] = useState('');
  const bodyRef = useRef<HTMLDivElement>(null);

  useEffect(() => { bodyRef.current?.scrollTo({ top: bodyRef.current.scrollHeight }); }, [messages]);

  useEffect(() => {
    if (isPdf && files[0]) {
      setPdfStatus('Reading PDF...');
      void extractPdfText(files[0]).then((pages) => {
        const text = pages.join('\n\n').slice(0, 60_000);
        setPdfText(text);
        setPdfStatus(`✓ ${files[0].name} loaded (${pages.length} pages). Ask me anything about it!`);
      }).catch(() => setPdfStatus('Could not read this PDF (is it scanned? Try PDF OCR first).'));
    }
  }, [files, isPdf]);

  const system = isPdf
    ? `You are ToolNest AI PDF Assistant. Answer questions using ONLY the following PDF content. If the answer is not in the document, say so.\n\n--- PDF CONTENT ---\n${pdfText}`
    : 'You are ToolNest AI, a helpful assistant. Be concise, clear and friendly.';

  const send = async () => {
    const text = input.trim();
    if (!text || busy || (isPdf && !pdfText)) return;
    setInput('');
    const next: ChatMessage[] = [...messages, { role: 'user', content: text }];
    setMessages([...next, { role: 'assistant', content: '…' }]);
    setBusy(true);
    try {
      const full = await aiComplete(next, system, (t) => setMessages([...next, { role: 'assistant', content: t }]));
      setMessages([...next, { role: 'assistant', content: full }]);
    } catch (err) {
      setMessages([...next, { role: 'assistant', content: `⚠️ ${err instanceof Error ? err.message : 'Error'}` }]);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      {isPdf && (
        <div className="mb-4">
          <FileDrop accept="application/pdf" files={files} onFiles={setFiles} hint="Upload the PDF you want to chat with" />
          {pdfStatus && <p className="muted mt-2" style={{ fontSize: 13 }}>{pdfStatus}</p>}
        </div>
      )}
      <div className="glass" style={{ display: 'flex', flexDirection: 'column', height: 460 }}>
        <div className="ai-messages" ref={bodyRef}>
          {messages.length === 0 && (
            <div className="ai-msg assistant">
              {isPdf ? 'Upload a PDF above, then ask me anything about it — summaries, key points, specific facts.' : 'Hi! I\'m ToolNest AI Chat. Ask me anything ✨'}
            </div>
          )}
          {messages.map((m, i) => (<div key={i} className={`ai-msg ${m.role}`}>{m.content}</div>))}
        </div>
        <div className="ai-input-row">
          <textarea
            value={input}
            rows={1}
            placeholder={isPdf ? 'Ask about your PDF...' : 'Type your message...'}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); void send(); } }}
          />
          <button className="ai-send" onClick={() => void send()} disabled={busy} aria-label="Send"><Icon name="send" size={17} /></button>
        </div>
      </div>
      <p className="muted mt-2" style={{ fontSize: 12, textAlign: 'center' }}>
        {getApiKey() ? 'Using your Gemini API key.' : <>Free AI mode — <a style={{ color: 'var(--brand-primary-hover)', cursor: 'pointer' }} onClick={openSettings}>add a Gemini API key</a> for the best quality.</>}
      </p>
    </div>
  );
}
