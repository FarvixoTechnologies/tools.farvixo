import 'dart:typed_data';

/// A file handed to a tool engine (from file_picker / image_picker / camera).
class ToolFile {
  const ToolFile({
    required this.name,
    required this.bytes,
    this.path,
    this.mime,
  });

  final String name;
  final Uint8List bytes;
  final String? path;
  final String? mime;

  int get sizeBytes => bytes.length;
}

/// Everything a tool engine needs to run: picked files, an optional text field,
/// and free-form options (quality, width, target format, …).
class ToolInput {
  const ToolInput({
    this.files = const [],
    this.text,
    this.options = const {},
  });

  final List<ToolFile> files;
  final String? text;
  final Map<String, Object?> options;

  T? option<T>(String key) => options[key] as T?;
}

enum ToolResultKind { text, file, imageUrl }

/// The output of a tool run. UI only depends on [kind] + the relevant payload,
/// so a LocalToolEngine and a future RemoteToolEngine can return the same shape.
class ToolResult {
  const ToolResult._({
    required this.kind,
    this.text,
    this.bytes,
    this.fileName,
    this.mime,
    this.imageUrl,
    this.summary,
    this.copyText,
  });

  final ToolResultKind kind;
  final String? text;
  final Uint8List? bytes;
  final String? fileName;
  final String? mime;
  final String? imageUrl;

  /// Short human note, e.g. "2.3 MB → 1.1 MB (52% smaller)".
  final String? summary;

  /// Optional copyable string offered alongside a non-text result (e.g. the
  /// source text encoded in a QR image). Text results are copied via [text].
  final String? copyText;

  factory ToolResult.text(String text, {String? summary}) => ToolResult._(
        kind: ToolResultKind.text,
        text: text,
        summary: summary,
      );

  factory ToolResult.file(
    Uint8List bytes, {
    required String fileName,
    String? mime,
    String? summary,
    String? copyText,
  }) =>
      ToolResult._(
        kind: ToolResultKind.file,
        bytes: bytes,
        fileName: fileName,
        mime: mime,
        summary: summary,
        copyText: copyText,
      );

  factory ToolResult.image(String imageUrl, {String? summary}) => ToolResult._(
        kind: ToolResultKind.imageUrl,
        imageUrl: imageUrl,
        summary: summary,
      );
}

/// A minimal single-choice selector a tool can declare (rendered as a small
/// dropdown in the workspace). The chosen value is passed to the engine via
/// [ToolInput.options] under [optionKey].
class ToolChoiceSpec {
  const ToolChoiceSpec({
    required this.optionKey,
    required this.label,
    required this.options,
    required this.defaultValue,
  });

  final String optionKey;
  final String label;
  final List<String> options;
  final String defaultValue;
}

/// Raised by an engine when the user cancels mid-run (cooperative).
class ToolCanceled implements Exception {
  const ToolCanceled();
  @override
  String toString() => 'Canceled';
}

/// Raised by an engine for a user-facing failure (bad input, processing error).
class ToolFailure implements Exception {
  const ToolFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Describes the input affordances a tool needs. Drives the (unchanged) detail
/// workspace UI without the UI knowing anything about the engine internals.
class ToolSpec {
  const ToolSpec({
    required this.actionLabel,
    this.needsFile = false,
    this.multiFile = false,
    this.needsText = false,
    this.allowedExtensions,
    this.pickFromGallery = false,
    this.textHint = 'Enter text',
    this.choice,
    this.regenerable = false,
  });

  /// CTA verb, e.g. "Compress", "Merge", "Generate".
  final String actionLabel;
  final bool needsFile;
  final bool multiFile;
  final bool needsText;

  /// Lowercase extensions without dots, e.g. ['pdf'] or ['jpg','png','webp'].
  final List<String>? allowedExtensions;

  /// When true the picker offers gallery/camera (images) instead of file_picker.
  final bool pickFromGallery;
  final String textHint;

  /// Optional minimal single-choice selector (algorithm, target language, …).
  final ToolChoiceSpec? choice;

  /// True for generators whose result should offer "Regenerate" (password,
  /// lorem, …). No-input tools are implicitly regenerable.
  final bool regenerable;

  /// A tool that produces output with no user input (e.g. UUID generator).
  bool get takesNoInput => !needsFile && !needsText && choice == null;

  /// Whether the result card should show "Regenerate" instead of "Process Another".
  bool get canRegenerate => regenerable || takesNoInput;
}

/// Progress reporter: [fraction] in 0..1 (null = indeterminate), [stage] label.
typedef ToolProgress = void Function(double? fraction, String? stage);

/// The contract every tool implementation satisfies. The UI + execution
/// controller depend ONLY on this interface, so a `RemoteToolEngine` (calling a
/// future backend) can replace a [LocalToolEngine] with no UI changes.
abstract class ToolEngine {
  ToolSpec get spec;

  /// Execute the tool. Implementations MUST:
  ///  - report progress through [onProgress],
  ///  - poll [isCanceled] between steps and throw [ToolCanceled] when true,
  ///  - throw [ToolFailure] with a user-facing message on error.
  Future<ToolResult> run(
    ToolInput input, {
    required ToolProgress onProgress,
    required bool Function() isCanceled,
  });
}

/// Marker base for engines that process entirely on-device. Semantically
/// identical to [ToolEngine]; exists so the registry (and future code) can tell
/// local from remote implementations and swap them per tool.
abstract class LocalToolEngine extends ToolEngine {}
