'use client';

import { aiComplete } from '@/lib/ai';
import { autoEnhance, canvasToBlob, loadImage, makeCanvas, sharpen } from '@/lib/image';
import { generateFreePollinationsImage, mapPollinationsModel } from '@/lib/engines/pollinations-image-engine';

/* ─── Types ─────────────────────────────────────────────────────────────── */

export type StudioStep = 'prompt' | 'generate' | 'edit' | 'export';
export type GenerationMode =
  | 'text-to-image' | 'image-to-image' | 'multi-fusion'
  | 'character-ref' | 'style-ref' | 'face-ref' | 'pose-ref' | 'object-ref'
  | 'depth-map' | 'controlnet' | 'ip-adapter'
  | 'sketch-to-image' | 'line-art' | 'scribble'
  | 'qr-art' | 'logo' | 'icon' | 'sticker' | 'wallpaper' | 'poster'
  | 'thumbnail' | 'banner' | 'social-post' | 'product-mockup'
  | 'interior' | 'fashion' | 'tattoo' | 'architecture' | 'game-asset'
  | 'pixel-art' | 'nft';

export type ExportFormat = 'png' | 'jpg' | 'webp' | 'bmp' | 'tiff' | 'avif';

export interface AiModel {
  id: string;
  label: string;
  provider: string;
  tier: 'free' | 'pro';
  description: string;
}

export interface AspectPreset {
  id: string;
  label: string;
  w: number;
  h: number;
}

export interface GenerationControls {
  model: string;
  cfgScale: number;
  steps: number;
  seed: number;
  randomSeed: boolean;
  sampler: string;
  scheduler: string;
  batchSize: number;
  numImages: number;
  denoiseStrength: number;
  guidanceScale: number;
  creativity: number;
  promptWeight: number;
  negativeWeight: number;
  aspectId: string;
  customWidth: number;
  customHeight: number;
  useCustomResolution: boolean;
}

export interface ReferenceSlot {
  id: string;
  type: 'style' | 'character' | 'face' | 'pose' | 'object' | 'sketch' | 'source';
  file?: File;
  preview?: string;
  weight: number;
}

export interface PromptTemplate {
  id: string;
  category: string;
  title: string;
  prompt: string;
  negative?: string;
}

export interface GeneratedImage {
  id: string;
  url: string;
  blob: Blob;
  prompt: string;
  negativePrompt: string;
  seed: number;
  model: string;
  width: number;
  height: number;
  style: string;
  mode: GenerationMode;
  createdAt: number;
  favorite?: boolean;
}

export interface EditAdjustments {
  brightness: number;
  contrast: number;
  saturation: number;
  sharpness: number;
  blur: number;
  hue: number;
  warmth: number;
}

export interface CreativeScores {
  quality: number;
  creativity: number;
  commercial: number;
  composition: number;
  lighting: number;
  nsfwRisk: number;
}

export interface StudioSession {
  prompt: string;
  negativePrompt: string;
  style: string;
  mode: GenerationMode;
  controls: GenerationControls;
  references: ReferenceSlot[];
  history: GeneratedImage[];
  favorites: string[];
  undoStack: string[];
  redoStack: string[];
}

export interface BatchJob {
  id: string;
  prompt: string;
  status: 'queued' | 'processing' | 'done' | 'error';
  result?: GeneratedImage;
  error?: string;
}

const SESSION_KEY = 'toolnest_ai_image_studio_v15';

/* ─── Constants ─────────────────────────────────────────────────────────── */

export const STUDIO_STEPS: { id: StudioStep; label: string }[] = [
  { id: 'prompt', label: 'Prompt' },
  { id: 'generate', label: 'Generate' },
  { id: 'edit', label: 'Edit' },
  { id: 'export', label: 'Export' },
];

