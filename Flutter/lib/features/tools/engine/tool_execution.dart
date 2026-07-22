import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import 'engines/audio_wav_engines.dart';
import 'engines/calc_engines.dart';
import 'engines/dev_engines.dart';
import 'engines/media_extra_engines.dart';
import 'engines/pending_native_engines.dart';
import 'engines/video_ffmpeg_engines.dart';
import 'engines/image_engines.dart';
import 'engines/image_fx_engines.dart';
import 'engines/local_util_engines.dart';
import 'engines/pdf_engines.dart';
import 'engines/pdf_extra_engines.dart';
import 'engines/remote_engines.dart';
import 'engines/scan_engines.dart';
import 'engines/text_engines.dart';
import 'engines/text_extra_engines.dart';
import '../converter/engines/pdf_converter_engine.dart';
import '../converter/engines/pdf_ocr_engine.dart';
import '../converter/models/target_format.dart';
import 'tool_engine.dart';

/// Maps tool slugs → engines. Registering a `RemoteToolEngine` here instead of a
/// `LocalToolEngine` for a given slug is the ONLY change needed to move that
/// tool server-side — the UI and controller are engine-agnostic.
class ToolEngineRegistry {
  ToolEngineRegistry(this._engines);
  final Map<String, ToolEngine> _engines;

  ToolEngine? forSlug(String slug) => _engines[slug];
  bool supports(String slug) => _engines.containsKey(slug);
}

