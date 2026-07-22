import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../domain/upload_source.dart';

/// Universal OS drag-and-drop wrapper.
///
/// On platforms where `desktop_drop` has no implementation (iOS today) this
/// renders [child] untouched, so the same widget tree is valid everywhere and
/// callers never branch on platform.
class UploadDropZone extends StatefulWidget {
  const UploadDropZone({
    super.key,
    required this.child,
    required this.onFiles,
    this.onHoverChanged,
    this.enabled = true,
  });

  final Widget child;

  /// Fires with the dropped payload, normalised for the picker service.
  final ValueChanged<List<({String name, int size, String? path})>> onFiles;

  /// Fires true while a payload hovers, false when it leaves or drops.
  final ValueChanged<bool>? onHoverChanged;

  final bool enabled;

  @override
  State<UploadDropZone> createState() => _UploadDropZoneState();
}

class _UploadDropZoneState extends State<UploadDropZone> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        widget.enabled && UploadPlatform.current.supportsDrop;
    if (!supported) return widget.child;

    return DropTarget(
      onDragEntered: (_) => _setHover(true),
      onDragExited: (_) => _setHover(false),
      onDragDone: (detail) async {
        _setHover(false);
        final payload = <({String name, int size, String? path})>[];
        for (final file in detail.files) {
          final name = file.name.isNotEmpty ? file.name : file.path;
          int size;
          try {
            size = await file.length();
          } on Object {
            // A dropped item we cannot stat (a folder, a vanished temp file)
            // still gets queued so the user sees it rather than nothing.
            size = 0;
          }
          payload.add((name: name, size: size, path: file.path));
        }
        if (payload.isNotEmpty) widget.onFiles(payload);
      },
      child: widget.child,
    );
  }
}