export const GENERATION_MODES: { id: GenerationMode; label: string; icon: string }[] = [
  { id: 'text-to-image', label: 'Text → Image', icon: 'sparkles' },
  { id: 'image-to-image', label: 'Image → Image', icon: 'image' },
  { id: 'multi-fusion', label: 'Multi Fusion', icon: 'merge' },
  { id: 'character-ref', label: 'Character Ref', icon: 'user' },
  { id: 'style-ref', label: 'Style Ref', icon: 'wand' },
  { id: 'face-ref', label: 'Face Ref', icon: 'user-square' },
  { id: 'pose-ref', label: 'Pose Ref', icon: 'hand' },
  { id: 'object-ref', label: 'Object Ref', icon: 'folder' },
  { id: 'sketch-to-image', label: 'Sketch → Image', icon: 'pen' },
  { id: 'line-art', label: 'Line Art', icon: 'pen' },
  { id: 'scribble', label: 'Scribble', icon: 'pen' },
  { id: 'logo', label: 'AI Logo', icon: 'hexagon' },
  { id: 'icon', label: 'AI Icon', icon: 'grid' },
  { id: 'sticker', label: 'AI Sticker', icon: 'star' },
  { id: 'wallpaper', label: 'Wallpaper', icon: 'image' },
  { id: 'poster', label: 'Poster', icon: 'grid' },
  { id: 'thumbnail', label: 'Thumbnail', icon: 'film' },
  { id: 'banner', label: 'Banner', icon: 'scaling' },
  { id: 'social-post', label: 'Social Post', icon: 'share' },
  { id: 'product-mockup', label: 'Product Mockup', icon: 'briefcase' },
  { id: 'interior', label: 'Interior Design', icon: 'home' },
  { id: 'fashion', label: 'Fashion', icon: 'scissors' },
  { id: 'tattoo', label: 'Tattoo', icon: 'pen' },
  { id: 'architecture', label: 'Architecture', icon: 'landmark' },
  { id: 'game-asset', label: 'Game Assets', icon: 'bot' },
  { id: 'pixel-art', label: 'Pixel Art', icon: 'grid' },
  { id: 'nft', label: 'NFT Creator', icon: 'link' },
  { id: 'qr-art', label: 'QR Art', icon: 'qr' },
];

export const AI_MODELS: AiModel[] = [
  { id: 'flux', label: 'FLUX Ultra', provider: 'Black Forest', tier: 'free', description: 'Best overall quality' },
  { id: 'flux-pro', label: 'FLUX Pro', provider: 'Black Forest', tier: 'free', description: 'Professional grade' },
  { id: 'turbo', label: 'SDXL Turbo', provider: 'Stability', tier: 'free', description: 'Fast iterations' },
  { id: 'sdxl', label: 'Stable Diffusion XL', provider: 'Stability', tier: 'free', description: 'Versatile classic' },
  { id: 'sd3', label: 'Stable Diffusion 3.5', provider: 'Stability', tier: 'free', description: 'Latest SD architecture' },
  { id: 'openai', label: 'DALL·E Style', provider: 'OpenAI', tier: 'free', description: 'Creative compositions' },
  { id: 'imagen', label: 'Google Imagen', provider: 'Google', tier: 'free', description: 'Photorealistic' },
  { id: 'realistic', label: 'Realistic Vision', provider: 'Community', tier: 'free', description: 'Photo realism' },
  { id: 'juggernaut', label: 'Juggernaut XL', provider: 'Community', tier: 'free', description: 'Cinematic scenes' },
  { id: 'dreamshaper', label: 'DreamShaper', provider: 'Community', tier: 'free', description: 'Artistic dreams' },
  { id: 'epic', label: 'Epic Realism', provider: 'Community', tier: 'free', description: 'Epic detail' },
  { id: 'anime', label: 'Anime XL', provider: 'Community', tier: 'free', description: 'Anime & manga' },
  { id: 'pony', label: 'Pony XL', provider: 'Community', tier: 'free', description: 'Stylized characters' },
];

export const STYLES = [
  'None', 'Photorealistic', 'Hyper Realistic', 'Cinematic', 'Movie Poster', 'Anime', 'Ghibli',
  'Disney', 'Pixar', 'Fantasy', 'Sci-Fi', 'Cyberpunk', 'Luxury', 'Minimal', 'Dark', 'Gaming',
  '3D Render', 'Clay', 'Comic', 'Watercolor', 'Oil Painting', 'Sketch', 'Neon', 'Isometric',
  'Pixel Art', 'Low Poly', 'Architecture', 'Fashion', 'Food', 'Product', 'Portrait', 'Landscape',
];

