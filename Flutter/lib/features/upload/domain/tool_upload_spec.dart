import 'package:flutter/foundation.dart';

import 'upload_source.dart';

/// What a single tool needs from Lightning Upload.
///
/// This is the **data** behind "which tools use upload". Before this file the
/// answer was inferred from tool names; now every upload-consuming tool
/// declares its own contract — accepted extensions, single vs multi file, and
/// whether the mobile picker should open the gallery instead of the file
/// browser.
@immutable
class ToolUploadSpec {
  const ToolUploadSpec({
    required this.accept,
    this.multiFile = false,
    this.maxFiles = 1,
    this.preferGallery = false,
    this.hint,
  });

  /// Lowercase extensions without dots. Empty means "any file".
  final List<String> accept;

  /// Whether the tool operates on a batch.
  final bool multiFile;

  /// Upper bound on batch size. Ignored when [multiFile] is false.
  final int maxFiles;

  /// On mobile, open the photo gallery rather than the document browser.
  final bool preferGallery;

  /// Short line shown under the drop zone, e.g. "Two or more PDFs".
  final String? hint;

  /// Sources that make sense for this spec on [platform].
  ///
  /// Image tools surface Camera and Gallery first; document tools hide them,
  /// because photographing a spreadsheet is never what the user meant.
  List<UploadSource> sourcesFor(UploadPlatform platform) {
    final all = UploadSource.forPlatform(platform);
    if (preferGallery) return all;
    return all
        .where((s) =>
            s != UploadSource.gallery &&
            s != UploadSource.camera &&
            s != UploadSource.scanner)
        .toList();
  }

  /// Human-readable accept list: `PDF`, `JPG, PNG, WEBP`, `Any file`.
  String get acceptLabel {
    if (accept.isEmpty) return 'Any file';
    return accept.map((e) => e.toUpperCase()).join(', ');
  }

  bool allows(String extension) =>
      accept.isEmpty || accept.contains(extension.toLowerCase());
}

// ---------------------------------------------------------------------------
// Shared accept sets
// ---------------------------------------------------------------------------

const _pdf = ['pdf'];
const _images = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic'];
const _video = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp'];
const _audio = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'wma'];
const _word = ['doc', 'docx', 'rtf', 'odt'];
const _excel = ['xls', 'xlsx', 'csv', 'ods'];
const _docs = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'md'];
const _subs = ['srt', 'vtt', 'ass', 'sub'];

const _image = ToolUploadSpec(accept: _images, preferGallery: true);
const _imageBatch = ToolUploadSpec(
  accept: _images,
  multiFile: true,
  maxFiles: 50,
  preferGallery: true,
);
const _pdfOne = ToolUploadSpec(accept: _pdf);
const _videoOne = ToolUploadSpec(accept: _video);
const _audioOne = ToolUploadSpec(accept: _audio);

/// Every tool that consumes an uploaded file, and what it accepts.
///
/// 71 of the 143 catalog tools. The other 72 take typed text, produce output
/// from parameters, or capture their own input (recorders) — they never open
/// the upload surface.
class ToolUploadSpecs {
  ToolUploadSpecs._();