final toolEngineRegistryProvider = Provider<ToolEngineRegistry>((ref) {
  // Remote engines reuse the existing AiService (Supabase-authed, streaming).
  final ai = ref.watch(aiServiceProvider);
  final qr = QrEngine();
  final base64 = Base64Engine();
  final json = JsonEngine();
  final textStats = TextStatsEngine();

  RemotePromptEngine prompt(String action, String hint, String instruction) =>
      RemotePromptEngine(ai,
          actionLabel: action, textHint: hint, instruction: instruction);

  return ToolEngineRegistry({
    // --- PDF Converter (unified + aliases) ---
    'pdf-converter': PdfConverterEngine(),
    'pdf-to-word': PdfConverterEngine(lockedTarget: TargetFormat.docx),
    'word-to-pdf': PdfConverterEngine(
      lockedTarget: TargetFormat.pdf,
      expectExtension: 'docx',
    ),
    'pdf-to-excel': PdfConverterEngine(lockedTarget: TargetFormat.xlsx),
    'excel-to-pdf': PdfConverterEngine(
      lockedTarget: TargetFormat.pdf,
      expectExtension: 'xlsx',
    ),
    'pdf-to-image': PdfConverterEngine(lockedTarget: TargetFormat.png),
    'pdf-ocr': PdfOcrEngine(),

    // --- Image extras (pure Dart, on-device) ---
    'image-watermark': ImageWatermarkEngine(),
    'meme-generator': MemeGeneratorEngine(),
    'image-upscaler': ImageUpscalerEngine(),

    // --- Video / audio codecs (ffmpeg, on-device) ---
    'video-converter': VideoConverterEngine(),
    'video-compressor': VideoCompressorEngine(),
    'video-trimmer': VideoTrimmerEngine(),
    'video-to-gif': VideoToGifEngine(),
    'gif-to-video': GifToVideoEngine(),
    'video-merger': VideoMergerEngine(),
    'video-mute': VideoMuteEngine(),
    'video-speed': VideoSpeedEngine(),
    'video-rotate': VideoRotateEngine(),
    'audio-extractor': AudioExtractorEngine(),
    'video-thumbnail': VideoThumbnailEngine(),
    'video-watermark': VideoWatermarkEngine(),
    'audio-converter': AudioConverterEngine(),
    'noise-reducer': NoiseReducerEngine(),

    // --- Awaiting native modules (honest, never fake) ---
    'screen-recorder': PendingNativeEngine(
      actionLabel: 'Start Recording',
      reason:
          'Screen recording needs the system capture module, which ships in the '
          'next native update. Until then use your device\'s built-in recorder.',
    ),
    'audio-recorder': PendingNativeEngine(
      actionLabel: 'Record',
      reason:
          'Microphone recording needs the native recorder module, which ships '
          'in the next update. Your device\'s voice recorder works meanwhile.',
    ),
    'text-to-speech': PendingNativeEngine(
      actionLabel: 'Speak',
      needsText: true,
      textHint: 'Text to speak aloud',
      reason:
          'Text-to-speech needs the platform voice module, which ships in the '
          'next native update.',
    ),
    'speech-to-text': PendingNativeEngine(
      actionLabel: 'Transcribe',
      needsFile: true,
      allowedExtensions: ['wav', 'mp3', 'm4a'],
      reason:
          'Transcription needs the on-device speech model, which ships in the '
          'next native update.',
    ),
    'image-ocr': PendingNativeEngine(
      actionLabel: 'Extract Text',
      needsFile: true,
      pickFromGallery: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      reason:
          'Image OCR needs the on-device text-recognition model (ML Kit), '
          'which ships in the next native update. PDF OCR already works for '
          'digital PDFs via the PDF OCR tool.',
    ),
    'background-remover': PendingNativeEngine(
      actionLabel: 'Remove Background',
      needsFile: true,
      pickFromGallery: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      reason:
          'Background removal needs the on-device segmentation model (ML Kit), '
          'which ships in the next native update.',
    ),

    // --- Subtitles (pure text, on-device) ---
    'subtitle-tools': SubtitleToolsEngine(),

    // --- Audio (on-device WAV suite; compressed formats need a codec dep) ---
    'audio-reverse': AudioReverseEngine(),
    'volume-booster': VolumeBoostEngine(),
    'audio-speed': AudioSpeedEngine(),
    'audio-cutter': AudioCutterEngine(),
    'ringtone-maker': AudioCutterEngine(maxSeconds: 30, suffix: 'ringtone'),
    'audio-merger': AudioMergerEngine(),
    'audio-normalizer': AudioNormalizerEngine(),
    'audio-metadata': AudioMetadataEngine(),

    // --- PDF (syncfusion, on-device) ---
    'merge-pdf': MergePdfEngine(),
    'split-pdf': SplitPdfEngine(),
    'compress-pdf': CompressPdfEngine(),
    'image-to-pdf': ImageToPdfEngine(),
    'protect-pdf': ProtectPdfEngine(),
    'unlock-pdf': UnlockPdfEngine(),
    'rotate-pdf': PdfRotateEngine(),
    'watermark-pdf': PdfWatermarkEngine(),
    'reverse-pdf': ReversePdfEngine(),
    'pdf-to-text': PdfToTextEngine(),
    'pdf-info': PdfInfoEngine(),
    'pdf-page-numbers': PdfPageNumberEngine(),

    // --- Image (image pkg, on-device) ---
    'image-compressor': ImageCompressEngine(),
    'image-resizer': ImageResizeEngine(),
    'image-converter': ImageConvertEngine(),
    'rotate-flip-image': ImageRotateFlipEngine(),
    'image-crop': ImageCropRatioEngine(),
    'image-grayscale': ImageFilterEngine('grayscale'),
    'image-sepia': ImageFilterEngine('sepia'),
    'image-invert': ImageFilterEngine('invert'),
    'image-blur': ImageBlurEngine(),
    'image-pixelate': ImagePixelateEngine(),
    'image-enhance': ImageEnhanceEngine(),
    'image-info': ImageInfoEngine(),
    'image-to-base64': ImageBase64Engine(),
    'color-palette-extractor': DominantColorsEngine(),

    // --- Utility (offline) ---
    'hash-generator': HashEngine(),
    'uuid-generator': UuidEngine(),
    'qr-generator': qr, // local-catalog slug
    'qr-code-generator': qr, // backend-catalog slug
    'qr-scanner': QrScanEngine(),
    'password-generator': PasswordEngine(),
    'password-strength': PasswordStrengthEngine(),
    'unit-converter': UnitConvertEngine(),
    'age-calculator': AgeCalcEngine(),
    'bmi-calculator': BmiEngine(),
    'percentage-calculator': PercentageEngine(),
    'emi-calculator': EmiEngine(),
    'interest-calculator': InterestEngine(),
    'discount-calculator': DiscountEngine(),
    'tip-calculator': TipEngine(),
    'gst-calculator': GstEngine(),
    'date-difference': DateDiffEngine(),
    'random-number': RandomNumberEngine(),
    'dice-roller': DiceEngine(),
    'card-validator': LuhnEngine(),
    'fuel-cost-calculator': FuelCostEngine(),

    // --- Text (pure-Dart, offline) ---
    'word-counter': textStats,
    'character-counter': textStats,
    'case-converter': CaseConverterEngine(),
    'lorem-ipsum-generator': LoremEngine(),
    'text-compare': TextCompareEngine(),
    'reverse-text': ReverseTextEngine(),
    'sort-lines': SortLinesEngine(),
    'remove-duplicate-lines': DedupeLinesEngine(),
    'text-cleaner': CleanTextEngine(),
    'slug-generator': SlugifyEngine(),
    'line-break-remover': LineBreakRemoverEngine(),
    'binary-translator': BinaryTextEngine(),
    'morse-code': MorseEngine(),
    'caesar-cipher': CipherEngine(),
    'text-extractor': ExtractorEngine(),
    'word-frequency': WordFrequencyEngine(),
    'number-to-words': NumberToWordsEngine(),
    'find-replace': FindReplaceEngine(),
    'text-repeater': TextRepeaterEngine(),

    // --- Developer (pure-Dart, offline) ---
    'base64': base64, // local-catalog slug
    'base64-encoder-decoder': base64, // backend-catalog slug
    'json-formatter': json,
    'json-validator': json,
    'url-encoder': UrlCodecEngine(),
    'html-entities': HtmlEntityEngine(),
    'jwt-decoder': JwtDecodeEngine(),
    'color-converter': ColorConvertEngine(),
    'timestamp-converter': TimestampEngine(),
    'number-base-converter': NumberBaseEngine(),
    'roman-numerals': RomanEngine(),
    'csv-to-json': CsvToJsonEngine(),
    'json-to-csv': JsonToCsvEngine(),
    'markdown-to-html': MarkdownHtmlEngine(),
    'css-minifier': CssMinifyEngine(),
    'html-to-text': HtmlStripEngine(),
    'token-generator': TokenGeneratorEngine(),
    'json-escape': JsonEscapeEngine(),
    'ip-subnet-calculator': IpSubnetEngine(),
    'file-to-base64': FileToBase64Engine(),
    'http-status-codes': HttpStatusEngine(),

    // --- AI (existing Farvixo AI backend) ---
    'ai-chat': RemoteChatEngine(ai),
    'ai-image-generator': RemoteImageGenEngine(ai),
    'ai-translator': RemoteTranslateEngine(ai),
    'ai-summarizer': prompt('Summarize', 'Paste text to summarize…',
        'Summarize the following text clearly and concisely:'),
    'ai-writer': prompt('Write', 'What should I write about?',
        'Write high-quality, well-structured content for this brief:'),
    'ai-email-writer': prompt('Draft Email', 'Describe the email you need…',
        'Draft a clear, professional email based on this description:'),
    'grammar-checker': prompt('Fix Grammar', 'Paste text to correct…',
        'Correct the grammar, spelling and punctuation of the following text. '
            'Return the corrected text first, then briefly list the fixes:'),
    'paraphraser': prompt('Paraphrase', 'Paste text to rephrase…',
        'Rephrase the following text so it keeps the same meaning but reads '
            'differently. Offer one strong rewrite:'),
    'ai-caption-generator': prompt('Generate Captions',
        'Describe your photo or post…',
        'Write 5 catchy social-media captions (with fitting emojis) for:'),
    'hashtag-generator': prompt('Generate Hashtags', 'Describe your post…',
        'Suggest 15 effective, relevant hashtags (no banned or spammy tags) '
            'for this post:'),
    'blog-outliner': prompt('Outline', 'Blog topic…',
        'Create a detailed blog-post outline with headings, subheadings and '
            'key talking points for:'),
    'product-description': prompt('Describe Product',
        'Product name + key features…',
        'Write a persuasive e-commerce product description (title, bullets, '
            'paragraph) for:'),
    'business-name-generator': prompt('Suggest Names',
        'What does the business do?…',
        'Suggest 10 brandable business names (with a one-line rationale each) '
            'for:'),
    'ai-story-writer': prompt('Write Story', 'A premise, characters, a vibe…',
        'Write an engaging short story based on this premise:'),
    'resume-bullet-writer': prompt('Write Bullets',
        'Role + what you did…',
        'Turn this experience into 4 strong, quantified resume bullet points:'),
    'interview-questions': prompt('Prepare', 'Role you are interviewing for…',
        'List the 10 most likely interview questions for this role, each with '
            'a strong sample answer outline:'),
    'quiz-generator': prompt('Generate Quiz', 'Topic + difficulty…',
        'Create a 10-question multiple-choice quiz (answers at the end) on:'),
    'prompt-improver': prompt('Improve Prompt', 'Paste your AI prompt…',
        'Rewrite this AI prompt to be clearer, more specific and more '
            'effective. Explain the key changes briefly:'),
    'notes-cleaner': prompt('Clean Notes', 'Paste rough notes…',
        'Turn these rough notes into clean, well-organized bullet notes with '
            'headings:'),
    'ai-code-explainer': prompt('Explain Code', 'Paste code…',
        'Explain what this code does, step by step, in plain language. Note '
            'any bugs or improvements:'),
  });
});