export const ASPECT_PRESETS: AspectPreset[] = [
  { id: '1:1', label: 'Square 1:1', w: 1024, h: 1024 },
  { id: '4:3', label: 'Standard 4:3', w: 1024, h: 768 },
  { id: '3:4', label: 'Portrait 3:4', w: 768, h: 1024 },
  { id: '16:9', label: 'Widescreen 16:9', w: 1280, h: 720 },
  { id: '9:16', label: 'Vertical 9:16', w: 720, h: 1280 },
  { id: '21:9', label: 'Ultrawide 21:9', w: 1536, h: 640 },
  { id: '2:3', label: 'Photo 2:3', w: 832, h: 1248 },
  { id: '3:2', label: 'Photo 3:2', w: 1248, h: 832 },
];

export const RESOLUTIONS = [512, 768, 1024, 1536, 2048, 4096];

export const SAMPLERS = ['Euler', 'Euler a', 'DPM++ 2M', 'DPM++ SDE', 'DDIM', 'LMS', 'Heun', 'UniPC'];
export const SCHEDULERS = ['Normal', 'Karras', 'Exponential', 'SGM Uniform', 'Simple'];

export const PROMPT_TEMPLATES: PromptTemplate[] = [
  { id: 'p1', category: 'Portrait', title: 'Cinematic Portrait', prompt: 'cinematic portrait, dramatic lighting, shallow depth of field, 85mm lens, professional photography', negative: 'blurry, distorted, low quality' },
  { id: 'p2', category: 'Landscape', title: 'Epic Landscape', prompt: 'epic landscape, golden hour, volumetric light, ultra detailed, 8k', negative: 'flat, dull, oversaturated' },
  { id: 'p3', category: 'Product', title: 'Product Shot', prompt: 'professional product photography, studio lighting, clean white background, commercial quality', negative: 'cluttered, shadows, noise' },
  { id: 'p4', category: 'Logo', title: 'Minimal Logo', prompt: 'minimal vector logo, clean lines, modern brand identity, flat design, professional', negative: 'complex, noisy, 3d' },
  { id: 'p5', category: 'Anime', title: 'Anime Character', prompt: 'anime character, detailed eyes, vibrant colors, studio ghibli inspired, masterpiece', negative: 'realistic, blurry, deformed' },
  { id: 'p6', category: 'Architecture', title: 'Modern Building', prompt: 'modern architecture, glass facade, golden hour, architectural photography, ultra sharp', negative: 'distorted, blurry' },
  { id: 'p7', category: 'Food', title: 'Food Photography', prompt: 'gourmet food photography, appetizing, natural lighting, shallow depth of field, restaurant quality', negative: 'unappetizing, dark, blurry' },
  { id: 'p8', category: 'Fantasy', title: 'Fantasy Scene', prompt: 'epic fantasy scene, magical atmosphere, detailed environment, concept art, cinematic', negative: 'flat, boring, low detail' },
  { id: 'p9', category: 'Cyberpunk', title: 'Cyberpunk City', prompt: 'cyberpunk cityscape, neon lights, rain, futuristic, blade runner inspired, cinematic', negative: 'daytime, boring, flat' },
  { id: 'p10', category: 'Interior', title: 'Luxury Interior', prompt: 'luxury interior design, modern minimalist, natural light, architectural digest style', negative: 'cluttered, dark, cheap' },
];

export const SURPRISE_PROMPTS = [
  'A luminous crystal forest at twilight with bioluminescent mushrooms and floating fireflies',
  'An astronaut painting on Mars with Earth visible in the sky, cinematic lighting',
  'A steampunk owl library with brass gears and warm amber light',
  'Underwater city with glass domes and colorful coral architecture',
  'A samurai standing in cherry blossom rain, ink wash painting style',
  'Futuristic Tokyo street food market at night, neon reflections on wet pavement',
  'A cozy cabin inside a giant tree, fairy lights, magical atmosphere',
  'Abstract geometric portrait made of liquid gold and deep purple smoke',
];

export const DEFAULT_CONTROLS: GenerationControls = {
  model: 'flux',
  cfgScale: 7,
  steps: 30,
  seed: Math.floor(Math.random() * 1e9),
  randomSeed: true,
  sampler: 'Euler a',
  scheduler: 'Karras',
  batchSize: 1,
  numImages: 1,
  denoiseStrength: 0.75,
  guidanceScale: 7.5,
  creativity: 50,
  promptWeight: 1,
  negativeWeight: 1,
  aspectId: '1:1',
  customWidth: 1024,
  customHeight: 1024,
  useCustomResolution: false,
};

