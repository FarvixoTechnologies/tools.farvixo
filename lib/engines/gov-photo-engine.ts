/**
 * Unified Government Photo Engine — single source of truth for all 8 gov tools.
 * Re-exports processing from lib/gov-photo.ts and adds spec catalog + simulator.
 */

export {
  PAN_SPECS,
  DEFAULT_EDIT,
  autoEditFromFace,
  complianceScore,
  validateCompliance,
  renderToSpec,
  encodeForSpec,
  prepareSourceCanvas,
  detectFace,
  generatePrintSheet,
  downloadZip,
  isPdfFileAsync,
  type PanPortal,
  type PanFileType,
  type PanSpec,
  type EditState,
  type FaceAnalysis,
  type ComplianceItem,
  type ComplianceStatus,
} from '@/lib/gov-photo';
import type { EditState as GovEditState, PanSpec, ComplianceItem } from '@/lib/gov-photo';

export type GovFileKind = 'photo' | 'signature' | 'document';

export interface GovSpec {
  id: string;
  label: string;
  labelHi: string;
  portal?: string;
  width: number;
  height: number;
  dpi: number;
  minKB: number;
  maxKB: number;
  format: 'jpeg' | 'pdf';
  physicalCm?: string;
  fileKind: GovFileKind;
  toolSlug: string;
  faceRequired: boolean;
}