/// UI-facing execution state. Mirrors the detail screen's existing visual
/// states (empty/selected/processing/done) without redesigning them.
sealed class ToolExecState {
  const ToolExecState();
}

class ToolIdle extends ToolExecState {
  const ToolIdle();
}

class ToolRunning extends ToolExecState {
  const ToolRunning({this.fraction, this.stage});
  final double? fraction;
  final String? stage;
}

class ToolSuccess extends ToolExecState {
  const ToolSuccess(this.result);
  final ToolResult result;
}

class ToolFailed extends ToolExecState {
  const ToolFailed(this.message);
  final String message;
}

/// Per-tool execution controller. autoDispose+family: one instance per open
/// tool page, released when the page is popped. Cancellation is cooperative and
/// run-scoped (a stale run can never overwrite a newer state).
final toolExecutionProvider = NotifierProvider.autoDispose
    .family<ToolExecutionController, ToolExecState, String>(
  ToolExecutionController.new,
);

class ToolExecutionController
    extends AutoDisposeFamilyNotifier<ToolExecState, String> {
  bool _canceled = false;
  int _runId = 0;

  @override
  ToolExecState build(String arg) => const ToolIdle();

  ToolEngine? get engine =>
      ref.read(toolEngineRegistryProvider).forSlug(arg);

  bool get isSupported => engine != null;

  void cancel() {
    _canceled = true;
    state = const ToolIdle();
  }

  void reset() {
    _canceled = false;
    state = const ToolIdle();
  }

  /// Publish an externally produced result (e.g. the live camera scanner)
  /// so it renders through the standard success card (copy / share / retry).
  void complete(ToolResult result) {
    _canceled = false;
    _runId++; // invalidate any in-flight run
    state = ToolSuccess(result);
  }

  Future<void> run(ToolInput input) async {
    final eng = engine;
    if (eng == null) {
      state = const ToolFailed('This tool is coming soon on mobile.');
      return;
    }
    _canceled = false;
    final myRun = ++_runId;
    state = const ToolRunning(stage: 'Starting');
    try {
      final result = await eng.run(
        input,
        onProgress: (fraction, stage) {
          if (myRun == _runId && !_canceled) {
            state = ToolRunning(fraction: fraction, stage: stage);
          }
        },
        isCanceled: () => _canceled || myRun != _runId,
      );
      if (myRun != _runId || _canceled) return; // superseded/canceled
      state = ToolSuccess(result);
    } on ToolCanceled {
      if (myRun == _runId) state = const ToolIdle();
    } on ToolFailure catch (e) {
      if (myRun == _runId) state = ToolFailed(e.message);
    } catch (_) {
      if (myRun == _runId) {
        state = const ToolFailed('Processing failed. Please try again.');
      }
    }
  }
}