export const DEFAULT_ADJUSTMENTS: EditAdjustments = {
  brightness: 0,
  contrast: 0,
  saturation: 0,
  sharpness: 0,
  blur: 0,
  hue: 0,
  warmth: 0,
};

/* ─── Prompt building ───────────────────────────────────────────────────── */

const MODE_PROMPT_SUFFIX: Partial<Record<GenerationMode, string>> = {
  logo: ', professional vector logo design, clean minimal, brand identity, flat design',
  icon: ', app icon design, clean minimal, rounded corners, professional UI icon',
  sticker: ', cute sticker design, die-cut, vibrant colors, white border',
  wallpaper: ', desktop wallpaper, ultra wide, cinematic, high resolution',
  poster: ', movie poster design, dramatic composition, typography space',
  thumbnail: ', YouTube thumbnail, bold colors, eye-catching, high contrast',
  banner: ', web banner design, professional marketing, clean layout',
  'social-post': ', social media post, Instagram aesthetic, engaging composition',
  'product-mockup': ', product mockup, studio lighting, commercial photography',
  interior: ', interior design render, architectural visualization, photorealistic',
  fashion: ', high fashion photography, runway style, editorial quality',
  tattoo: ', tattoo design, clean linework, black ink style, detailed',
  architecture: ', architectural visualization, modern building, photorealistic render',
  'game-asset': ', game asset, stylized, clean design, game ready',
  'pixel-art': ', pixel art, 16-bit style, retro gaming aesthetic',
  nft: ', NFT artwork, unique digital art, vibrant, collectible style',
  'qr-art': ', artistic QR code integration, scannable design, creative pattern',
};

