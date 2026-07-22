import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/category_colors.dart';

/// Output formats supported by the unified PDF Converter (web parity).
enum TargetFormat {
  docx,
  xlsx,
  pptx,
  txt,
  html,
  rtf,
  jpg,
  png,
  webp,
  csv,
  md,
  pdf,
}

extension TargetFormatX on TargetFormat {
  String get id => name;

  String get label => switch (this) {
        TargetFormat.docx => 'Word',
        TargetFormat.xlsx => 'Excel',
        TargetFormat.pptx => 'PowerPoint',
        TargetFormat.txt => 'Text',
        TargetFormat.html => 'HTML',
        TargetFormat.rtf => 'RTF',
        TargetFormat.jpg => 'JPG',
        TargetFormat.png => 'PNG',
        TargetFormat.webp => 'WebP',
        TargetFormat.csv => 'CSV',
        TargetFormat.md => 'Markdown',
        TargetFormat.pdf => 'PDF',
      };

  String get description => switch (this) {
        TargetFormat.docx => 'Editable Word document',
        TargetFormat.xlsx => 'Spreadsheet with detected tables',
        TargetFormat.pptx => 'One slide per PDF page',
        TargetFormat.txt => 'Plain extracted text',
        TargetFormat.html => 'Semantic HTML markup',
        TargetFormat.rtf => 'Rich text fallback',
        TargetFormat.jpg => 'JPEG page images',
        TargetFormat.png => 'Lossless page images',
        TargetFormat.webp => 'Modern compressed images',
        TargetFormat.csv => 'First detected table',
        TargetFormat.md => 'Headings + paragraphs',
        TargetFormat.pdf => 'Portable PDF document',
      };

  String get extension => name;

  String get mime => switch (this) {
        TargetFormat.docx =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        TargetFormat.xlsx =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        TargetFormat.pptx =>
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        TargetFormat.txt => 'text/plain',
        TargetFormat.html => 'text/html',
        TargetFormat.rtf => 'application/rtf',
        TargetFormat.jpg => 'image/jpeg',
        TargetFormat.png => 'image/png',
        TargetFormat.webp => 'image/webp',
        TargetFormat.csv => 'text/csv',
        TargetFormat.md => 'text/markdown',
        TargetFormat.pdf => 'application/pdf',
      };

  IconData get icon => switch (this) {
        TargetFormat.docx => Icons.description_rounded,
        TargetFormat.xlsx => Icons.table_chart_rounded,
        TargetFormat.pptx => Icons.slideshow_rounded,
        TargetFormat.txt => Icons.notes_rounded,
        TargetFormat.html => Icons.code_rounded,
        TargetFormat.rtf => Icons.text_snippet_rounded,
        TargetFormat.jpg => Icons.image_rounded,
        TargetFormat.png => Icons.image_outlined,
        TargetFormat.webp => Icons.photo_rounded,
        TargetFormat.csv => Icons.grid_on_rounded,
        TargetFormat.md => Icons.article_rounded,
        TargetFormat.pdf => Icons.picture_as_pdf_rounded,
      };

  /// Semantic accent (mirrors web FORMAT_META) — not a parallel palette.
  ///
  /// Office and web formats keep their official brand colour, which is fixed
  /// by the vendor and identical in both themes. Farvixo's own formats (PDF,
  /// images) resolve through [CategoryColors] so a PDF reads the same here as
  /// it does in the tools grid, and adapts to light mode.
  Color accentOf(BuildContext context) => switch (this) {
        TargetFormat.docx => AppColors.formatWord,
        TargetFormat.xlsx => AppColors.formatExcel,
        TargetFormat.pptx => AppColors.formatPowerPoint,
        TargetFormat.txt => AppColors.formatPlainText,
        TargetFormat.html => AppColors.formatHtml,
        TargetFormat.rtf => AppColors.formatRtf,
        TargetFormat.csv => AppColors.formatCsv,
        TargetFormat.md => AppColors.formatMarkdown,
        TargetFormat.pdf => CategoryColors.pdf.accentOf(context),
        TargetFormat.jpg ||
        TargetFormat.png ||
        TargetFormat.webp =>
          CategoryColors.image.accentOf(context),
      };

  bool get isImage =>
      this == TargetFormat.jpg ||
      this == TargetFormat.png ||
      this == TargetFormat.webp;

  bool get isOffice =>
      this == TargetFormat.docx ||
      this == TargetFormat.xlsx ||
      this == TargetFormat.pptx;

  bool get isTextual =>
      this == TargetFormat.txt ||
      this == TargetFormat.html ||
      this == TargetFormat.rtf ||
      this == TargetFormat.md ||
      this == TargetFormat.csv;

  static TargetFormat? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final key = raw.trim().toLowerCase();
    for (final f in TargetFormat.values) {
      if (f.name == key) return f;
    }
    return null;
  }
}

/// Formats offered when the input is already a PDF.
const pdfOutputFormats = <TargetFormat>[
  TargetFormat.docx,
  TargetFormat.xlsx,
  TargetFormat.pptx,
  TargetFormat.txt,
  TargetFormat.html,
  TargetFormat.rtf,
  TargetFormat.jpg,
  TargetFormat.png,
  TargetFormat.webp,
  TargetFormat.csv,
  TargetFormat.md,
];

/// Free-tier formats (core conversions).
const freeTargetFormats = <TargetFormat>{
  TargetFormat.docx,
  TargetFormat.txt,
  TargetFormat.html,
  TargetFormat.rtf,
  TargetFormat.md,
  TargetFormat.jpg,
  TargetFormat.png,
  TargetFormat.pdf,
};
