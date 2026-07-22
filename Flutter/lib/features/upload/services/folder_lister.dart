/// Lists the files directly inside a folder.
///
/// `dart:io` cannot be imported at all in a web build, so the implementation is
/// selected at compile time — the same conditional-import pattern the repo
/// already uses for `settings_export_saver_*.dart`.
library;

export 'folder_lister_stub.dart'
    if (dart.library.io) 'folder_lister_io.dart'
    if (dart.library.js_interop) 'folder_lister_web.dart';
