import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/tool_upload_spec.dart';
import '../domain/upload_item.dart';
import '../domain/upload_source.dart';
import 'folder_lister.dart';

/// Turns a user's source choice into queue-ready [UploadItem]s.
///
/// This is the only place in the upload feature that touches platform file
/// APIs. Sources that need credentials or a native bridge return an empty list
/// and are explained by [unavailableReason], so the UI can say why instead of
/// silently doing nothing.
class UploadPickerService {
  const UploadPickerService();

  /// Picks files for [source], honouring [spec] when the caller is a tool.
  ///
  /// Returns an empty list if the user cancels or every picked file is
  /// rejected by the spec.
  Future<List<UploadItem>> pick(
    UploadSource source, {
    ToolUploadSpec? spec,
  }) async {
    switch (source) {
      case UploadSource.files:
      case UploadSource.recent:
      case UploadSource.external:
      case UploadSource.dragDrop:
        return _limit(await _pickFiles(spec), spec);

      case UploadSource.folder:
        return _limit(await _pickFolder(spec), spec);

      case UploadSource.gallery:
        return _limit(await _pickImages(fromCamera: false, spec: spec), spec);

      case UploadSource.camera:
      case UploadSource.scanner:
        return _limit(await _pickImages(fromCamera: true, spec: spec), spec);

      // Not wired yet — see unavailableReason().
      case UploadSource.clipboard:
      case UploadSource.googleDrive:
      case UploadSource.dropbox:
      case UploadSource.oneDrive:
      case UploadSource.box:
      case UploadSource.url:
      case UploadSource.smb:
      case UploadSource.ftp:
        return const [];
    }
  }

  /// Why a source cannot run yet, or null when it works.
  static String? unavailableReason(UploadSource source) {
    switch (source) {
      case UploadSource.googleDrive:
      case UploadSource.dropbox:
      case UploadSource.oneDrive:
      case UploadSource.box:
        return 'Needs an OAuth client ID — not configured yet';
      case UploadSource.smb:
      case UploadSource.ftp:
        return 'Needs a network file-system plugin';
      case UploadSource.url:
        return 'Needs the backend fetch endpoint';
      case UploadSource.clipboard:
        return 'Needs a clipboard file plugin';
      case UploadSource.files:
      case UploadSource.folder:
      case UploadSource.gallery:
      case UploadSource.camera:
      case UploadSource.scanner:
      case UploadSource.recent:
      case UploadSource.external:
      case UploadSource.dragDrop:
        return null;
    }
  }

  Future<List<UploadItem>> _pickFiles(ToolUploadSpec? spec) async {
    final accept = spec?.accept ?? const <String>[];
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: spec?.multiFile ?? true,
      withData: kIsWeb,
      // Native extension filtering where the platform supports it; the
      // _accepted() pass below is the guarantee.
      type: accept.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: accept.isEmpty ? null : accept,
    );
    if (result == null) return const [];
    return [
      for (final f in result.files)
        if (f.name.isNotEmpty && _accepted(f.name, spec))
          _item(
            name: f.name,
            bytes: f.size,
            path: f.path,
            source: UploadSource.files,
          ),
    ];
  }

  Future<List<UploadItem>> _pickFolder(ToolUploadSpec? spec) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return const [];
    final entries = await listFolder(dir);
    return [
      for (final e in entries)
        if (_accepted(e.name, spec))
          _item(
            name: e.name,
            bytes: e.sizeBytes,
            path: e.path,
            source: UploadSource.folder,
          ),
    ];
  }

  Future<List<UploadItem>> _pickImages({
    required bool fromCamera,
    ToolUploadSpec? spec,
  }) async {
    final picker = ImagePicker();

    if (fromCamera) {
      final shot = await picker.pickImage(source: ImageSource.camera);
      if (shot == null) return const [];
      return [
        _item(
          name: shot.name,
          bytes: await shot.length(),
          path: shot.path,
          source: UploadSource.camera,
        ),
      ];
    }

    // Single-file tools get the single picker, so the user is not invited to
    // select a batch that will then be silently trimmed.
    if (!(spec?.multiFile ?? true)) {
      final one = await picker.pickImage(source: ImageSource.gallery);
      if (one == null) return const [];
      return [
        _item(
          name: one.name,
          bytes: await one.length(),
          path: one.path,
          source: UploadSource.gallery,
        ),
      ];
    }

    final shots = await picker.pickMultiImage();
    final items = <UploadItem>[];
    for (final s in shots) {
      if (!_accepted(s.name, spec)) continue;
      items.add(
        _item(
          name: s.name,
          bytes: await s.length(),
          path: s.path,
          source: UploadSource.gallery,
        ),
      );
    }
    return items;
  }

  /// Builds items from an OS drag-and-drop payload.
  ///
  /// The OS drag layer cannot be told what a tool accepts, so filtering has to
  /// happen here — a user can always drop a `.zip` onto a PDF tool. Returning
  /// an empty list lets the caller explain the rejection.
  List<UploadItem> fromDrop(
    List<({String name, int size, String? path})> drop, {
    ToolUploadSpec? spec,
  }) {
    return _limit(
      [
        for (final d in drop)
          if (_accepted(d.name, spec))
            _item(
              name: d.name,
              bytes: d.size,
              path: d.path,
              source: UploadSource.dragDrop,
            ),
      ],
      spec,
    );
  }

  /// Whether [fileName]'s extension passes [spec].
  static bool _accepted(String fileName, ToolUploadSpec? spec) {
    if (spec == null || spec.accept.isEmpty) return true;
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return false;
    return spec.allows(fileName.substring(dot + 1));
  }

  /// Trims a batch to the spec's ceiling.
  static List<UploadItem> _limit(List<UploadItem> items, ToolUploadSpec? spec) {
    if (spec == null || items.isEmpty) return items;
    final max = spec.multiFile ? spec.maxFiles : 1;
    return items.length <= max ? items : items.sublist(0, max);
  }

  static int _seq = 0;

  UploadItem _item({
    required String name,
    required int bytes,
    required String? path,
    required UploadSource source,
  }) {
    _seq++;
    return UploadItem(
      id: '${DateTime.now().microsecondsSinceEpoch}-$_seq',
      name: name,
      sizeBytes: bytes,
      source: source,
      localPath: path,
    );
  }
}
