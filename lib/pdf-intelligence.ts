'use client';

import { loadPdfJs } from './pdf';

// ─── Types ───────────────────────────────────────────────────────────────────

export type DocumentType = 'invoice' | 'resume' | 'contract' | 'academic' | 'report' | 'form' | 'presentation' | 'spreadsheet' | 'unknown';
export type PageType = 'text' | 'table' | 'image' | 'form' | 'mixed';

export interface HeadingNode {
  text: string;
  level: number;
  page: number;
  y: number;
}

export interface TableInfo {
  page: number;
  rows: number;
  cols: number;
  y: number;
}

export interface ImageInfo {
  page: number;
  width: number;
  height: number;
}

export interface PageAnalysis {
  pageNum: number;
  type: PageType;
  textDensity: number;
  tableCount: number;
  imageCount: number;
  lineCount: number;
  avgFontSize: number;
  hasColumns: boolean;
  confidence: number;
}

export interface DocumentStructure {
  pageCount: number;
  totalWords: number;
  totalChars: number;
  headings: HeadingNode[];
  tables: TableInfo[];
  images: ImageInfo[];
  pages: PageAnalysis[];
  documentType: DocumentType;
  documentTypeConfidence: number;
  formatRecommendation: { format: string; reason: string };
  overallConfidence: number;
  textPages: number;
  tablePages: number;
  imagePages: number;
  formPages: number;
}

// ─── Document Intelligence Engine ────────────────────────────────────────────