/** All government ID specs — PAN portals + standalone tools. */
export const GOV_SPECS: Record<string, GovSpec> = {
  'pan-nsdl-photo': {
    id: 'pan-nsdl-photo', label: 'PAN Photo (NSDL)', labelHi: 'PAN फोटो (NSDL)',
    portal: 'NSDL', width: 197, height: 276, dpi: 200, minKB: 20, maxKB: 50,
    format: 'jpeg', physicalCm: '3.5 × 2.5 cm', fileKind: 'photo', toolSlug: 'pan-card-photo-resizer', faceRequired: true,
  },
  'pan-nsdl-signature': {
    id: 'pan-nsdl-signature', label: 'PAN Signature (NSDL)', labelHi: 'PAN हस्ताक्षर (NSDL)',
    portal: 'NSDL', width: 354, height: 157, dpi: 200, minKB: 10, maxKB: 50,
    format: 'jpeg', physicalCm: '4.5 × 2 cm', fileKind: 'signature', toolSlug: 'pan-card-photo-resizer', faceRequired: false,
  },
  'pan-uti-photo': {
    id: 'pan-uti-photo', label: 'PAN Photo (UTI)', labelHi: 'PAN फोटो (UTI)',
    portal: 'UTI', width: 213, height: 213, dpi: 300, minKB: 5, maxKB: 30,
    format: 'jpeg', fileKind: 'photo', toolSlug: 'pan-card-photo-resizer', faceRequired: true,
  },
  'pan-uti-signature': {
    id: 'pan-uti-signature', label: 'PAN Signature (UTI)', labelHi: 'PAN हस्ताक्षर (UTI)',
    portal: 'UTI', width: 400, height: 200, dpi: 600, minKB: 5, maxKB: 60,
    format: 'jpeg', fileKind: 'signature', toolSlug: 'pan-card-photo-resizer', faceRequired: false,
  },
  'aadhaar-photo': {
    id: 'aadhaar-photo', label: 'Aadhaar Photo', labelHi: 'आधार फोटो',
    portal: 'UIDAI', width: 300, height: 400, dpi: 200, minKB: 20, maxKB: 100,
    format: 'jpeg', fileKind: 'photo', toolSlug: 'aadhaar-photo-resizer', faceRequired: true,
  },
  'passport-india': {
    id: 'passport-india', label: 'India Passport', labelHi: 'भारतीय पासपोर्ट',
    portal: 'ICAO', width: 413, height: 531, dpi: 300, minKB: 10, maxKB: 100,
    format: 'jpeg', physicalCm: '35×45 mm', fileKind: 'photo', toolSlug: 'passport-photo-maker', faceRequired: true,
  },
  'passport-us': {
    id: 'passport-us', label: 'US Passport', labelHi: 'US पासपोर्ट',
    portal: 'ICAO', width: 600, height: 600, dpi: 300, minKB: 10, maxKB: 240,
    format: 'jpeg', physicalCm: '2×2 in', fileKind: 'photo', toolSlug: 'passport-photo-maker', faceRequired: true,
  },
  'passport-uk': {
    id: 'passport-uk', label: 'UK Passport', labelHi: 'UK पासपोर्ट',
    portal: 'ICAO', width: 413, height: 531, dpi: 300, minKB: 10, maxKB: 100,
    format: 'jpeg', physicalCm: '35×45 mm', fileKind: 'photo', toolSlug: 'passport-photo-maker', faceRequired: true,
  },
  'passport-schengen': {
    id: 'passport-schengen', label: 'Schengen Visa', labelHi: 'शेंगेन वीज़ा',
    portal: 'ICAO', width: 413, height: 531, dpi: 300, minKB: 10, maxKB: 100,
    format: 'jpeg', physicalCm: '35×45 mm', fileKind: 'photo', toolSlug: 'passport-photo-maker', faceRequired: true,
  },
  'passport-signature-small': {
    id: 'passport-signature-small', label: 'Passport Signature (small)', labelHi: 'पासपोर्ट हस्ताक्षर (छोटा)',
    width: 200, height: 100, dpi: 200, minKB: 5, maxKB: 20,
    format: 'jpeg', fileKind: 'signature', toolSlug: 'passport-signature-resizer', faceRequired: false,
  },
  'passport-signature-large': {
    id: 'passport-signature-large', label: 'Passport Signature (large)', labelHi: 'पासपोर्ट हस्ताक्षर (बड़ा)',
    width: 400, height: 200, dpi: 200, minKB: 10, maxKB: 50,
    format: 'jpeg', fileKind: 'signature', toolSlug: 'passport-signature-resizer', faceRequired: false,
  },
  'voter-photo': {
    id: 'voter-photo', label: 'Voter ID Photo', labelHi: 'मतदाता ID फोटो',
    portal: 'ECI', width: 240, height: 320, dpi: 200, minKB: 10, maxKB: 100,
    format: 'jpeg', fileKind: 'photo', toolSlug: 'voter-id-photo-resizer', faceRequired: true,
  },
  'dl-photo': {
    id: 'dl-photo', label: 'DL Photo', labelHi: 'DL फोटो',
    portal: 'Sarathi', width: 420, height: 525, dpi: 200, minKB: 20, maxKB: 200,
    format: 'jpeg', fileKind: 'photo', toolSlug: 'driving-licence-photo-resizer', faceRequired: true,
  },
  'dl-signature': {
    id: 'dl-signature', label: 'DL Signature', labelHi: 'DL हस्ताक्षर',
    width: 256, height: 64, dpi: 200, minKB: 2, maxKB: 10,
    format: 'jpeg', fileKind: 'signature', toolSlug: 'driving-licence-photo-resizer', faceRequired: false,
  },
  'ssc-photo': {
    id: 'ssc-photo', label: 'SSC Photo', labelHi: 'SSC फोटो',
    width: 413, height: 531, dpi: 200, minKB: 100, maxKB: 120,
    format: 'jpeg', physicalCm: '3.5×4.5 cm', fileKind: 'photo', toolSlug: 'exam-photo-signature-resizer', faceRequired: true,
  },
  'ssc-signature': {
    id: 'ssc-signature', label: 'SSC Signature', labelHi: 'SSC हस्ताक्षर',
    width: 472, height: 236, dpi: 200, minKB: 5, maxKB: 20,
    format: 'jpeg', physicalCm: '4×2 cm', fileKind: 'signature', toolSlug: 'exam-photo-signature-resizer', faceRequired: false,
  },
  'upsc-photo': {
    id: 'upsc-photo', label: 'UPSC Photo', labelHi: 'UPSC फोटो',
    width: 350, height: 350, dpi: 200, minKB: 20, maxKB: 300,
    format: 'jpeg', fileKind: 'photo', toolSlug: 'exam-photo-signature-resizer', faceRequired: true,
  },
  'ibps-photo': {
    id: 'ibps-photo', label: 'IBPS Photo', labelHi: 'IBPS फोटो',
    width: 200, height: 230, dpi: 200, minKB: 20, maxKB: 50,
    format: 'jpeg', fileKind: 'photo', toolSlug: 'exam-photo-signature-resizer', faceRequired: true,
  },
  'ibps-signature': {
    id: 'ibps-signature', label: 'IBPS Signature', labelHi: 'IBPS हस्ताक्षर',
    width: 140, height: 60, dpi: 200, minKB: 5, maxKB: 20,
    format: 'jpeg', fileKind: 'signature', toolSlug: 'exam-photo-signature-resizer', faceRequired: false,
  },
  'neet-photo': {
    id: 'neet-photo', label: 'NEET/JEE Photo', labelHi: 'NEET/JEE फोटो',
    width: 1200, height: 1800, dpi: 200, minKB: 50, maxKB: 200,
    format: 'jpeg', physicalCm: '4×6 in', fileKind: 'photo', toolSlug: 'exam-photo-signature-resizer', faceRequired: true,
  },
};

