'use client';

export interface AudioAnalysis {
  fileName: string;
  fileSize: number;
  duration: number;
  sampleRate: number;
  channels: number;
  format: string;
  estimatedBitrateKbps: number;
  peakDb: number;
  loudnessDb: number;
  silencePercent: number;
  clippingPercent: number;
  noiseLevel: number;
  hasEcho: boolean;
  isVoice: boolean;
  isMusic: boolean;
  estimatedBpm: number;
  qualityScore: number;
  suggestions: string[];
  waveformPeaks: number[];
  spectrumBands: number[];
}

function extOf(file: File): string {
  return (file.name.split('.').pop() || 'audio').toLowerCase();
}

function analyzeBuffer(buffer: AudioBuffer): Omit<AudioAnalysis, 'fileName' | 'fileSize' | 'format' | 'suggestions' | 'qualityScore' | 'waveformPeaks' | 'spectrumBands'> {
  const ch0 = buffer.getChannelData(0);
  const len = ch0.length;
  let peak = 0;
  let sumSq = 0;
  let clipCount = 0;
  let silentFrames = 0;
  const frameSize = Math.max(1, Math.floor(buffer.sampleRate / 20));
  let zcrSum = 0;

  for (let i = 0; i < len; i++) {
    const v = Math.abs(ch0[i]);
    if (v > peak) peak = v;
    sumSq += ch0[i] * ch0[i];
    if (v > 0.99) clipCount++;
    if (i > 0 && ((ch0[i] >= 0) !== (ch0[i - 1] >= 0))) zcrSum++;
  }

  for (let i = 0; i < len; i += frameSize) {
    let frameEnergy = 0;
    const end = Math.min(i + frameSize, len);
    for (let j = i; j < end; j++) frameEnergy += ch0[j] * ch0[j];
    if (frameEnergy / (end - i) < 0.0001) silentFrames++;
  }

  const rms = Math.sqrt(sumSq / len);
  const loudnessDb = rms > 0 ? 20 * Math.log10(rms) : -60;
  const peakDb = peak > 0 ? 20 * Math.log10(peak) : -60;
  const silencePercent = Math.round((silentFrames / Math.ceil(len / frameSize)) * 100);
  const clippingPercent = Math.round((clipCount / len) * 10000) / 100;
  const zcr = zcrSum / len;

  const isVoice = zcr > 0.08 && zcr < 0.25 && loudnessDb > -35;
  const isMusic = zcr < 0.12 && buffer.numberOfChannels >= 2;
  const noiseLevel = loudnessDb < -45 && peak > 0.01 ? Math.round((1 - rms / peak) * 100) : Math.max(0, Math.round((0.02 - rms) * 500));

  let estimatedBpm = 0;
  const hop = Math.floor(buffer.sampleRate * 0.05);
  const energies: number[] = [];
  for (let i = 0; i < len; i += hop) {
    let e = 0;
    const end = Math.min(i + hop, len);
    for (let j = i; j < end; j++) e += ch0[j] * ch0[j];
    energies.push(e / (end - i));
  }
  if (energies.length > 4) {
    let bestLag = 0;
    let bestCorr = 0;
    for (let lag = 2; lag < Math.min(energies.length / 2, 40); lag++) {
      let corr = 0;
      for (let i = 0; i < energies.length - lag; i++) corr += energies[i] * energies[i + lag];
      if (corr > bestCorr) { bestCorr = corr; bestLag = lag; }
    }
    if (bestLag > 0) estimatedBpm = Math.round(60 / (bestLag * 0.05));
    if (estimatedBpm < 60 || estimatedBpm > 200) estimatedBpm = 0;
  }

  return {
    duration: buffer.duration,
    sampleRate: buffer.sampleRate,
    channels: buffer.numberOfChannels,
    estimatedBitrateKbps: 0,
    peakDb: Math.round(peakDb * 10) / 10,
    loudnessDb: Math.round(loudnessDb * 10) / 10,
    silencePercent,
    clippingPercent,
    noiseLevel: Math.min(100, noiseLevel),
    hasEcho: false,
    isVoice,
    isMusic,
    estimatedBpm,
  };
}

