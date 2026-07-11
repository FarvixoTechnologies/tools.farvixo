'use client';

import type { Tool } from '@/data/tools';
import OcrImageRunner from './OcrImageRunner';
import PdfOcrRunner from './PdfOcrRunner';

/** Routes image OCR to the Galactic Edition wizard; PDF OCR keeps the focused PDF flow. */
export default function OcrRunner({ tool }: { tool: Tool }) {
  if (tool.mode === 'image') return <OcrImageRunner tool={tool} />;
  return <PdfOcrRunner tool={tool} />;
}
