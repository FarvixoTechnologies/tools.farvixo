import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'tool_engine.dart';

/// Handles the OS boundary: picking input files (file_picker or gallery), and
/// exporting results (save to temp + share sheet). Engines never touch I/O, so
/// swapping a LocalToolEngine for a RemoteToolEngine needs no changes here.
class ToolIoService {
  /// Pick input file(s) according to [spec]. Returns [] when the user cancels.
  Future<List<ToolFile>> pickFiles(ToolSpec spec) async {
    if (spec.pickFromGallery) {
      final picker = ImagePicker();
      if (spec.multiFile) {
        final picked = await picker.pickMultiImage();
        return _fromXFiles(picked);
      }
      final one = await picker.pickImage(source: ImageSource.gallery);
      return one == null ? const [] : _fromXFiles([one]);
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: spec.multiFile,
      withData: true,
      type: spec.allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: spec.allowedExtensions,
    );
    if (result == null) return const [];

    final files = <ToolFile>[];
    for (final f in result.files) {
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) continue;
      files.add(ToolFile(name: f.name, bytes: bytes, path: f.path));
    }
    return files;
  }

  Future<List<ToolFile>> _fromXFiles(List<XFile> xfiles) async {
    final out = <ToolFile>[];
    for (final x in xfiles) {
      out.add(ToolFile(
        name: x.name,
        bytes: await x.readAsBytes(),
        path: x.path,
        mime: x.mimeType,
      ));
    }
    return out;
  }

  /// Persist a file-result to the temp dir and return the [File].
  Future<File> saveResult(ToolResult result) async {
    if (result.bytes == null) {
      throw StateError('Result has no bytes to save');
    }
    final dir = await getTemporaryDirectory();
    final name = result.fileName ?? 'farvixo-result';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(result.bytes!, flush: true);
    return file;
  }

  /// Open the OS share sheet for a result (file, text, or image URL).
  Future<void> shareResult(ToolResult result) async {
    switch (result.kind) {
      case ToolResultKind.file:
        final file = await saveResult(result);
        await Share.shareXFiles([XFile(file.path, mimeType: result.mime)]);
      case ToolResultKind.text:
        if (result.text != null) await Share.share(result.text!);
      case ToolResultKind.imageUrl:
        if (result.imageUrl != null) await Share.share(result.imageUrl!);
    }
  }
}

final toolIoServiceProvider = Provider<ToolIoService>((ref) => ToolIoService());
