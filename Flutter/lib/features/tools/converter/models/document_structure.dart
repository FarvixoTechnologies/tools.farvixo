import 'target_format.dart';

enum DocumentType {
  invoice,
  resume,
  contract,
  academic,
  report,
  form,
  presentation,
  spreadsheet,
  scanned,
  unknown,
}

enum PageKind { text, table, image, form, mixed }

enum ScriptHint { latin, bengali, devanagari, cjk, mixed, unknown }

class PageStrategy {
  const PageStrategy({
    required this.pageIndex,
    required this.kind,
    required this.textDensity,
    required this.charCount,
    required this.tableScore,
    required this.imageCount,
    required this.confidence,
  });

  final int pageIndex;
  final PageKind kind;
  final double textDensity;
  final int charCount;
  final double tableScore;
  final int imageCount;
  final double confidence;
}

class FormatRecommendation {
  const FormatRecommendation({
    required this.format,
    required this.reason,
  });

  final TargetFormat format;
  final String reason;
}

class ConfidenceBreakdown {
  const ConfidenceBreakdown({
    required this.overall,
    required this.textExtractability,
    required this.layoutComplexity,
    required this.tableQuality,
    this.issues = const [],
  });

  final int overall;
  final int textExtractability;
  final int layoutComplexity;
  final int tableQuality;
  final List<String> issues;
}

class DocumentStructure {
  const DocumentStructure({
    required this.pageCount,
    required this.totalWords,
    required this.totalChars,
    required this.pages,
    required this.documentType,
    required this.documentTypeConfidence,
    required this.recommendation,
    required this.overallConfidence,
    required this.isScanned,
    required this.scriptHint,
    required this.tableCount,
    required this.imageCount,
    required this.sampleText,
  });

  final int pageCount;
  final int totalWords;
  final int totalChars;
  final List<PageStrategy> pages;
  final DocumentType documentType;
  final int documentTypeConfidence;
  final FormatRecommendation recommendation;
  final int overallConfidence;
  final bool isScanned;
  final ScriptHint scriptHint;
  final int tableCount;
  final int imageCount;
  final String sampleText;

  int get textPages =>
      pages.where((p) => p.kind == PageKind.text || p.kind == PageKind.mixed).length;

  int get tablePages => pages.where((p) => p.kind == PageKind.table).length;

  int get imagePages => pages.where((p) => p.kind == PageKind.image).length;
}
