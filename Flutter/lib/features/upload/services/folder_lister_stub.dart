/// One file discovered inside a picked folder.
typedef FolderEntry = ({String name, int sizeBytes, String path});

/// Fallback used when neither `dart:io` nor web interop is available.
Future<List<FolderEntry>> listFolder(String path) async => const [];
