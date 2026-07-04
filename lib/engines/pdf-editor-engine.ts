'use client';

import { loadPdfJs } from '@/lib/pdf';
import type { PDFDocumentProxy } from 'pdfjs-dist';

export type EditorTool =
  | 'select'
  | 'text'
  | 'highlight'
  | 'underline'
  | 'rect'
  | 'ellipse'
  | 'draw'
  | 'image'
  | 'stamp';

export interface PageAnnotation {
  id: string;
  pageIndex: number;
  tool: EditorTool;
  x: number;
  y: number;
  width?: number;
  height?: number;
  text?: string;
  color?: string;
  fontSize?: number;
  points?: number[];
  imageDataUrl?: string;
  opacity?: number;
}

export interface EditorDocument {
  fileName: string;
  pageCount: number;
  annotations: PageAnnotation[];
}

let annId = 0;
export function newAnnotationId(): string {
  return `ann-${++annId}-${Date.now()}`;
}

export async function loadPdfDocument(file: File): Promise<PDFDocumentProxy> {
  const pdfjs = await loadPdfJs();
  const data = new Uint8Array(await file.arrayBuffer());
  return pdfjs.getDocument({ data, useSystemFonts: true }).promise;
}

export async function renderPageToCanvas(
  pdf: PDFDocumentProxy,
  pageNum: number,
  scale: number,
): Promise<HTMLCanvasElement> {
  const page = await pdf.getPage(pageNum);
  const viewport = page.getViewport({ scale });
  const canvas = document.createElement('canvas');
  canvas.width = viewport.width;
  canvas.height = viewport.height;
  const ctx = canvas.getContext('2d')!;
  await page.render({ canvasContext: ctx, viewport }).promise;
  return canvas;
}

export async function extractTextItems(pdf: PDFDocumentProxy, pageNum: number) {
  const page = await pdf.getPage(pageNum);
  const content = await page.getTextContent();
  return content.items
    .filter((item) => 'str' in item && typeof (item as { str?: string }).str === 'string')
    .map((item) => {
      const t = item as { str: string; transform: number[] };
      return {
        text: t.str,
        x: t.transform[4],
        y: t.transform[5],
        fontSize: Math.abs(t.transform[0]) || 12,
      };
    });
}

/** Bake annotations into PDF via pdf-lib. */
export async function exportAnnotatedPdf(
  originalBytes: ArrayBuffer,
  annotations: PageAnnotation[],
  scale: number,
): Promise<Uint8Array> {
  const { PDFDocument, StandardFonts, rgb, degrees } = await import('@cantoo/pdf-lib');
  const doc = await PDFDocument.load(originalBytes, { ignoreEncryption: true });
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const pages = doc.getPages();

  for (const ann of annotations) {
    const page = pages[ann.pageIndex];
    if (!page) continue;
    const { height: ph } = page.getSize();
    const pdfY = ph - ann.y / scale;

    switch (ann.tool) {
      case 'text':
        page.drawText(ann.text ?? '', {
          x: ann.x / scale,
          y: pdfY - (ann.fontSize ?? 14),
          size: ann.fontSize ?? 14,
          font,
          color: rgb(0.1, 0.1, 0.15),
        });
        break;
      case 'highlight':
        page.drawRectangle({
          x: ann.x / scale,
          y: pdfY - (ann.height ?? 20) / scale,
          width: (ann.width ?? 100) / scale,
          height: (ann.height ?? 20) / scale,
          color: rgb(1, 0.92, 0.23),
          opacity: 0.4,
        });
        break;
      case 'underline':
        page.drawLine({
          start: { x: ann.x / scale, y: pdfY },
          end: { x: (ann.x + (ann.width ?? 100)) / scale, y: pdfY },
          thickness: 1.5,
          color: rgb(0.9, 0.2, 0.2),
        });
        break;
      case 'rect':
        page.drawRectangle({
          x: ann.x / scale,
          y: pdfY - (ann.height ?? 40) / scale,
          width: (ann.width ?? 80) / scale,
          height: (ann.height ?? 40) / scale,
          borderColor: rgb(0.48, 0.23, 0.93),
          borderWidth: 2,
        });
        break;
      case 'ellipse':
        page.drawEllipse({
          x: (ann.x + (ann.width ?? 60) / 2) / scale,
          y: pdfY - (ann.height ?? 40) / 2 / scale,
          xScale: (ann.width ?? 60) / scale / 2,
          yScale: (ann.height ?? 40) / scale / 2,
          borderColor: rgb(0.48, 0.23, 0.93),
          borderWidth: 2,
        });
        break;
      case 'draw':
        if (ann.points && ann.points.length >= 4) {
          for (let i = 0; i < ann.points.length - 2; i += 2) {
            page.drawLine({
              start: { x: ann.points[i] / scale, y: ph - ann.points[i + 1] / scale },
              end: { x: ann.points[i + 2] / scale, y: ph - ann.points[i + 3] / scale },
              thickness: 2,
              color: rgb(0.2, 0.2, 0.8),
            });
          }
        }
        break;
      case 'image':
      case 'stamp':
        if (ann.imageDataUrl) {
          const imgBytes = await fetch(ann.imageDataUrl).then((r) => r.arrayBuffer());
          const isPng = ann.imageDataUrl.startsWith('data:image/png');
          const img = isPng ? await doc.embedPng(imgBytes) : await doc.embedJpg(imgBytes);
          page.drawImage(img, {
            x: ann.x / scale,
            y: pdfY - (ann.height ?? 80) / scale,
            width: (ann.width ?? 80) / scale,
            height: (ann.height ?? 80) / scale,
            rotate: degrees(0),
          });
        }
        break;
      default:
        break;
    }
  }

  return doc.save();
}

/** Detect PII patterns for smart redact. */
export function detectPiiInText(text: string): Array<{ type: string; match: string; start: number; end: number }> {
  const patterns: Array<{ type: string; re: RegExp }> = [
    { type: 'aadhaar', re: /\b[2-9]\d{3}\s?\d{4}\s?\d{4}\b/g },
    { type: 'pan', re: /\b[A-Z]{5}[0-9]{4}[A-Z]\b/g },
    { type: 'email', re: /\b[\w.+-]+@[\w-]+\.[\w.]+\b/g },
    { type: 'phone', re: /\b(?:\+91[\s-]?)?[6-9]\d{9}\b/g },
  ];
  const hits: Array<{ type: string; match: string; start: number; end: number }> = [];
  for (const { type, re } of patterns) {
    let m: RegExpExecArray | null;
    const r = new RegExp(re.source, re.flags);
    while ((m = r.exec(text)) !== null) {
      hits.push({ type, match: m[0], start: m.index, end: m.index + m[0].length });
    }
  }
  return hits;
}