function uid(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

export function getResolution(controls: GenerationControls): { w: number; h: number } {
  if (controls.useCustomResolution) {
    return {
      w: Math.min(8192, Math.max(256, controls.customWidth)),
      h: Math.min(8192, Math.max(256, controls.customHeight)),
    };
  }
  const preset = ASPECT_PRESETS.find((a) => a.id === controls.aspectId) || ASPECT_PRESETS[0];
  const scale = Math.min(1, 2048 / Math.max(preset.w, preset.h));
  return { w: Math.round(preset.w * scale), h: Math.round(preset.h * scale) };
}

export function buildFullPrompt(
  prompt: string,
  style: string,
  mode: GenerationMode,
  negativePrompt: string,
  controls: GenerationControls,
): { positive: string; negative: string } {
  let positive = prompt.trim();
  if (style && style !== 'None') positive += `, ${style.toLowerCase()} style`;
  const suffix = MODE_PROMPT_SUFFIX[mode];
  if (suffix) positive += suffix;
  if (controls.creativity > 70) positive += ', highly creative, unique composition, artistic';
  if (controls.creativity < 30) positive += ', precise, accurate, faithful to description';
  positive += ', high quality, detailed, professional';

  let negative = negativePrompt.trim();
  if (!negative) negative = 'blurry, low quality, distorted, deformed, ugly, bad anatomy, watermark, text, signature';
  if (controls.negativeWeight > 1) negative += ', worst quality, low resolution, jpeg artifacts';

  return { positive, negative };
}

export function scorePrompt(prompt: string): { score: number; tokens: number; suggestions: string[] } {
  const tokens = prompt.trim().split(/\s+/).filter(Boolean).length;
  const suggestions: string[] = [];
  let score = 40;

  if (tokens >= 5) score += 15;
  if (tokens >= 10) score += 10;
  if (tokens >= 20) score += 5;
  if (tokens > 60) { score -= 10; suggestions.push('Consider shortening — very long prompts may dilute focus'); }

  const qualityWords = /cinematic|detailed|professional|lighting|8k|masterpiece|ultra|sharp|vivid/i;
  const styleWords = /style|aesthetic|mood|atmosphere|color palette/i;
  const subjectWords = /portrait|landscape|character|product|logo|building|scene/i;

  if (qualityWords.test(prompt)) score += 10;
  else suggestions.push('Add quality terms: cinematic, detailed, professional');
  if (styleWords.test(prompt)) score += 8;
  else suggestions.push('Describe style or mood for better results');
  if (subjectWords.test(prompt)) score += 7;
  else suggestions.push('Be specific about the subject');

  return { score: Math.min(100, score), tokens, suggestions };
}

export function randomPrompt(): string {
  return SURPRISE_PROMPTS[Math.floor(Math.random() * SURPRISE_PROMPTS.length)];
}

/* ─── AI Prompt Studio ──────────────────────────────────────────────────── */

const PROMPT_SYSTEM = 'You are an expert AI image prompt engineer for Stable Diffusion and FLUX models. Output only the requested prompt text, no explanations or quotes.';

const LOCAL_QUALITY_TAGS = 'highly detailed, sharp focus, professional quality, vivid lighting, masterpiece';

function withLocalFallback(aiFn: () => Promise<string>, localFn: () => string): () => Promise<string> {
  return async () => {
    try {
      const result = await aiFn();
      if (result.trim()) return result.trim();
    } catch { /* use local */ }
    return localFn();
  };
}

export function enhancePromptLocal(prompt: string, style: string): string {
  const styleBit = style && style !== 'None' ? `, ${style.toLowerCase()} style` : '';
  return `${prompt.trim()}${styleBit}, ${LOCAL_QUALITY_TAGS}, cinematic composition, 8k uhd`;
}

export function rewritePromptLocal(prompt: string): string {
  const words = prompt.trim().split(/\s+/);
  if (words.length < 4) return enhancePromptLocal(prompt, 'None');
  const shuffled = [...words].sort(() => Math.random() - 0.5);
  return shuffled.join(' ');
}

export function expandPromptLocal(prompt: string): string {
  return `${prompt.trim()}, atmospheric depth, rich textures, dynamic lighting, intricate details, ${LOCAL_QUALITY_TAGS}`;
}

export function shortenPromptLocal(prompt: string): string {
  return prompt.trim().split(/\s+/).slice(0, 35).join(' ');
}

export function magicPromptLocal(prompt: string, mode: GenerationMode): string {
  const base = prompt.trim() || randomPrompt();
  const modeLabel = mode.replace(/-/g, ' ');
  return `${base}, stunning ${modeLabel} artwork, ${LOCAL_QUALITY_TAGS}, trending on artstation`;
}

export async function enhancePrompt(prompt: string, style: string): Promise<string> {
  return withLocalFallback(
    () => aiComplete([{ role: 'user', content: `Enhance this image prompt with vivid details, lighting, composition, and quality tags. Style hint: ${style}.\n\nPrompt: ${prompt}` }], PROMPT_SYSTEM),
    () => enhancePromptLocal(prompt, style),
  )();
}

export async function rewritePrompt(prompt: string): Promise<string> {
  return withLocalFallback(
    () => aiComplete([{ role: 'user', content: `Rewrite this image prompt with different wording but same intent:\n\n${prompt}` }], PROMPT_SYSTEM),
    () => rewritePromptLocal(prompt),
  )();
}

export async function expandPrompt(prompt: string): Promise<string> {
  return withLocalFallback(
    () => aiComplete([{ role: 'user', content: `Expand this image prompt with more visual details, atmosphere, and technical quality tags:\n\n${prompt}` }], PROMPT_SYSTEM),
    () => expandPromptLocal(prompt),
  )();
}

export async function shortenPrompt(prompt: string): Promise<string> {
  return withLocalFallback(
    () => aiComplete([{ role: 'user', content: `Shorten this image prompt to under 40 words while keeping the core visual intent:\n\n${prompt}` }], PROMPT_SYSTEM),
    () => shortenPromptLocal(prompt),
  )();
}

export async function translatePrompt(prompt: string, lang: string): Promise<string> {
  return withLocalFallback(
    () => aiComplete([{ role: 'user', content: `Translate this image generation prompt to ${lang}. Keep technical art terms in English where appropriate:\n\n${prompt}` }], PROMPT_SYSTEM),
    () => prompt,
  )();
}

export async function magicPrompt(prompt: string, mode: GenerationMode): Promise<string> {
  return withLocalFallback(
    () => aiComplete([{ role: 'user', content: `Create a stunning, detailed image prompt for ${mode.replace(/-/g, ' ')} mode. User idea: ${prompt || 'surprise me with something creative'}` }], PROMPT_SYSTEM),
    () => magicPromptLocal(prompt, mode),
  )();
}

/** Free client-side reference analysis — extracts colors & mood from uploaded image. */
export async function analyzeReferenceVisual(file: File | Blob): Promise<string> {
  const canvas = await loadBlobToCanvas(file);
  const ctx = canvas.getContext('2d')!;
  const { width, height } = canvas;
  const sample = ctx.getImageData(0, 0, Math.min(width, 128), Math.min(height, 128)).data;

  const buckets = new Map<string, number>();
  let lumSum = 0;
  let satSum = 0;
  let edgeSum = 0;
  const step = 4;

  for (let i = 0; i < sample.length; i += step * 4) {
    const r = sample[i];
    const g = sample[i + 1];
    const b = sample[i + 2];
    const key = `${Math.round(r / 32) * 32},${Math.round(g / 32) * 32},${Math.round(b / 32) * 32}`;
    buckets.set(key, (buckets.get(key) || 0) + 1);
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    lumSum += lum;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    satSum += max === 0 ? 0 : (max - min) / max;
    if (i > 0) {
      const prev = sample[i - step * 4];
      edgeSum += Math.abs(r - prev);
    }
  }

  const pixels = sample.length / (step * 4);
  const topColors = [...buckets.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3)
    .map(([rgb]) => `rgb(${rgb})`);
  const avgLum = lumSum / pixels;
  const avgSat = satSum / pixels;
  const mood = avgLum < 80 ? 'dark moody atmosphere' : avgLum > 180 ? 'bright airy atmosphere' : 'balanced natural lighting';
  const palette = avgSat > 0.35 ? 'vibrant color palette' : 'muted subtle palette';
  const sketchy = edgeSum / pixels > 40 ? 'sketch-like linework' : 'smooth photographic';
  const orient = width > height * 1.2 ? 'landscape composition' : height > width * 1.2 ? 'portrait composition' : 'square composition';

  return `${orient}, ${mood}, ${palette}, dominant colors ${topColors.join(', ')}, ${sketchy}`;
}

export async function analyzeImageCreative(blob: Blob, prompt = ''): Promise<CreativeScores> {
  try {
    const canvas = await loadBlobToCanvas(blob);
    const ctx = canvas.getContext('2d')!;
    const w = Math.min(canvas.width, 256);
    const h = Math.min(canvas.height, 256);
    const [small] = [document.createElement('canvas')];
    small.width = w;
    small.height = h;
    small.getContext('2d')!.drawImage(canvas, 0, 0, w, h);
    const data = small.getContext('2d')!.getImageData(0, 0, w, h).data;

    let lumVar = 0;
    let sat = 0;
    let edges = 0;
    const lums: number[] = [];

    for (let i = 0; i < data.length; i += 16) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const lum = 0.299 * r + 0.587 * g + 0.114 * b;
      lums.push(lum);
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      sat += max === 0 ? 0 : (max - min) / max;
      if (i > 0) edges += Math.abs(r - data[i - 16]);
    }

    const mean = lums.reduce((a, b) => a + b, 0) / lums.length;
    lumVar = Math.sqrt(lums.reduce((a, l) => a + (l - mean) ** 2, 0) / lums.length);
    const avgSat = sat / (data.length / 16);
    const edgeScore = edges / (data.length / 16);
    const megapixels = (canvas.width * canvas.height) / 1e6;

    const quality = Math.min(98, Math.round(55 + edgeScore * 0.4 + Math.min(megapixels * 20, 25)));
    const creativity = Math.min(98, Math.round(50 + avgSat * 45 + lumVar * 0.15));
    const commercial = Math.min(98, Math.round(60 + (lumVar > 25 && lumVar < 70 ? 20 : 10) + (avgSat > 0.25 ? 10 : 0)));
    const composition = Math.min(98, Math.round(55 + lumVar * 0.35));
    const lighting = Math.min(98, Math.round(50 + lumVar * 0.5));
    const nsfwRisk = /nude|naked|nsfw|explicit/i.test(prompt) ? 35 : 5;

    return { quality, creativity, commercial, composition, lighting, nsfwRisk };
  } catch {
    return { quality: 75, creativity: 70, commercial: 65, composition: 72, lighting: 68, nsfwRisk: 5 };
  }
}

