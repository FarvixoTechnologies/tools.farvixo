'use client';

import { useEffect, useRef, useState } from 'react';
import type { Tool } from '@/data/tools';
import { FileDrop, ErrorBox, OutputBlock } from '../shared';
import Icon from '../../Icon';
import { downloadText } from '@/lib/download';

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
