import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_typography.dart';
import '../../../../theme/design_tokens.dart';
import '../../domain/upload_source.dart';
import '../../domain/upload_status.dart';
import '../upload_layout.dart';
import 'lightning_hero.dart';

/// A file the user chose, with its bytes already read.
typedef PickedFile = ({String name, Uint8List bytes});

/// The Lightning stage as a **local file picker** — no queue, no transport.
///
/// This is the piece on-device tools need. PDF Converter, image tools and the
/// rest process files locally and never send them anywhere; wiring them to the
/// upload *queue* would start a fake transfer and break the "files stay on your
/// device" promise those screens make.
///
/// So the art is decoupled from the pipeline:
///
/// * [LightningPicker] — pick a local file, hand back bytes. On-device tools.
/// * `ToolUploadPanel` — pick, queue and transfer. Tools that upload.
///
/// Both render the identical hero, so the app looks consistent while behaving
/// honestly in each case.
class LightningPicker extends StatefulWidget {
  const LightningPicker({
    super.key,
    required this.onPicked,
    required this.accept,
    this.caption,
    this.hint,
    this.height,
    this.enabled = true,
    this.busy = false,
    this.pickedName,
  });

  /// Fires with the chosen file once its bytes are read.
  final ValueChanged<PickedFile> onPicked;

  /// Lowercase extensions without dots. Empty means any file.
  final List<String> accept;

  /// Overrides the line under the status label.
  final String? caption;

  /// Extra hint shown under the stage.
  final String? hint;

  /// Fixed stage height. Defaults to this device's embedded metrics.
  final double? height;

  final bool enabled;

  /// Renders the working phase while the caller processes the file.
  final bool busy;

  /// Name of the already-staged file, if any.
  final String? pickedName;

  @override
  State<LightningPicker> createState() => _LightningPickerState();
}

class _LightningPickerState extends State<LightningPicker> {
  bool _hovering = false;
  bool _reading = false;

  bool get _canDrop =>
      widget.enabled && UploadPlatform.current.supportsDrop;

  UploadStatus get _status {
    if (widget.busy || _reading) return UploadStatus.preparing;
    if (_hovering) return UploadStatus.hover;
    if (widget.pickedName != null) return UploadStatus.completed;
    return UploadStatus.idle;
  }

  bool _accepted(String name) {
    if (widget.accept.isEmpty) return true;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return false;
    return widget.accept.contains(name.substring(dot + 1).toLowerCase());
  }

  void _reject(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: Motion.snackbar,
      ),
    );
  }

  Future<void> _browse() async {
    if (!widget.enabled) return;
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: widget.accept.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: widget.accept.isEmpty ? null : widget.accept,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    if (!_accepted(f.name)) {
      _reject('Unsupported file type.');
      return;
    }
    final bytes = f.bytes;
    if (bytes == null) {
      _reject('Could not read that file.');
      return;
    }
    widget.onPicked((name: f.name, bytes: bytes));
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _hovering = false);
    if (!widget.enabled || details.files.isEmpty) return;

    final item = details.files.first;
    if (item is DropItemDirectory) {
      _reject('Drop a single file, not a folder.');
      return;
    }
    if (!_accepted(item.name)) {
      final ext = item.name.split('.').last;
      _reject('Unsupported file type: .$ext');
      return;
    }

    setState(() => _reading = true);
    try {
      final bytes = await item.readAsBytes();
      if (!mounted) return;
      widget.onPicked((name: item.name, bytes: bytes));
    } on Object catch (e) {
      _reject('Could not read dropped file: $e');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = UploadMetrics.of(context).embedded;
    final height = widget.height ?? metrics.heroMaxHeight;

    final stage = SizedBox(
      height: height,
      child: LightningHero(
        status: _status,
        metrics: metrics,
        isDropTarget: _hovering,
        caption: widget.caption ?? _defaultCaption(),
        onTap: widget.enabled ? _browse : null,
      ),
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stage,
        if (widget.hint != null) ...[
          const SizedBox(height: Gap.inline),
          Text(
            widget.hint!,
            textAlign: TextAlign.center,
            style: AppTypography.caption(context),
          ),
        ],
      ],
    );

    if (!_canDrop) return body;

    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: _onDrop,
      child: body,
    );
  }

  String _defaultCaption() {
    if (widget.pickedName != null) return widget.pickedName!;
    final formats = widget.accept.isEmpty
        ? null
        : widget.accept.take(5).map((e) => e.toUpperCase()).join(' · ');
    final base = _canDrop ? 'Drop a file, or tap' : 'Tap to choose a file';
    return formats == null ? base : '$base\n$formats';
  }
}