function buildSpectrumBands(buffer: AudioBuffer, bands = 64): number[] {
  const ch = buffer.getChannelData(0);
  const sampleCount = Math.min(ch.length, buffer.sampleRate * 45);
  const result = new Array(bands).fill(0);
  const seg = Math.floor(sampleCount / bands);
  if (!seg) return result.map(() => 0.1);

  for (let b = 0; b < bands; b++) {
    let energy = 0;
    const start = b * seg;
    const end = Math.min(start + seg, sampleCount);
    for (let i = start; i < end; i++) {
      const w = ch[i];
      const weight = 1 + Math.log2(1 + b);
      energy += w * w * weight;
    }
    result[b] = Math.sqrt(energy / (end - start));
  }
  const max = Math.max(...result, 0.001);
  return result.map((v) => v / max);
}

function buildWaveformPeaks(buffer: AudioBuffer, bars = 120): number[] {
  const ch = buffer.getChannelData(0);
  const block = Math.max(1, Math.floor(ch.length / bars));
  const peaks: number[] = [];
  for (let i = 0; i < bars; i++) {
    let peak = 0;
    const start = i * block;
    const end = Math.min(start + block, ch.length);
    for (let j = start; j < end; j++) {
      const v = Math.abs(ch[j]);
      if (v > peak) peak = v;
    }
    peaks.push(peak);
  }
  const max = Math.max(...peaks, 0.001);
  return peaks.map((p) => p / max);
}

function buildSuggestions(a: Omit<AudioAnalysis, 'suggestions' | 'qualityScore' | 'waveformPeaks' | 'spectrumBands'>): string[] {
  const tips: string[] = [];
  if (a.clippingPercent > 0.5) tips.push('Clipping detected — enable Normalize or reduce volume before export.');
  if (a.noiseLevel > 30) tips.push('Background noise detected — enable AI Noise Removal for cleaner output.');
  if (a.silencePercent > 25) tips.push(`${a.silencePercent}% silence — enable Silence Removal to trim dead air.`);
  if (a.loudnessDb < -24) tips.push('Audio is quiet — enable Loudness Optimization for consistent playback.');
  if (a.isVoice && !a.isMusic) tips.push('Voice detected — Podcast Ready preset with voice enhancement recommended.');
  if (a.isMusic) tips.push('Music detected — FLAC or AAC 256k preserves quality for music libraries.');
  if (a.estimatedBitrateKbps > 320 && a.duration > 60) tips.push('High bitrate source — consider FLAC lossless or MP3 192k to save space.');
  if (tips.length === 0) tips.push('Balanced MP3 192k is recommended for universal compatibility.');
  return tips;
}

function scoreQuality(a: Omit<AudioAnalysis, 'qualityScore' | 'suggestions' | 'waveformPeaks' | 'spectrumBands'>): number {
  let score = 75;
  if (a.estimatedBitrateKbps >= 256) score += 12;
  else if (a.estimatedBitrateKbps >= 192) score += 8;
  else if (a.estimatedBitrateKbps < 96) score -= 10;
  if (a.sampleRate >= 44100) score += 5;
  if (a.clippingPercent > 1) score -= 15;
  if (a.noiseLevel > 40) score -= 10;
  if (a.channels >= 2) score += 3;
  return Math.max(0, Math.min(100, score));
}

export function getAudioRecommendation(analysis: AudioAnalysis): {
  preset: import('./audio-presets').AudioPresetId;
  format: import('./audio-presets').AudioFormat;
  bitrate: string;
} {
  if (analysis.isVoice && !analysis.isMusic) {
    return { preset: 'podcast', format: 'mp3', bitrate: '128k' };
  }
  if (analysis.isMusic && analysis.estimatedBitrateKbps > 256) {
    return { preset: 'lossless', format: 'flac', bitrate: '0' };
  }
  if (analysis.fileSize > 20 * 1024 * 1024) {
    return { preset: 'mobile', format: 'aac', bitrate: '96k' };
  }
  return { preset: 'balanced', format: 'mp3', bitrate: '192k' };
}

