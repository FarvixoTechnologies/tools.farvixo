'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, ErrorBox, OutputBlock } from '../shared';
import Icon from '../../Icon';
import { downloadText } from '@/lib/download';
import { aiComplete } from '@/lib/ai';

/* Web Speech API typings (not in TS lib by default) */
interface SpeechRecognitionResultEvent {
  resultIndex: number;
  results: { length: number; [i: number]: { isFinal: boolean; 0: { transcript: string } } };
}
interface SpeechRecognitionLike {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  onresult: ((e: SpeechRecognitionResultEvent) => void) | null;
  onend: (() => void) | null;
  onerror: ((e: { error: string }) => void) | null;
  start: () => void;
  stop: () => void;
}

function getRecognition(): SpeechRecognitionLike | null {
  if (typeof window === 'undefined') return null;
  const w = window as unknown as { SpeechRecognition?: new () => SpeechRecognitionLike; webkitSpeechRecognition?: new () => SpeechRecognitionLike };
  const Ctor = w.SpeechRecognition || w.webkitSpeechRecognition;
  return Ctor ? new Ctor() : null;
}

function toSrtTime(s: number): string {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60);
  const ms = Math.floor((s % 1) * 1000);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')},${String(ms).padStart(3, '0')}`;
}

export default function SpeechRunner({ tool }: { tool: Tool }) {
  const mode = tool.mode; // tts | stt | subtitle
  const [error, setError] = useState('');

  /* ── TTS ── */
  const [ttsText, setTtsText] = useState('');
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [voiceIdx, setVoiceIdx] = useState(0);
  const [rate, setRate] = useState(1);
  const [speaking, setSpeaking] = useState(false);

  useEffect(() => {
    if (mode !== 'tts' || typeof window === 'undefined') return;
    const load = () => setVoices(window.speechSynthesis.getVoices());
    load();
    window.speechSynthesis.onvoiceschanged = load;
  }, [mode]);

  const speak = () => {
    if (!ttsText.trim()) return;
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(ttsText);
    if (voices[voiceIdx]) u.voice = voices[voiceIdx];
    u.rate = rate;
    u.onend = () => setSpeaking(false);
    setSpeaking(true);
    window.speechSynthesis.speak(u);
  };

  /* ── STT / Subtitle ── */
  const [listening, setListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [segments, setSegments] = useState<{ start: number; end: number; text: string }[]>([]);
  const recRef = useRef<SpeechRecognitionLike | null>(null);
  const startTimeRef = useRef(0);
  const segStartRef = useRef(0);
  const [files, setFiles] = useState<File[]>([]);
  const [mediaUrl, setMediaUrl] = useState('');
  const [sttLang, setSttLang] = useState('en-US');

  useEffect(() => {
    if (files[0]) setMediaUrl(URL.createObjectURL(files[0]));
  }, [files]);

  const startListening = () => {
    const rec = getRecognition();
    if (!rec) {
      setError('Speech recognition is not supported in this browser. Please use Chrome or Edge.');
      return;
    }
    setError('');
    rec.lang = sttLang;
    rec.continuous = true;
    rec.interimResults = true;
    startTimeRef.current = performance.now();
    segStartRef.current = 0;
    rec.onresult = (e) => {
      let finalText = '';
      let interim = '';
      for (let i = 0; i < e.results.length; i++) {
        const r = e.results[i];
        if (r.isFinal) finalText += r[0].transcript + ' ';
        else interim += r[0].transcript;
      }
      setTranscript(finalText + interim);
      if (mode === 'subtitle' && finalText) {
        const now = (performance.now() - startTimeRef.current) / 1000;
        setSegments(() => {
          const chunks = finalText.trim().split(/(?<=[.?!])\s+/).filter(Boolean);
          const dur = now / Math.max(1, chunks.length);
          return chunks.map((text, i) => ({ start: i * dur, end: (i + 1) * dur, text }));
        });
      }
    };
    rec.onerror = (e) => setError(`Recognition error: ${e.error}`);
    rec.onend = () => setListening(false);
    recRef.current = rec;
    rec.start();
    setListening(true);
  };

  const stopListening = () => {
    recRef.current?.stop();
    setListening(false);
  };

  const exportSrt = () => {
    const srt = segments.map((s, i) => `${i + 1}\n${toSrtTime(s.start)} --> ${toSrtTime(s.end)}\n${s.text}\n`).join('\n');
    downloadText(srt || `1\n00:00:00,000 --> 00:00:05,000\n${transcript}\n`, 'subtitles.srt');
  };

  /* ── UI ── */
  if (mode === 'tts') {
    return (
      <div className="workspace-grid">
        <div className="field">
          <label>Text to speak</label>
          <textarea value={ttsText} style={{ minHeight: 220 }} placeholder="Type or paste text here..." onChange={(e) => setTtsText(e.target.value)} />
        </div>
        <div className="options-panel">
          <h3>Options</h3>
          <div className="field"><label>Voice</label>
            <select value={voiceIdx} onChange={(e) => setVoiceIdx(+e.target.value)}>
              {voices.map((v, i) => <option key={v.name + i} value={i}>{v.name} ({v.lang})</option>)}
              {voices.length === 0 && <option>Default voice</option>}
            </select></div>
          <div className="field"><label>Speed <span className="range-value">{rate.toFixed(1)}×</span></label>
            <input type="range" min={0.5} max={2} step={0.1} value={rate} onChange={(e) => setRate(+e.target.value)} /></div>
          {error && <ErrorBox message={error} />}
          <button className="btn btn-primary" disabled={!ttsText.trim()} onClick={speaking ? () => { window.speechSynthesis.cancel(); setSpeaking(false); } : speak}>
            <Icon name={speaking ? 'x' : 'volume'} size={16} /> {speaking ? 'Stop' : 'Speak Now'}
          </button>
          <p className="muted" style={{ fontSize: 12.5 }}>Uses your device&apos;s built-in voices. Tip: to save as audio, use a system recorder or the Voice Changer tool.</p>
        </div>
      </div>
    );
  }

  if (mode === 'stt') return <SttStudio tool={tool} />;

  return (
    <div className="workspace-grid">
      <div>
        {mode === 'subtitle' && (
          <>
            <FileDrop accept={tool.accept} files={files} onFiles={setFiles} hint="Upload a video/audio file, press Start, then play it out loud" />
            {mediaUrl && (
              <video src={mediaUrl} controls className="w-full mt-4" style={{ borderRadius: 12, maxHeight: 300 }} />
            )}
          </>
        )}
        <div className="field mt-4">
          <label>{mode === 'subtitle' ? 'Live transcript' : 'Transcript'}</label>
          <div className="output-area" style={{ minHeight: 160 }}>{transcript || (listening ? 'Listening...' : 'Press Start and speak (or play your media out loud).')}</div>
        </div>
      </div>
      <div className="options-panel">
        <h3>Options</h3>
        <div className="field"><label>Language</label>
          <select value={sttLang} onChange={(e) => setSttLang(e.target.value)}>
            <option value="en-US">English (US)</option>
            <option value="en-IN">English (India)</option>
            <option value="hi-IN">Hindi</option>
            <option value="bn-IN">Bengali</option>
            <option value="es-ES">Spanish</option>
            <option value="fr-FR">French</option>
            <option value="de-DE">German</option>
            <option value="ar-SA">Arabic</option>
          </select></div>
        {error && <ErrorBox message={error} />}
        <button className="btn btn-primary" onClick={listening ? stopListening : startListening}>
          <Icon name="mic" size={16} /> {listening ? 'Stop' : 'Start Listening'}
        </button>
        {transcript && (
          <>
            {mode === 'subtitle'
              ? <button className="btn btn-outline" onClick={exportSrt}><Icon name="download" size={15} /> Download SRT</button>
              : <OutputBlock text={transcript} filename="transcript.txt" />}
          </>
        )}
        <p className="muted" style={{ fontSize: 12.5 }}>
          {mode === 'subtitle'
            ? 'How it works: press Start Listening, then play your video with the sound on. Speech is captured live and exported as an SRT subtitle file.'
            : 'Live speech recognition via your browser (Chrome/Edge recommended).'}
        </p>
      </div>
    </div>
  );
}

/* ══════════════════════════  Speech-to-Text Studio  ══════════════════════════ */

interface Segment { t: number; text: string }

const STT_LANGS: [string, string][] = [
  ['en-US', 'English (US)'], ['en-GB', 'English (UK)'], ['en-IN', 'English (India)'],
  ['hi-IN', 'Hindi'], ['bn-IN', 'Bengali'], ['ta-IN', 'Tamil'], ['te-IN', 'Telugu'],
  ['ur-PK', 'Urdu'], ['ar-SA', 'Arabic'], ['es-ES', 'Spanish'], ['fr-FR', 'French'],
  ['de-DE', 'German'], ['it-IT', 'Italian'], ['pt-BR', 'Portuguese (BR)'], ['ru-RU', 'Russian'],
  ['ja-JP', 'Japanese'], ['ko-KR', 'Korean'], ['zh-CN', 'Chinese (Mandarin)'],
];

function clock(s: number): string {
  const m = Math.floor(s / 60);
  const sec = Math.floor(s % 60);
  return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
}

export function SttStudio(_props: { tool: Tool }) {
  const [listening, setListening] = useState(false);
  const [paused, setPaused] = useState(false);
  const [lang, setLang] = useState('en-US');
  const [segments, setSegments] = useState<Segment[]>([]);
  const [interim, setInterim] = useState('');
  const [error, setError] = useState('');
  const [elapsed, setElapsed] = useState(0);

  const [aiBusy, setAiBusy] = useState('');
  const [aiOut, setAiOut] = useState('');
  const [copied, setCopied] = useState(false);

  const recRef = useRef<SpeechRecognitionLike | null>(null);
  const wantRef = useRef(false);          // should we keep listening (for auto-restart)
  const startedRef = useRef(0);           // performance.now at session start

  const fullText = segments.map((s) => s.text).join(' ').trim();
  const words = fullText ? fullText.split(/\s+/).length : 0;
  const wpm = elapsed > 2 ? Math.round((words / elapsed) * 60) : 0;

  /* elapsed clock */
  useEffect(() => {
    if (!listening || paused) return;
    const id = setInterval(() => setElapsed((performance.now() - startedRef.current) / 1000), 250);
    return () => clearInterval(id);
  }, [listening, paused]);

  const start = async () => {
    const rec = getRecognition();
    if (!rec) { setError('Speech recognition needs Chrome or Edge (desktop). Your browser is not supported.'); return; }
    setError('');

    // Pre-flight: grant permission + confirm a working mic, then release it
    // immediately so it does NOT compete with SpeechRecognition's own capture.
    try {
      const s = await navigator.mediaDevices.getUserMedia({ audio: true });
      s.getTracks().forEach((t) => t.stop());
    } catch (err) {
      const name = err instanceof Error ? err.name : '';
      setError(
        name === 'NotAllowedError' ? 'Microphone blocked. Click the 🔒/mic icon in the address bar → Allow, then try again.'
          : name === 'NotFoundError' ? 'No microphone found. Plug in a mic or check your sound settings.'
            : name === 'NotReadableError' ? 'Your microphone is in use by another app (Zoom/Teams/etc). Close it and try again.'
              : 'Could not access the microphone. Check that a mic is connected and permitted.',
      );
      return;
    }

    rec.lang = lang;
    rec.continuous = true;
    rec.interimResults = true;
    startedRef.current = performance.now() - elapsed * 1000;
    rec.onresult = (e) => {
      let fin = ''; let intr = '';
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i];
        if (r.isFinal) fin += r[0].transcript; else intr += r[0].transcript;
      }
      if (fin.trim()) {
        const t = (performance.now() - startedRef.current) / 1000;
        setSegments((prev) => [...prev, { t, text: fin.trim() }]);
      }
      setInterim(intr);
    };
    rec.onerror = (ev) => {
      if (ev.error === 'no-speech' || ev.error === 'aborted') return; // transient — auto-restarts
      wantRef.current = false; // stop the auto-restart loop for real errors
      setListening(false);
      if (ev.error === 'not-allowed' || ev.error === 'service-not-allowed') setError('Microphone permission denied. Allow mic access in the address bar and try again.');
      else if (ev.error === 'audio-capture') setError('No audio captured. Your mic may be muted, in use by another app, or the wrong device is selected in Windows sound settings.');
      else if (ev.error === 'network') setError('Network error — speech recognition needs an internet connection.');
      else setError(`Recognition error: ${ev.error}`);
    };
    rec.onend = () => {
      // Chrome auto-stops on silence — restart if the user still wants to listen.
      if (wantRef.current) { try { rec.start(); } catch { /* already started */ } }
      else setListening(false);
    };
    recRef.current = rec;
    wantRef.current = true;
    rec.start();
    setListening(true);
    setPaused(false);
  };

  const stop = () => {
    wantRef.current = false;
    recRef.current?.stop();
    setListening(false);
    setPaused(false);
    setInterim('');
  };

  const togglePause = () => {
    if (paused) { wantRef.current = true; try { recRef.current?.start(); } catch { /* noop */ } setPaused(false); }
    else { wantRef.current = false; recRef.current?.stop(); setPaused(true); setInterim(''); }
  };

  const clearAll = () => { setSegments([]); setInterim(''); setElapsed(0); setAiOut(''); startedRef.current = performance.now(); };

  useEffect(() => () => { wantRef.current = false; recRef.current?.stop(); }, []);

  /* exports */
  const srt = () => segments.map((s, i) => {
    const end = segments[i + 1]?.t ?? s.t + 3;
    return `${i + 1}\n${toSrtTime(s.t)} --> ${toSrtTime(end)}\n${s.text}\n`;
  }).join('\n');
  const vtt = () => 'WEBVTT\n\n' + segments.map((s, i) => {
    const end = segments[i + 1]?.t ?? s.t + 3;
    return `${toSrtTime(s.t).replace(',', '.')} --> ${toSrtTime(end).replace(',', '.')}\n${s.text}\n`;
  }).join('\n');

  const copy = async () => { await navigator.clipboard.writeText(fullText); setCopied(true); setTimeout(() => setCopied(false), 1500); };

  const runAi = async (kind: 'clean' | 'summary' | 'translate' | 'actions') => {
    if (!fullText) return;
    setAiBusy(kind); setAiOut('');
    const prompts: Record<typeof kind, string> = {
      clean: 'Fix punctuation, capitalisation and paragraph breaks in this raw transcript. Keep every word, do not summarise. Return only the cleaned text.',
      summary: 'Summarise this transcript into a short paragraph plus 3-5 key bullet points. Use markdown.',
      translate: 'Translate this transcript into fluent English. Return only the translation.',
      actions: 'Extract clear action items / to-dos from this transcript as a markdown checklist. If none, say so.',
    };
    try {
      const out = await aiComplete([{ role: 'user', content: fullText }], prompts[kind], (full) => setAiOut(full), { temperature: 0.3 });
      setAiOut(out);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'AI request failed');
    } finally {
      setAiBusy('');
    }
  };

  return (
    <div className="stt-root">
      <SttStyles />
      <div className="stt-grid">
        {/* Left: live capture */}
        <div className="stt-main">
          <div className={`stt-stage ${listening && !paused ? 'live' : ''}`}>
            <div className="stt-eq" aria-hidden>{Array.from({ length: 40 }).map((_, i) => <span key={i} style={{ animationDelay: `${(i % 10) * 0.08}s` }} />)}</div>
            <div className="stt-stats">
              <span><b>{clock(elapsed)}</b> time</span>
              <span><b>{words}</b> words</span>
              <span><b>{wpm}</b> wpm</span>
              <span className={`stt-dot ${listening && !paused ? 'on' : ''}`}>{listening ? (paused ? 'Paused' : 'Recording') : 'Idle'}</span>
            </div>
          </div>

          <div className="stt-transcript" aria-live="polite">
            {segments.length === 0 && !interim && <span className="stt-hint">Press <b>Start</b> and speak — your words appear here live, with timestamps.</span>}
            {segments.map((s, i) => (
              <span key={i} className="stt-seg"><span className="stt-ts">{clock(s.t)}</span>{s.text} </span>
            ))}
            {interim && <span className="stt-interim">{interim}</span>}
          </div>

          {aiOut && (
            <div className="stt-ai-out">
              <div className="stt-ai-head">AI result{aiBusy && ' …'}</div>
              <div className="stt-ai-body">{aiOut}</div>
            </div>
          )}
        </div>

        {/* Right: controls */}
        <div className="options-panel">
          <div className="field"><label>Language</label>
            <select value={lang} onChange={(e) => setLang(e.target.value)} disabled={listening}>
              {STT_LANGS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </select>
          </div>

          {error && <ErrorBox message={error} />}

          {!listening ? (
            <button className="btn btn-primary stt-rec" onClick={() => void start()}><Icon name="mic" size={16} /> Start</button>
          ) : (
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn" style={{ flex: 1 }} onClick={togglePause}>{paused ? '▶ Resume' : '⏸ Pause'}</button>
              <button className="btn btn-primary" style={{ flex: 1 }} onClick={stop}><Icon name="x" size={15} /> Stop</button>
            </div>
          )}

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <button className="btn" disabled={!fullText} onClick={copy}>{copied ? '✓ Copied' : 'Copy'}</button>
            <button className="btn" disabled={!fullText} onClick={clearAll}>Clear</button>
            <button className="btn" disabled={!fullText} onClick={() => downloadText(fullText, 'transcript.txt')}>.txt</button>
            <button className="btn" disabled={!segments.length} onClick={() => downloadText(srt(), 'transcript.srt')}>.srt</button>
            <button className="btn" disabled={!segments.length} onClick={() => downloadText(vtt(), 'transcript.vtt')}>.vtt</button>
            <button className="btn" disabled={!segments.length} onClick={() => downloadText(JSON.stringify(segments, null, 2), 'transcript.json')}>.json</button>
          </div>

          <div className="stt-ai-actions">
            <div className="stt-ai-label">AI enhance</div>
            {([['clean', 'Punctuate & clean'], ['summary', 'Summarise'], ['translate', 'Translate → English'], ['actions', 'Action items']] as [string, string][]).map(([k, label]) => (
              <button key={k} className="btn btn-outline" disabled={!fullText || !!aiBusy} onClick={() => void runAi(k as 'clean')}>
                <Icon name="sparkles" size={14} /> {aiBusy === k ? 'Working…' : label}
              </button>
            ))}
          </div>

          <p className="muted" style={{ fontSize: 12 }}>Live recognition runs in your browser (Chrome/Edge). Auto-restarts through pauses so long dictation never cuts off. AI enhance uses Farvixo&apos;s free AI.</p>
        </div>
      </div>
    </div>
  );
}