export function getGovSpec(id: string): GovSpec | undefined {
  return GOV_SPECS[id];
}

export function govSpecToPanSpec(spec: GovSpec): PanSpec {
  return {
    w: spec.width,
    h: spec.height,
    dpi: spec.dpi,
    minKB: spec.minKB,
    maxKB: spec.maxKB,
    format: spec.format,
    cmLabel: spec.physicalCm ?? `${spec.width}×${spec.height} px`,
  };
}

export interface ExtendedEditState extends GovEditState {
  saturation: number;
  exposure: number;
  gamma: number;
}

export const DEFAULT_EXTENDED_EDIT: ExtendedEditState = {
  panX: 0.5, panY: 0.5, zoom: 1, rotation: 0, brightness: 100, contrast: 100,
  saturation: 100, exposure: 100, gamma: 100,
};

/** Apply extended color adjustments on canvas context before draw. */
export function applyExtendedFilters(
  ctx: CanvasRenderingContext2D,
  edit: ExtendedEditState,
): void {
  const sat = edit.saturation / 100;
  const exp = edit.exposure / 100;
  const bright = edit.brightness / 100;
  const contrast = edit.contrast / 100;
  ctx.filter = `brightness(${bright * exp}) contrast(${contrast}) saturate(${sat})`;
}

/** Portal acceptance simulator — 0–100 score. */
export function portalAcceptanceScore(
  compliance: ComplianceItem[],
  pro = false,
): { score: number; ready: boolean; hints: string[] } {
  const active = compliance.filter((c) => c.status !== 'skip');
  if (active.length === 0) return { score: 0, ready: false, hints: ['Upload a photo to begin'] };

  const weights: Record<string, number> = {
    dimensions: 15, filesize: 15, format: 10, dpi: 10, background: 12,
    face: 12, coverage: 10, eyes: 8, pose: 8, glare: 5, sharpness: 5, aspect: 5,
  };

  let earned = 0;
  let total = 0;
  const hints: string[] = [];

  for (const item of active) {
    const w = weights[item.id] ?? 5;
    total += w;
    if (item.status === 'pass') earned += w;
    else if (item.status === 'warn') earned += w * 0.5;
    if (item.status !== 'pass' && item.message) {
      hints.push(pro ? `${item.label}: ${item.message}` : item.label);
    }
  }

  const score = total > 0 ? Math.round((earned / total) * 100) : 0;
  const fails = active.filter((c) => c.status === 'fail').length;
  return { score, ready: fails === 0 && score >= (pro ? 85 : 70), hints: hints.slice(0, pro ? 12 : 3) };
}

/** Auto-trim signature to ink bounding box. */
export function autoTrimSignature(canvas: HTMLCanvasElement, padding = 8): HTMLCanvasElement {
  const ctx = canvas.getContext('2d')!;
  const { width, height } = canvas;
  const data = ctx.getImageData(0, 0, width, height).data;
  let minX = width, minY = height, maxX = 0, maxY = 0;

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const a = data[i + 3];
      const lum = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
      if (a > 20 && lum < 240) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }

  if (maxX <= minX) return canvas;

  const out = document.createElement('canvas');
  const ow = maxX - minX + padding * 2;
  const oh = maxY - minY + padding * 2;
  out.width = ow;
  out.height = oh;
  out.getContext('2d')!.drawImage(
    canvas,
    minX, minY, maxX - minX + 1, maxY - minY + 1,
    padding, padding, ow - padding * 2, oh - padding * 2,
  );
  return out;
}

/** Presets for Image Compressor — derived from GOV_SPECS (no conflicts). */
export function govPresetsForCompressor(): Array<{
  id: string;
  label: string;
  width: number;
  height: number;
  minKB?: number;
  maxKB: number;
  format: 'jpeg';
  description: string;
}> {
  const seen = new Set<string>();
  return Object.values(GOV_SPECS)
    .filter((s) => s.format === 'jpeg')
    .filter((s) => {
      if (seen.has(s.id)) return false;
      seen.add(s.id);
      return true;
    })
    .map((s) => ({
      id: s.id,
      label: s.label,
      width: s.width,
      height: s.height,
      minKB: s.minKB,
      maxKB: s.maxKB,
      format: 'jpeg' as const,
      description: `${s.portal ?? 'Gov'} · ${s.physicalCm ?? `${s.width}×${s.height}px`}`,
    }));
}

/** Gov Kit — common Indian ID bundle spec IDs. */
export const GOV_KIT_SPECS = [
  'pan-nsdl-photo',
  'pan-nsdl-signature',
  'aadhaar-photo',
  'passport-india',
] as const;