/* ─── Generation ────────────────────────────────────────────────────────── */

const IMG2IMG_MODES: GenerationMode[] = [
  'image-to-image', 'multi-fusion', 'character-ref', 'style-ref', 'face-ref',
  'pose-ref', 'object-ref', 'sketch-to-image', 'line-art', 'scribble',
];

async function buildReferencePrompt(references: ReferenceSlot[], mode: GenerationMode): Promise<string> {
  const active = references.filter((r) => r.file && r.weight > 0);
  if (!active.length) return '';

  const hints: string[] = [];
  for (const ref of active.slice(0, 3)) {
    if (!ref.file) continue;
    const visual = await analyzeReferenceVisual(ref.file);
    const weight = Math.round(ref.weight * 100);
    hints.push(`${ref.type} reference (${weight}%): ${visual}`);
  }

  if (IMG2IMG_MODES.includes(mode) && hints.length) {
    return `, inspired by reference image — ${hints.join('; ')}`;
  }
  if (hints.length) return `, incorporating ${hints.join('; ')}`;
  return '';
}

export async function generateStudioImage(opts: {
  prompt: string;
  negativePrompt: string;
  style: string;
  mode: GenerationMode;
  controls: GenerationControls;
  references?: ReferenceSlot[];
  signal?: AbortSignal;
  onProgress?: (pct: number) => void;
}): Promise<GeneratedImage> {
  const { positive, negative } = buildFullPrompt(opts.prompt, opts.style, opts.mode, opts.negativePrompt, opts.controls);
  const { w, h } = getResolution(opts.controls);
  const seed = opts.controls.randomSeed ? Math.floor(Math.random() * 1e9) : opts.controls.seed;
  const model = mapPollinationsModel(opts.controls.model);

  let finalPrompt = positive;
  const refSuffix = await buildReferencePrompt(opts.references || [], opts.mode);
  if (refSuffix) finalPrompt += refSuffix;

  opts.onProgress?.(10);

  const blob = await generateFreePollinationsImage({
    prompt: finalPrompt,
    negative,
    width: w,
    height: h,
    seed,
    model,
    enhance: opts.controls.cfgScale > 7,
    signal: opts.signal,
  });

  opts.onProgress?.(100);

  return {
    id: uid(),
    url: URL.createObjectURL(blob),
    blob,
    prompt: opts.prompt,
    negativePrompt: opts.negativePrompt,
    seed,
    model: opts.controls.model,
    width: w,
    height: h,
    style: opts.style,
    mode: opts.mode,
    createdAt: Date.now(),
  };
}