export async function analyzeDocument(
  file: File,
  onProgress?: (done: number, total: number) => void,
): Promise<DocumentStructure> {
  const pdfjs = await loadPdfJs();
  const data = await file.arrayBuffer();
  const doc = await pdfjs.getDocument({ data }).promise;
  const pageCount = doc.numPages;

  const headings: HeadingNode[] = [];
  const tables: TableInfo[] = [];
  const images: ImageInfo[] = [];
  const pages: PageAnalysis[] = [];
  let totalWords = 0;
  let totalChars = 0;

  for (let i = 1; i <= pageCount; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    const ops = await page.getOperatorList();

    interface TextItem { str: string; transform: number[]; width: number; height: number; fontName: string }
    const items = content.items as TextItem[];

    // Analyze text items
    let pageWords = 0;
    let pageChars = 0;
    let lineCount = 0;
    let tableIndicators = 0;
    const fontSizes: number[] = [];
    const xPositions: number[] = [];
    let lastY = -1;

    for (const item of items) {
      if (!item.str.trim()) continue;
      const fontSize = Math.abs(item.transform[0]) || Math.abs(item.transform[3]) || 12;
      fontSizes.push(fontSize);
      xPositions.push(item.transform[4]);

      const y = Math.round(item.transform[5]);
      if (Math.abs(y - lastY) > 3) {
        lineCount++;
        lastY = y;
      }

      pageWords += item.str.split(/\s+/).filter(Boolean).length;
      pageChars += item.str.length;

      // Detect headings (larger font, short text, start of lines)
      const avgFs = fontSizes.length > 10 ? fontSizes.reduce((a, b) => a + b, 0) / fontSizes.length : 12;
      if (fontSize > avgFs * 1.3 && item.str.length < 80 && item.str.length > 2) {
        const level = fontSize > avgFs * 1.8 ? 1 : fontSize > avgFs * 1.5 ? 2 : 3;
        if (!headings.some((h) => h.text === item.str.trim() && h.page === i)) {
          headings.push({ text: item.str.trim(), level, page: i, y });
        }
      }

      // Table indicators: aligned columns, repeated tab/space patterns
      if (item.str.includes('\t') || /\s{3,}/.test(item.str)) tableIndicators++;
    }

    // Detect columns (multiple distinct X clusters)
    const xClusters = detectClusters(xPositions, 50);
    const hasColumns = xClusters > 1;

    // Detect tables via alignment patterns
    const tableCount = detectTables(items, i, tables);

    // Count images from operator list
    let imageCount = 0;
    for (let op = 0; op < ops.fnArray.length; op++) {
      if (ops.fnArray[op] === 82 || ops.fnArray[op] === 83) { // paintImageXObject / paintJpegXObject
        imageCount++;
        images.push({ page: i, width: 0, height: 0 });
      }
    }

    // Determine page type
    const textDensity = pageChars / Math.max(1, lineCount);
    let pageType: PageType = 'text';
    if (tableCount > 0 && tableIndicators > lineCount * 0.3) pageType = 'table';
    else if (imageCount > 0 && pageWords < 50) pageType = 'image';
    else if (tableCount > 0 && imageCount > 0) pageType = 'mixed';

    // Calculate page confidence
    const avgFontSize = fontSizes.length > 0 ? fontSizes.reduce((a, b) => a + b, 0) / fontSizes.length : 12;
    let confidence = 95;
    if (hasColumns) confidence -= 10;
    if (imageCount > 2) confidence -= 15;
    if (tableCount > 0) confidence -= 5;
    if (pageWords < 10 && imageCount > 0) confidence -= 20; // likely scanned
    confidence = Math.max(20, Math.min(100, confidence));

    pages.push({
      pageNum: i,
      type: pageType,
      textDensity,
      tableCount,
      imageCount,
      lineCount,
      avgFontSize,
      hasColumns,
      confidence,
    });

    totalWords += pageWords;
    totalChars += pageChars;
    onProgress?.(i, pageCount);
  }

  // Detect document type
  const { type: documentType, confidence: documentTypeConfidence } = detectDocumentType(headings, tables, images, pages, totalWords, pageCount);

  // Generate format recommendation
  const formatRecommendation = getFormatRecommendation(documentType, pages, tables, images);

  // Overall confidence
  const overallConfidence = Math.round(pages.reduce((s, p) => s + p.confidence, 0) / Math.max(1, pages.length));

  return {
    pageCount,
    totalWords,
    totalChars,
    headings,
    tables,
    images,
    pages,
    documentType,
    documentTypeConfidence,
    formatRecommendation,
    overallConfidence,
    textPages: pages.filter((p) => p.type === 'text').length,
    tablePages: pages.filter((p) => p.type === 'table').length,
    imagePages: pages.filter((p) => p.type === 'image').length,
    formPages: pages.filter((p) => p.type === 'form').length,
  };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function detectClusters(values: number[], threshold: number): number {
  if (values.length < 5) return 1;
  const sorted = [...new Set(values.map((v) => Math.round(v / threshold) * threshold))];
  return Math.min(sorted.length, 4);
}

function detectTables(
  items: { str: string; transform: number[] }[],
  pageNum: number,
  tables: TableInfo[],
): number {
  // Group by Y position to find rows
  const rows = new Map<number, number[]>();
  for (const item of items) {
    const y = Math.round(item.transform[5] / 5) * 5;
    const x = item.transform[4];
    if (!rows.has(y)) rows.set(y, []);
    rows.get(y)!.push(x);
  }

  // Find sequences of rows with similar column counts (table pattern)
  let tableCount = 0;
  const rowEntries = Array.from(rows.entries()).sort((a, b) => b[0] - a[0]);
  let streak = 0;
  let lastColCount = 0;

  for (const [, cols] of rowEntries) {
    const colCount = new Set(cols.map((x) => Math.round(x / 40) * 40)).size;
    if (colCount >= 3 && Math.abs(colCount - lastColCount) <= 1) {
      streak++;
    } else {
      if (streak >= 3) {
        tableCount++;
        tables.push({ page: pageNum, rows: streak, cols: lastColCount, y: 0 });
      }
      streak = colCount >= 3 ? 1 : 0;
    }
    lastColCount = colCount;
  }
  if (streak >= 3) {
    tableCount++;
    tables.push({ page: pageNum, rows: streak, cols: lastColCount, y: 0 });
  }

  return tableCount;
}

function detectDocumentType(
  headings: HeadingNode[],
  tables: TableInfo[],
  images: ImageInfo[],
  pages: PageAnalysis[],
  totalWords: number,
  pageCount: number,
): { type: DocumentType; confidence: number } {
  const scores: Record<DocumentType, number> = {
    invoice: 0, resume: 0, contract: 0, academic: 0,
    report: 0, form: 0, presentation: 0, spreadsheet: 0, unknown: 0,
  };

  const headingTexts = headings.map((h) => h.text.toLowerCase());
  const tablePages = pages.filter((p) => p.type === 'table').length;
  const imagePages = pages.filter((p) => p.type === 'image').length;
  const avgWordsPerPage = totalWords / Math.max(1, pageCount);

  // Invoice signals
  if (headingTexts.some((h) => /invoice|bill|receipt|payment|total|amount|due/.test(h))) scores.invoice += 40;
  if (tables.length >= 1 && pageCount <= 3) scores.invoice += 20;
  if (totalWords < 500 && tables.length > 0) scores.invoice += 15;

  // Resume signals
  if (headingTexts.some((h) => /experience|education|skills|objective|summary|qualification/.test(h))) scores.resume += 40;
  if (pageCount <= 3 && headings.length >= 4) scores.resume += 20;
  if (totalWords > 200 && totalWords < 1500 && pageCount <= 2) scores.resume += 15;

  // Contract signals
  if (headingTexts.some((h) => /agreement|clause|party|witness|term|condition|whereas/.test(h))) scores.contract += 40;
  if (avgWordsPerPage > 300 && pageCount > 3) scores.contract += 15;
  if (headings.length > 5 && tables.length === 0) scores.contract += 10;

  // Academic signals
  if (headingTexts.some((h) => /abstract|introduction|methodology|conclusion|reference|bibliography/.test(h))) scores.academic += 50;
  if (pageCount > 5 && headings.length > 5) scores.academic += 15;

  // Report signals
  if (headingTexts.some((h) => /executive summary|findings|recommendation|appendix/.test(h))) scores.report += 40;
  if (pageCount > 5 && images.length > 2) scores.report += 15;
  if (tables.length > 2 && headings.length > 3) scores.report += 10;

  // Form signals
  if (pages.filter((p) => p.type === 'form').length > 0) scores.form += 30;
  if (totalWords < 300 && pageCount <= 2 && headings.length < 3) scores.form += 15;

  // Presentation signals
  if (imagePages > pageCount * 0.5) scores.presentation += 30;
  if (avgWordsPerPage < 100 && pageCount > 5) scores.presentation += 20;

  // Spreadsheet signals
  if (tablePages > pageCount * 0.5) scores.spreadsheet += 40;
  if (tables.length > 3) scores.spreadsheet += 20;

  // Find highest score
  let maxType: DocumentType = 'unknown';
  let maxScore = 0;
  for (const [type, score] of Object.entries(scores)) {
    if (score > maxScore) { maxScore = score; maxType = type as DocumentType; }
  }

  const confidence = Math.min(95, maxScore);
  if (maxScore < 20) return { type: 'unknown', confidence: 10 };
  return { type: maxType, confidence };
}

function getFormatRecommendation(
  docType: DocumentType,
  pages: PageAnalysis[],
  tables: TableInfo[],
  images: ImageInfo[],
): { format: string; reason: string } {
  switch (docType) {
    case 'invoice':
    case 'spreadsheet':
      return { format: 'xlsx', reason: 'Tables detected - Excel preserves data structure perfectly' };
    case 'resume':
      return { format: 'docx', reason: 'Resume layout is best preserved in Word format' };
    case 'contract':
      return { format: 'docx', reason: 'Legal text is best in editable Word format' };
    case 'academic':
      return { format: 'docx', reason: 'Academic papers convert cleanly to Word for editing' };
    case 'report':
      if (images.length > 5) return { format: 'pptx', reason: 'Image-heavy report works well as presentation' };
      return { format: 'docx', reason: 'Reports with mixed content are best in Word' };
    case 'presentation':
      return { format: 'pptx', reason: 'Visual content maps directly to slides' };
    case 'form':
      return { format: 'html', reason: 'Forms are most interactive in HTML format' };
    default:
      if (tables.length > pages.length * 0.5) return { format: 'xlsx', reason: 'Many tables detected - Excel recommended' };
      if (pages.every((p) => p.type === 'image')) return { format: 'png', reason: 'Image-only PDF - extract as images' };
      return { format: 'docx', reason: 'Word is the most versatile format for mixed content' };
  }
}

// ─── Confidence Scoring ──────────────────────────────────────────────────────

export function calculateConversionConfidence(
  structure: DocumentStructure,
  targetFormat: string,
): { overall: number; perPage: number[]; issues: string[] } {
  const issues: string[] = [];
  const perPage: number[] = [];

  for (const page of structure.pages) {
    let score = page.confidence;

    // Format-specific adjustments
    if (targetFormat === 'docx' || targetFormat === 'rtf') {
      if (page.hasColumns) { score -= 10; issues.push(`Page ${page.pageNum}: Multi-column layout may shift`); }
      if (page.imageCount > 3) { score -= 10; issues.push(`Page ${page.pageNum}: Images may not be embedded`); }
    }
    if (targetFormat === 'xlsx' || targetFormat === 'csv') {
      if (page.type !== 'table') { score -= 20; issues.push(`Page ${page.pageNum}: Non-table content will be simplified`); }
    }
    if (targetFormat === 'txt' || targetFormat === 'md') {
      if (page.imageCount > 0) { score -= 15; issues.push(`Page ${page.pageNum}: Images will be lost in text format`); }
      if (page.tableCount > 0 && targetFormat === 'txt') { score -= 10; issues.push(`Page ${page.pageNum}: Table structure simplified`); }
    }
    if (targetFormat === 'pptx') {
      if (page.lineCount > 30) { score -= 10; issues.push(`Page ${page.pageNum}: Dense text may overflow slide`); }
    }

    perPage.push(Math.max(15, Math.min(100, score)));
  }

  // Deduplicate issues
  const uniqueIssues = [...new Set(issues)].slice(0, 8);
  const overall = Math.round(perPage.reduce((s, p) => s + p, 0) / Math.max(1, perPage.length));

  return { overall, perPage, issues: uniqueIssues };
}

// ─── Smart Page Router ───────────────────────────────────────────────────────

export interface PageStrategy {
  pageNum: number;
  type: PageType;
  strategy: 'text-extract' | 'table-detect' | 'image-render' | 'ocr-fallback' | 'mixed-hybrid';
  confidence: number;
}

export function buildPageStrategies(structure: DocumentStructure): PageStrategy[] {
  return structure.pages.map((page) => {
    let strategy: PageStrategy['strategy'] = 'text-extract';

    if (page.type === 'table') strategy = 'table-detect';
    else if (page.type === 'image') strategy = page.confidence < 50 ? 'ocr-fallback' : 'image-render';
    else if (page.type === 'mixed') strategy = 'mixed-hybrid';
    else if (page.textDensity < 5 && page.imageCount > 0) strategy = 'ocr-fallback';

    return {
      pageNum: page.pageNum,
      type: page.type,
      strategy,
      confidence: page.confidence,
    };
  });
}