export async function analyzeAudioFile(file: File): Promise<AudioAnalysis> {
  const ext = extOf(file);
  const arrayBuf = await file.arrayBuffer();

  const ctx = new AudioContext();
  let buffer: AudioBuffer;
  try {
    buffer = await ctx.decodeAudioData(arrayBuf.slice(0));
  } catch {
    await ctx.close();
    const meta = await probeAudioMetadata(file);
    const bitrateKbps = meta.duration > 0 ? Math.round((file.size * 8) / meta.duration / 1000) : 0;
    const base = {
      fileName: file.name,
      fileSize: file.size,
      duration: meta.duration,
      sampleRate: 44100,
      channels: 2,
      format: ext.toUpperCase(),
      estimatedBitrateKbps: bitrateKbps,
      peakDb: 0,
      loudnessDb: -20,
      silencePercent: 0,
      clippingPercent: 0,
      noiseLevel: 0,
      hasEcho: false,
      isVoice: false,
      isMusic: false,
      estimatedBpm: 0,
    };
    return {
      ...base,
      qualityScore: 70,
      suggestions: ['Could not fully decode — FFmpeg will still convert this file.'],
      waveformPeaks: Array(120).fill(0.3),
      spectrumBands: Array(64).fill(0.2),
    };
  }
  await ctx.close();

  const partial = analyzeBuffer(buffer);
  const bitrateKbps = partial.duration > 0
    ? Math.round((file.size * 8) / partial.duration / 1000)
    : 0;

  const base = {
    fileName: file.name,
    fileSize: file.size,
    ...partial,
    estimatedBitrateKbps: bitrateKbps,
    format: ext.toUpperCase(),
  };

  return {
    ...base,
    qualityScore: scoreQuality({ ...base, estimatedBitrateKbps: bitrateKbps }),
    suggestions: buildSuggestions({ ...base, estimatedBitrateKbps: bitrateKbps }),
    waveformPeaks: buildWaveformPeaks(buffer),
    spectrumBands: buildSpectrumBands(buffer),
  };
}

function probeAudioMetadata(file: File): Promise<{ duration: number }> {
  return new Promise((resolve) => {
    const url = URL.createObjectURL(file);
    const audio = document.createElement('audio');
    audio.preload = 'metadata';
    const cleanup = () => URL.revokeObjectURL(url);
    audio.onloadedmetadata = () => {
      cleanup();
      resolve({ duration: Number.isFinite(audio.duration) ? audio.duration : 0 });
    };
    audio.onerror = () => { cleanup(); resolve({ duration: 0 }); };
    audio.src = url;
  });
}

export async function extractAudioFromZip(zipFile: File): Promise<File[]> {
  const JSZip = (await import('jszip')).default;
  const zip = await JSZip.loadAsync(await zipFile.arrayBuffer());
  const re = /\.(mp3|wav|aac|m4a|flac|ogg|opus|wma|aiff|amr|ac3|caf|au|ape|dts|mid|midi)$/i;
  const out: File[] = [];
  for (const [path, entry] of Object.entries(zip.files)) {
    if (entry.dir || !re.test(path)) continue;
    const blob = await entry.async('blob');
    out.push(new File([blob], path.split('/').pop() || 'audio.mp3', { type: blob.type || 'audio/mpeg' }));
  }
  return out;
}

export async function fetchAudioFromUrl(url: string): Promise<File> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Could not fetch audio (${res.status})`);
  const blob = await res.blob();
  if (!blob.type.startsWith('audio/') && !url.match(/\.(mp3|wav|flac|ogg|m4a|aac|opus)/i)) {
    throw new Error('URL did not return an audio file');
  }
  const name = url.split('/').pop()?.split('?')[0] || 'audio.mp3';
  return new File([blob], name, { type: blob.type || 'audio/mpeg' });
}

const SESSION_KEY = 'toolnest-audio-conv-history';

export function saveAudioSession(names: string[]): void {
  try {
    const prev = loadAudioSession();
    const merged = [...names, ...prev].slice(0, 12);
    localStorage.setItem(SESSION_KEY, JSON.stringify([...new Set(merged)]));
  } catch { /* ignore */ }
}

export function loadAudioSession(): string[] {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}