export async function generateBatch(
  prompts: string[],
  baseOpts: Omit<Parameters<typeof generateStudioImage>[0], 'prompt' | 'onProgress'>,
  onJobUpdate?: (jobs: BatchJob[]) => void,
): Promise<BatchJob[]> {
  const jobs: BatchJob[] = prompts.map((p) => ({ id: uid(), prompt: p, status: 'queued' }));
  onJobUpdate?.(jobs);

  for (let i = 0; i < jobs.length; i++) {
    jobs[i] = { ...jobs[i], status: 'processing' };
    onJobUpdate?.([...jobs]);
    try {
      const result = await generateStudioImage({ ...baseOpts, prompt: jobs[i].prompt });
      jobs[i] = { ...jobs[i], status: 'done', result };
    } catch (e) {
      jobs[i] = { ...jobs[i], status: 'error', error: e instanceof Error ? e.message : 'Failed' };
    }
    onJobUpdate?.([...jobs]);
  }
  return jobs;
}

/* ─── Image editing & enhancement ───────────────────────────────────────── */

export async function loadBlobToCanvas(blob: Blob): Promise<HTMLCanvasElement> {
  const img = await loadImage(blob);
  const [c, ctx] = makeCanvas(img.width, img.height);
  ctx.drawImage(img, 0, 0);
  return c;
}