  static const Map<String, ToolUploadSpec> byToolId = {
    // ---------------- PDF (19) ----------------
    'pdf-converter': _pdfOne,
    'pdf-to-word': _pdfOne,
    'pdf-to-excel': _pdfOne,
    'pdf-to-image': _pdfOne,
    'pdf-to-text': _pdfOne,
    'pdf-ocr': _pdfOne,
    'pdf-info': _pdfOne,
    'pdf-page-numbers': _pdfOne,
    'protect-pdf': _pdfOne,
    'unlock-pdf': _pdfOne,
    'rotate-pdf': _pdfOne,
    'reverse-pdf': _pdfOne,
    'split-pdf': _pdfOne,
    'compress-pdf': _pdfOne,
    'watermark-pdf': _pdfOne,
    'merge-pdf': ToolUploadSpec(
      accept: _pdf,
      multiFile: true,
      maxFiles: 30,
      hint: 'Two or more PDFs, in merge order',
    ),
    'image-to-pdf': ToolUploadSpec(
      accept: _images,
      multiFile: true,
      maxFiles: 100,
      preferGallery: true,
      hint: 'Photos become pages, in the order you pick them',
    ),
    'word-to-pdf': ToolUploadSpec(accept: _word),
    'excel-to-pdf': ToolUploadSpec(accept: _excel),

    // ---------------- Image (19) ----------------
    'background-remover': _image,
    'image-compressor': _imageBatch,
    'image-converter': _imageBatch,
    'image-resizer': _imageBatch,
    'image-crop': _image,
    'image-enhance': _image,
    'image-upscaler': _image,
    'image-blur': _image,
    'image-pixelate': _image,
    'image-grayscale': _image,
    'image-invert': _image,
    'image-sepia': _image,
    'image-watermark': _image,
    'image-ocr': _image,
    'image-info': _image,
    'image-to-base64': _image,
    'color-palette-extractor': _image,
    'rotate-flip-image': _image,
    'meme-generator': _image,

    // ---------------- Video (13) ----------------
    'video-compressor': _videoOne,
    'video-converter': _videoOne,
    'video-trimmer': _videoOne,
    'video-rotate': _videoOne,
    'video-speed': _videoOne,
    'video-mute': _videoOne,
    'video-watermark': _videoOne,
    'video-thumbnail': _videoOne,
    'video-to-gif': _videoOne,
    'gif-to-video': ToolUploadSpec(accept: ['gif']),
    'audio-extractor': _videoOne,
    'video-merger': ToolUploadSpec(
      accept: _video,
      multiFile: true,
      maxFiles: 20,
      hint: 'Two or more clips, in join order',
    ),
    'subtitle-tools': ToolUploadSpec(accept: _subs),

    // ---------------- Audio (11) ----------------
    'audio-converter': _audioOne,
    'audio-cutter': _audioOne,
    'audio-speed': _audioOne,
    'audio-reverse': _audioOne,
    'audio-normalizer': _audioOne,
    'audio-metadata': _audioOne,
    'noise-reducer': _audioOne,
    'volume-booster': _audioOne,
    'ringtone-maker': _audioOne,
    'speech-to-text': _audioOne,
    'audio-merger': ToolUploadSpec(
      accept: _audio,
      multiFile: true,
      maxFiles: 20,
      hint: 'Two or more tracks, in join order',
    ),

    // ---------------- AI (5) ----------------
    'ai-caption-generator': _image,
    'ai-summarizer': ToolUploadSpec(
      accept: _docs,
      hint: 'Or paste text instead',
    ),
    'ai-translator': ToolUploadSpec(
      accept: _docs,
      hint: 'Or paste text instead',
    ),
    'quiz-generator': ToolUploadSpec(
      accept: _docs,
      hint: 'Build questions from a document',
    ),
    'resume-bullet-writer': ToolUploadSpec(
      accept: _docs,
      hint: 'Upload a CV to rewrite its bullets',
    ),

    // ---------------- Developer (2) ----------------
    'file-to-base64': ToolUploadSpec(accept: []),
    'csv-to-json': ToolUploadSpec(accept: ['csv', 'tsv', 'txt']),

    // ---------------- Text (1) ----------------
    'text-extractor': ToolUploadSpec(accept: _docs),

    // ---------------- Utility (1) ----------------
    'qr-scanner': _image,
  };

  /// The spec for [toolId], or null when the tool takes no file.
  static ToolUploadSpec? of(String? toolId) =>
      toolId == null ? null : byToolId[toolId];

  /// Whether this tool opens the upload surface at all.
  static bool needsUpload(String? toolId) => of(toolId) != null;

  /// Total number of upload-consuming tools.
  static int get count => byToolId.length;

  /// Tools that accept a batch rather than a single file.
  static Iterable<String> get multiFileTools => byToolId.entries
      .where((e) => e.value.multiFile)
      .map((e) => e.key);
}
