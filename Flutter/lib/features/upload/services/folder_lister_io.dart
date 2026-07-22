import 'dart:io';

/// One file discovered inside a picked folder.
typedef FolderEntry = ({String name, int sizeBytes, String path});

/// Lists the files directly inside [path] (non-recursive).
///
/// Non-recursive on purpose: a recursive walk of a large tree blocks the
/// picker sheet and can enqueue thousands of files from one tap. Sub-folders
/// are surfaced in the UI as a separate action.
Future<List<FolderEntry>> listFolder(String path) async {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];

  final entries = <FolderEntry>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.isEmpty
        ? entity.path
        : entity.uri.pathSegments.last;
    if (name.isEmpty || name.startsWith('.')) continue;
    try {
      entries.add((
        name: name,
        sizeBytes: await entity.length(),
        path: entity.path,
      ));
    } on FileSystemException {
      // Unreadable file (permissions, vanished mid-scan) — skip it rather
      // than failing the whole folder pick.
      continue;
    }
  }
  return entries;
}