export function applyAdjustments(canvas: HTMLCanvasElement, adj: EditAdjustments): HTMLCanvasElement {
  const [out, ctx] = makeCanvas(canvas.width, canvas.height);
  ctx.filter = [
    `brightness(${100 + adj.brightness}%)`,
    `contrast(${100 + adj.contrast}%)`,
    `saturate(${100 + adj.saturation}%)`,
    `blur(${adj.blur}px)`,
    `hue-rotate(${adj.hue}deg)`,
    adj.warmth !== 0 ? `sepia(${Math.abs(adj.warmth)}%)` : '',
  ].filter(Boolean).join(' ');
  ctx.drawImage(canvas, 0, 0);
  if (adj.sharpness > 0) sharpen(out, adj.sharpness / 100);
  return out;
}

export async function upscaleCanvas(canvas: HTMLCanvasElement, factor: 2 | 4 | 8): Promise<HTMLCanvasElement> {
  const [out, ctx] = makeCanvas(canvas.width * factor, canvas.height * factor);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(canvas, 0, 0, out.width, out.height);
  if (factor >= 2) sharpen(out, 0.25);
  if (factor >= 4) autoEnhance(out);
  return out;
}

export async function expandCanvasImage(canvas: HTMLCanvasElement, paddingPct: number): Promise<HTMLCanvasElement> {
  const padX = Math.round(canvas.width * (paddingPct / 100));
  const padY = Math.round(canvas.height * (paddingPct / 100));
  const [out, ctx] = makeCanvas(canvas.width + padX * 2, canvas.height + padY * 2);
  const grad = ctx.createRadialGradient(out.width / 2, out.height / 2, 0, out.width / 2, out.height / 2, Math.max(out.width, out.height) / 2);
  grad.addColorStop(0, '#1a1a28');
  grad.addColorStop(1, '#0a0a12');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, out.width, out.height);
  ctx.drawImage(canvas, padX, padY);
  return out;
}

export async function blurBackground(canvas: HTMLCanvasElement, amount: number): Promise<HTMLCanvasElement> {
  const [out, ctx] = makeCanvas(canvas.width, canvas.height);
  ctx.filter = `blur(${amount}px)`;
  ctx.drawImage(canvas, 0, 0);
  ctx.filter = 'none';
  const [fg, fctx] = makeCanvas(canvas.width, canvas.height);
  fctx.drawImage(canvas, 0, 0);
  const cx = canvas.width * 0.5;
  const cy = canvas.height * 0.45;
  const rx = canvas.width * 0.28;
  const ry = canvas.height * 0.35;
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
  ctx.clip();
  ctx.drawImage(fg, 0, 0);
  ctx.restore();
  return out;
}

export async function exportImage(
  blob: Blob,
  format: ExportFormat,
  quality = 0.92,
  transparent = false,
): Promise<Blob> {
  const canvas = await loadBlobToCanvas(blob);
  const mimeMap: Record<ExportFormat, string> = {
    png: 'image/png',
    jpg: 'image/jpeg',
    webp: 'image/webp',
    bmp: 'image/bmp',
    tiff: 'image/png',
    avif: 'image/webp',
  };
  if (transparent && format === 'png') {
    return canvasToBlob(canvas, 'image/png');
  }
  return canvasToBlob(canvas, mimeMap[format], quality);
}

/* ─── Session persistence ───────────────────────────────────────────────── */

export function saveSession(data: Partial<StudioSession>): void {
  try {
    const existing = loadSession();
    localStorage.setItem(SESSION_KEY, JSON.stringify({ ...existing, ...data }));
  } catch { /* quota */ }
}

export function loadSession(): Partial<StudioSession> {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? JSON.parse(raw) as Partial<StudioSession> : {};
  } catch {
    return {};
  }
}

export function saveToHistory(image: GeneratedImage): GeneratedImage[] {
  const session = loadSession();
  const history = (session.history || []).slice(0, 49);
  history.unshift({ ...image, url: '' });
  saveSession({ history });
  return history;
}

export function getPromptHistory(): string[] {
  try {
    const raw = localStorage.getItem(`${SESSION_KEY}_prompts`);
    return raw ? JSON.parse(raw) as string[] : [];
  } catch {
    return [];
  }
}

export function addPromptHistory(prompt: string): void {
  const list = getPromptHistory().filter((p) => p !== prompt);
  list.unshift(prompt);
  localStorage.setItem(`${SESSION_KEY}_prompts`, JSON.stringify(list.slice(0, 30)));
}