function SttStyles() {
  return (
    <style>{`
.stt-root { isolation: isolate; }
.stt-grid { display: grid; grid-template-columns: 1fr 300px; gap: 16px; }
@media (max-width: 820px){ .stt-grid { grid-template-columns: 1fr; } }
.stt-main { display: flex; flex-direction: column; gap: 14px; min-width: 0; }
.stt-stage { position: relative; border-radius: 16px; padding: 14px 16px; background: var(--bg-surface); border: 1px solid var(--border-subtle); overflow: hidden; transition: box-shadow .3s ease, border-color .3s ease; }
.stt-stage.live { border-color: rgba(108,77,255,.5); box-shadow: 0 0 34px -6px rgba(108,77,255,.5); }
.stt-eq { display: flex; align-items: center; justify-content: center; gap: 3px; height: 90px; }
.stt-eq span { width: 4px; height: 8px; border-radius: 3px; background: linear-gradient(180deg,#6C4DFF,#C026D3); opacity: .35; }
.stt-stage.live .stt-eq span { animation: stt-bar .9s ease-in-out infinite; opacity: 1; }
@keyframes stt-bar { 0%,100% { height: 8px; } 50% { height: 64px; } }
.stt-stats { display: flex; flex-wrap: wrap; gap: 16px; margin-top: 8px; font-size: 12.5px; color: var(--text-muted); }
.stt-stats b { color: var(--text-primary); font-size: 15px; }
.stt-dot { margin-left: auto; padding: 3px 12px; border-radius: 999px; background: rgba(255,255,255,.06); }
.stt-dot.on { color: #fff; background: linear-gradient(120deg,#6C4DFF,#C026D3); animation: stt-pulse 1.4s ease-in-out infinite; }
@keyframes stt-pulse { 50% { box-shadow: 0 0 16px rgba(192,38,211,.7);} }
.stt-transcript { min-height: 220px; max-height: 420px; overflow-y: auto; padding: 18px; border-radius: 16px; background: var(--bg-surface); border: 1px solid var(--border-subtle); font-size: 16px; line-height: 1.9; color: var(--text-primary); }
.stt-hint { color: var(--text-muted); }
.stt-ts { display: inline-block; margin-right: 6px; padding: 1px 7px; border-radius: 6px; font-size: 11px; font-variant-numeric: tabular-nums; color: #9A9AB5; background: rgba(255,255,255,.05); vertical-align: middle; }
.stt-interim { color: var(--text-muted); font-style: italic; }
.stt-ai-out { border-radius: 16px; border: 1px solid rgba(108,77,255,.35); background: rgba(108,77,255,.06); overflow: hidden; }
.stt-ai-head { padding: 8px 14px; font-size: 12px; font-weight: 700; letter-spacing: .05em; text-transform: uppercase; color: #B9A8FF; border-bottom: 1px solid rgba(108,77,255,.2); }
.stt-ai-body { padding: 14px; font-size: 14.5px; line-height: 1.7; white-space: pre-wrap; color: var(--text-primary); }
.stt-ai-actions { display: flex; flex-direction: column; gap: 8px; margin-top: 4px; }
.stt-ai-label, .stt-ai-actions .stt-ai-label { font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; color: var(--text-muted); }
.stt-rec { animation: stt-glow 2.6s ease-in-out infinite; }
@keyframes stt-glow { 50% { box-shadow: 0 0 22px rgba(108,77,255,.6);} }
@media (prefers-reduced-motion: reduce){ .stt-dot.on, .stt-rec, .stt-stage { animation: none !important; } }
`}</style>
  );
}
